S7::method(rho_estimate_tokens, S7::class_any) <- function(x, ...) 0

S7::method(rho_estimate_tokens, S7::class_character) <- function(x, ...) {
  as.double(ceiling(sum(nchar(x, type = "bytes"), na.rm = TRUE) / 4))
}

S7::method(rho_estimate_tokens, S7::class_list) <- function(x, ...) {
  as.double(sum(vapply(x, rho_estimate_tokens, double(1))))
}

S7::method(rho_estimate_tokens, TextContent) <- function(x, ...) {
  rho_estimate_tokens(x@text)
}

S7::method(rho_estimate_tokens, ThinkingContent) <- function(x, ...) {
  rho_estimate_tokens(x@text)
}

S7::method(rho_estimate_tokens, ImageContent) <- function(x, ...) 1200

S7::method(rho_estimate_tokens, ArtifactRefContent) <- function(x, ...) {
  rho_estimate_tokens(c(x@artifact_id, x@media_type))
}

S7::method(rho_estimate_tokens, ToolCall) <- function(x, ...) {
  arguments <- paste(deparse(x@arguments, width.cutoff = 500L), collapse = "")
  rho_estimate_tokens(c(x@name, arguments))
}

S7::method(rho_estimate_tokens, UserMessage) <- function(x, ...) {
  rho_estimate_tokens(x@content)
}

S7::method(rho_estimate_tokens, AssistantMessage) <- function(x, ...) {
  rho_estimate_tokens(x@content)
}

S7::method(rho_estimate_tokens, ToolResultMessage) <- function(x, ...) {
  rho_estimate_tokens(c(x@content, x@added_tool_names))
}

S7::method(rho_estimate_tokens, ToolSpec) <- function(x, ...) {
  rho_estimate_tokens(c(
    x@name,
    x@label,
    x@description,
    paste(deparse(x@parameters, width.cutoff = 500L), collapse = "")
  ))
}

S7::method(rho_estimate_tokens, RhoOperation) <- function(x, ...) {
  rho_estimate_tokens(paste(
    deparse(rho_context_signature(x), width.cutoff = 500L),
    collapse = ""
  ))
}

S7::method(rho_estimate_tokens, Context) <- function(x, ...) {
  rho_estimate_tokens(c(
    x@system_prompt,
    x@messages,
    x@tools,
    x@operations
  ))
}

rho_assistant_usage_is_current <- function(message, after, revision = NULL) {
  if (!S7::S7_inherits(message, AssistantMessage)) {
    return(FALSE)
  }
  revision_matches <- is.null(revision) ||
    (!is.null(message@context_revision) &&
      identical(message@context_revision@digest, revision@digest))
  message@timestamp > after &&
    !message@stop_reason %in% c("aborted", "error") &&
    S7::S7_inherits(message@usage, Usage) &&
    message@usage@total > 0 &&
    revision_matches
}

rho_message_context_usage <- function(
  messages,
  after = -Inf,
  revision = NULL
) {
  usage_indexes <- which(vapply(
    messages,
    rho_assistant_usage_is_current,
    logical(1),
    after = after,
    revision = revision
  ))
  if (!length(usage_indexes)) {
    tokens <- rho_estimate_tokens(messages)
    return(RhoContextUsage(
      tokens = tokens,
      usage_tokens = 0,
      trailing_tokens = tokens,
      last_usage_index = NULL
    ))
  }

  last_usage_index <- usage_indexes[[length(usage_indexes)]]
  usage_tokens <- messages[[last_usage_index]]@usage@total
  trailing <- if (last_usage_index < length(messages)) {
    rho_estimate_tokens(messages[seq.int(last_usage_index + 1L, length(messages))])
  } else {
    0
  }
  RhoContextUsage(
    tokens = as.double(usage_tokens + trailing),
    usage_tokens = as.double(usage_tokens),
    trailing_tokens = as.double(trailing),
    last_usage_index = as.integer(last_usage_index)
  )
}

S7::method(rho_context_usage, S7::class_list) <- function(
  messages,
  after = -Inf,
  model = NULL,
  ...
) {
  rho_message_context_usage(messages, after = after)
}

S7::method(rho_context_usage, Context) <- function(
  messages,
  after = -Inf,
  model = NULL,
  ...
) {
  if (is.null(model)) {
    tokens <- rho_estimate_tokens(messages)
    return(RhoContextUsage(
      tokens = tokens,
      usage_tokens = 0,
      trailing_tokens = tokens,
      last_usage_index = NULL
    ))
  }
  revision <- rho_context_revision(messages, model)
  usage <- rho_message_context_usage(
    messages@messages,
    after = after,
    revision = revision
  )
  if (usage@usage_tokens > 0) {
    return(usage)
  }
  tokens <- rho_estimate_tokens(messages)
  RhoContextUsage(
    tokens = tokens,
    usage_tokens = 0,
    trailing_tokens = tokens,
    last_usage_index = NULL
  )
}

S7::method(
  rho_should_compact,
  list(RhoCompactionSettings, RhoContextUsage, Model)
) <- function(settings, usage, model, ...) {
  settings@enabled &&
    usage@tokens > as.double(model@limits@context_window) - settings@reserve_tokens
}

S7::method(rho_compaction_message_cut_allowed, S7::class_any) <- function(
  message,
  ...
) {
  FALSE
}

S7::method(rho_compaction_message_cut_allowed, UserMessage) <- function(
  message,
  ...
) {
  TRUE
}

S7::method(
  rho_compaction_message_cut_allowed,
  AssistantMessage
) <- function(message, ...) {
  TRUE
}

S7::method(rho_compaction_cut_allowed, RhoSessionEntry) <- function(entry, ...) {
  FALSE
}

S7::method(
  rho_compaction_cut_allowed,
  RhoSessionMessageEntry
) <- function(entry, ...) {
  rho_compaction_message_cut_allowed(entry@message)
}

rho_compaction_active_entries <- function(agent) {
  entries <- rho_active_session_entries(
    agent@state$entries,
    agent@state$leaf_id
  )
  excluded <- vapply(
    Filter(
      function(entry) S7::S7_inherits(entry, RhoSessionContextExclusionEntry),
      entries
    ),
    function(entry) entry@target_entry_id,
    character(1)
  )
  Filter(
    function(entry) {
      !S7::S7_inherits(entry, RhoSessionMessageEntry) ||
        !entry@id %in% excluded
    },
    entries
  )
}

rho_compaction_turn_start <- function(entries, index, start) {
  for (candidate in seq.int(index, start)) {
    entry <- entries[[candidate]]
    if (
      S7::S7_inherits(entry, RhoSessionMessageEntry) &&
        S7::S7_inherits(entry@message, UserMessage)
    ) {
      return(candidate)
    }
  }
  NULL
}

rho_compaction_cut <- function(entries, start, keep_recent_tokens) {
  valid <- which(vapply(entries, rho_compaction_cut_allowed, logical(1)))
  valid <- valid[valid >= start]
  if (!length(valid)) {
    return(NULL)
  }

  cut <- valid[[1L]]
  accumulated <- 0
  for (index in seq.int(length(entries), start)) {
    entry <- entries[[index]]
    if (!S7::S7_inherits(entry, RhoSessionMessageEntry)) {
      next
    }
    accumulated <- accumulated + rho_estimate_tokens(entry@message)
    if (accumulated >= keep_recent_tokens) {
      candidates <- valid[valid >= index]
      if (length(candidates)) {
        cut <- candidates[[1L]]
      }
      break
    }
  }

  entry <- entries[[cut]]
  starts_turn <- S7::S7_inherits(entry, RhoSessionMessageEntry) &&
    S7::S7_inherits(entry@message, UserMessage)
  turn_start <- if (starts_turn) NULL else rho_compaction_turn_start(entries, cut, start)
  RhoCompactionCut(
    first_kept = cut,
    turn_start = turn_start,
    split_turn = !starts_turn && !is.null(turn_start)
  )
}

rho_compaction_message_entries <- function(entries) {
  lapply(
    Filter(
      function(entry) S7::S7_inherits(entry, RhoSessionMessageEntry),
      entries
    ),
    function(entry) entry@message
  )
}

rho_compaction_checkpoint <- function(entries) {
  compaction_index <- rho_latest_compaction_index(entries)
  if (is.null(compaction_index)) {
    return(RhoCompactionCheckpoint(
      start = 1L,
      previous_summary = "",
      timestamp = -Inf
    ))
  }
  compaction <- entries[[compaction_index]]
  ids <- vapply(entries, function(entry) entry@id, character(1))
  first_kept <- match(compaction@result@first_kept_entry_id, ids)
  start <- if (is.na(first_kept)) compaction_index + 1L else first_kept
  RhoCompactionCheckpoint(
    start = as.integer(start),
    previous_summary = compaction@result@summary,
    timestamp = compaction@timestamp
  )
}

S7::method(
  rho_prepare_compaction,
  list(RhoAgent, RhoCompactionSettings)
) <- function(agent, settings, context = NULL, ...) {
  entries <- rho_compaction_active_entries(agent)
  if (!length(entries)) {
    return(rho_nothing_to_compact(
      "The session has no messages to compact"
    ))
  }

  checkpoint <- rho_compaction_checkpoint(entries)
  cut <- rho_compaction_cut(entries, checkpoint@start, settings@keep_recent_tokens)
  if (is.null(cut) || cut@first_kept <= checkpoint@start) {
    return(rho_nothing_to_compact(
      "The retained-token budget already covers the active session context"
    ))
  }

  history_end <- if (cut@split_turn) cut@turn_start else cut@first_kept
  history <- if (history_end > checkpoint@start) {
    entries[seq.int(checkpoint@start, history_end - 1L)]
  } else {
    list()
  }
  turn_prefix <- if (cut@split_turn && cut@first_kept > cut@turn_start) {
    entries[seq.int(cut@turn_start, cut@first_kept - 1L)]
  } else {
    list()
  }
  messages <- rho_compaction_message_entries(history)
  prefix_messages <- rho_compaction_message_entries(turn_prefix)
  if (!length(messages) && !length(prefix_messages)) {
    return(rho_nothing_to_compact(
      "The selected cut point contains no messages to summarize"
    ))
  }

  if (is.null(context)) {
    context <- rho_build_agent_context(agent)
  }
  usage <- rho_context_usage(
    context,
    after = checkpoint@timestamp,
    model = agent@options@model
  )
  RhoCompactionPreparation(
    first_kept_entry_id = entries[[cut@first_kept]]@id,
    messages = messages,
    turn_prefix = prefix_messages,
    split_turn = cut@split_turn,
    tokens_before = usage@tokens,
    previous_summary = checkpoint@previous_summary,
    settings = settings
  )
}

S7::method(rho_compaction_text, S7::class_any) <- function(x, ...) {
  sprintf("[%s]", class(x)[[1L]])
}

S7::method(rho_compaction_text, S7::class_character) <- function(x, ...) {
  paste(x, collapse = "\n")
}

S7::method(rho_compaction_text, S7::class_list) <- function(x, ...) {
  paste(vapply(x, rho_compaction_text, character(1)), collapse = "\n")
}

S7::method(rho_compaction_text, TextContent) <- function(x, ...) x@text

S7::method(rho_compaction_text, ThinkingContent) <- function(x, ...) {
  paste0("<thinking>\n", x@text, "\n</thinking>")
}

S7::method(rho_compaction_text, ImageContent) <- function(x, ...) {
  sprintf("[image: %s]", x@mime_type)
}

S7::method(rho_compaction_text, ArtifactRefContent) <- function(x, ...) {
  sprintf("[artifact: %s; %s]", x@artifact_id, x@media_type)
}

S7::method(rho_compaction_text, ToolCall) <- function(x, ...) {
  arguments <- paste(deparse(x@arguments, width.cutoff = 500L), collapse = "")
  sprintf("[tool call: %s]\n%s", x@name, arguments)
}

S7::method(rho_compaction_text, UserMessage) <- function(x, ...) {
  paste0("user:\n", rho_compaction_text(x@content))
}

S7::method(rho_compaction_text, AssistantMessage) <- function(x, ...) {
  paste0("assistant:\n", rho_compaction_text(x@content))
}

S7::method(rho_compaction_text, ToolResultMessage) <- function(x, ...) {
  paste0("tool result (", x@tool_name, "):\n", rho_compaction_text(x@content))
}

rho_compaction_system_prompt <- function() {
  paste(
    "Summarize the supplied conversation as a context checkpoint.",
    "Do not continue the conversation or answer its questions.",
    "Preserve exact paths, identifiers, constraints, decisions, progress, and next steps."
  )
}

rho_compaction_summary_prompt <- function(
  messages,
  previous_summary,
  custom_instructions
) {
  sections <- c(
    "<conversation>",
    vapply(messages, rho_compaction_text, character(1)),
    "</conversation>"
  )
  if (nzchar(previous_summary)) {
    sections <- c(
      sections,
      "<previous-summary>",
      previous_summary,
      "</previous-summary>",
      "Update the previous summary with the new conversation."
    )
  }
  sections <- c(
    sections,
    "Use sections for goal, constraints, completed work, current work, decisions, next steps, and critical context."
  )
  if (nzchar(custom_instructions)) {
    sections <- c(sections, "Additional focus:", custom_instructions)
  }
  paste(sections, collapse = "\n\n")
}

rho_compaction_prefix_prompt <- function(messages) {
  paste(
    "<conversation-prefix>",
    paste(vapply(messages, rho_compaction_text, character(1)), collapse = "\n\n"),
    "</conversation-prefix>",
    paste(
      "This is the omitted prefix of a turn whose recent suffix remains in context.",
      "Summarize the original request, early progress, and facts needed to understand that suffix."
    ),
    sep = "\n\n"
  )
}

rho_compaction_completion <- function(agent, preparation, prompt, fraction) {
  max_tokens <- max(
    1L,
    min(
      floor(fraction * preparation@settings@reserve_tokens),
      agent@options@model@limits@max_tokens
    )
  )
  context <- rho_context(
    system_prompt = rho_compaction_system_prompt(),
    messages = list(rho_user_message(prompt))
  )
  options <- utils::modifyList(
    agent@options@stream_options,
    list(max_tokens = as.integer(max_tokens))
  )
  rho_complete(
    agent@options@provider,
    agent@options@model,
    context,
    options = options
  )
}

rho_compaction_completion_text <- function(value) {
  if (S7::S7_inherits(value, ProviderErrorValue)) {
    return(rho_compaction_error(
      RhoCompactionFailure,
      paste("Compaction summarization failed:", value@message),
      details = list(provider_error = value)
    ))
  }
  if (!S7::S7_inherits(value, AssistantMessage)) {
    return(rho_compaction_error(
      RhoCompactionFailure,
      "The compaction provider returned a value outside the assistant-message protocol",
      details = list(value = value)
    ))
  }
  text <- paste(
    vapply(
      Filter(
        function(content) S7::S7_inherits(content, TextContent),
        value@content
      ),
      function(content) content@text,
      character(1)
    ),
    collapse = "\n"
  )
  if (!nzchar(text)) {
    return(rho_compaction_error(
      RhoCompactionFailure,
      "The compaction provider returned no text summary"
    ))
  }
  text
}

S7::method(
  rho_compact_preparation,
  list(RhoSummaryCompactor, RhoCompactionPreparation)
) <- function(
  compactor,
  preparation,
  agent,
  custom_instructions = "",
  ...
) {
  rho_coro_task(
    function() {
      history_prompt <- rho_compaction_summary_prompt(
        preparation@messages,
        preparation@previous_summary,
        custom_instructions
      )
      history <- coro::await(rho_as_promise(
        rho_compaction_completion(agent, preparation, history_prompt, 0.8)
      ))
      summary <- rho_compaction_completion_text(history)
      if (S7::S7_inherits(summary, RhoCompactionErrorValue)) {
        return(summary)
      }

      if (preparation@split_turn && length(preparation@turn_prefix)) {
        prefix <- coro::await(rho_as_promise(
          rho_compaction_completion(
            agent,
            preparation,
            rho_compaction_prefix_prompt(preparation@turn_prefix),
            0.5
          )
        ))
        prefix <- rho_compaction_completion_text(prefix)
        if (S7::S7_inherits(prefix, RhoCompactionErrorValue)) {
          return(prefix)
        }
        summary <- paste0(
          summary,
          "\n\n---\n\nTurn context for the retained suffix:\n\n",
          prefix
        )
      }

      rho_compaction_result(
        summary = summary,
        first_kept_entry_id = preparation@first_kept_entry_id,
        tokens_before = preparation@tokens_before,
        source = RhoGeneratedCompaction()
      )
    },
    label = "session-compaction-summary"
  )
}

S7::method(
  rho_before_compaction,
  list(RhoDefaultAgentPolicy, RhoBeforeCompactionContext)
) <- function(policy, context, ...) {
  rho_task(rho_before_compaction_decision())
}

S7::method(
  rho_after_compaction,
  list(RhoDefaultAgentPolicy, RhoAfterCompactionContext)
) <- function(policy, context, ...) {
  rho_task(NULL)
}

rho_compaction_start_event <- function(reason, will_retry, preparation) {
  rho_agent_event(
    RhoCompactionStartEvent,
    "compaction_start",
    reason = reason,
    will_retry = will_retry,
    preparation = preparation
  )
}

rho_compaction_end_event <- function(
  reason,
  will_retry,
  outcome = NULL,
  error = NULL
) {
  rho_agent_event(
    RhoCompactionEndEvent,
    "compaction_end",
    reason = reason,
    will_retry = will_retry,
    outcome = outcome,
    error = error
  )
}

rho_validate_compaction_result <- function(agent, result) {
  if (!S7::S7_inherits(result, RhoCompactionResult)) {
    return(rho_compaction_error(
      RhoCompactionFailure,
      "A compactor must return a RhoCompactionResult"
    ))
  }
  active_entries <- rho_compaction_active_entries(agent)
  entry <- Filter(
    function(candidate) identical(candidate@id, result@first_kept_entry_id),
    active_entries
  )
  if (
    length(entry) != 1L ||
      !S7::S7_inherits(entry[[1L]], RhoSessionMessageEntry) ||
      !rho_compaction_cut_allowed(entry[[1L]])
  ) {
    return(rho_compaction_error(
      RhoCompactionFailure,
      "The compaction result does not reference a valid retained message entry"
    ))
  }
  result
}

rho_compaction_task_value <- function(action, message) {
  task <- tryCatch(
    action(),
    error = function(error) {
      rho_task(rho_compaction_error(
        RhoCompactionFailure,
        paste(message, conditionMessage(error)),
        details = list(parent = error)
      ))
    }
  )
  rho_catch(
    rho_as_task(task),
    function(error) {
      rho_compaction_error(
        RhoCompactionFailure,
        paste(message, conditionMessage(error)),
        details = list(parent = error)
      )
    }
  )
}

rho_run_compaction <- function(
  agent,
  reason,
  custom_instructions = "",
  will_retry = FALSE,
  context = NULL
) {
  preparation <- rho_prepare_compaction(
    agent,
    agent@options@compaction,
    context = context
  )
  if (
    S7::S7_inherits(preparation, RhoCompactionSkipped) ||
      S7::S7_inherits(preparation, RhoCompactionErrorValue)
  ) {
    return(rho_task(preparation))
  }

  rho_coro_task(
    function() {
      coro::await(rho_as_promise(
        rho_emit_agent_event(
          agent,
          rho_compaction_start_event(reason, will_retry, preparation)
        )
      ))
      before_context <- RhoBeforeCompactionContext(
        agent = agent,
        preparation = preparation,
        reason = reason,
        will_retry = will_retry,
        custom_instructions = custom_instructions
      )
      decision <- coro::await(rho_as_promise(
        rho_compaction_task_value(
          function() rho_before_compaction(agent@options@policy, before_context),
          "Before-compaction policy failed:"
        )
      ))
      if (S7::S7_inherits(decision, RhoCompactionErrorValue)) {
        coro::await(rho_as_promise(rho_emit_agent_event(
          agent,
          rho_compaction_end_event(reason, will_retry, error = decision)
        )))
        return(decision)
      }
      if (!S7::S7_inherits(decision, RhoBeforeCompactionDecision)) {
        error <- rho_compaction_error(
          RhoCompactionFailure,
          "Before-compaction policy must return a RhoBeforeCompactionDecision"
        )
        coro::await(rho_as_promise(rho_emit_agent_event(
          agent,
          rho_compaction_end_event(reason, will_retry, error = error)
        )))
        return(error)
      }
      if (decision@cancel) {
        outcome <- rho_compaction_cancelled(
          "Compaction was cancelled by the agent policy"
        )
        coro::await(rho_as_promise(rho_emit_agent_event(
          agent,
          rho_compaction_end_event(reason, will_retry, outcome = outcome)
        )))
        return(outcome)
      }

      result <- decision@result
      if (is.null(result)) {
        result <- coro::await(rho_as_promise(
          rho_compaction_task_value(
            function() {
              rho_compact_preparation(
                agent@options@compactor,
                preparation,
                agent,
                custom_instructions = custom_instructions
              )
            },
            "Compactor failed:"
          )
        ))
      }
      result <- rho_validate_compaction_result(agent, result)
      if (S7::S7_inherits(result, RhoCompactionErrorValue)) {
        coro::await(rho_as_promise(rho_emit_agent_event(
          agent,
          rho_compaction_end_event(reason, will_retry, error = result)
        )))
        return(result)
      }

      entry <- RhoSessionCompactionEntry(
        id = rho_next_session_entry_id(agent),
        parent_id = agent@state$leaf_id,
        timestamp = as.double(Sys.time()),
        result = result,
        reason = reason,
        will_retry = will_retry
      )
      commit <- coro::await(rho_as_promise(
        rho_append_session_entry(agent, entry)
      ))
      if (S7::S7_inherits(commit, RhoSessionJournalErrorValue)) {
        error <- rho_compaction_error(
          RhoCompactionFailure,
          commit@message,
          details = list(journal = commit)
        )
        coro::await(rho_as_promise(rho_emit_agent_event(
          agent,
          rho_compaction_end_event(reason, will_retry, error = error)
        )))
        return(error)
      }
      after_context <- RhoAfterCompactionContext(
        agent = agent,
        entry = entry,
        result = result,
        reason = reason,
        will_retry = will_retry
      )
      after <- coro::await(rho_as_promise(
        rho_compaction_task_value(
          function() rho_after_compaction(agent@options@policy, after_context),
          "After-compaction policy failed:"
        )
      ))
      after_error <- NULL
      if (S7::S7_inherits(after, RhoCompactionErrorValue)) {
        after_error <- after
      }
      coro::await(rho_as_promise(rho_emit_agent_event(
        agent,
        rho_compaction_end_event(
          reason,
          will_retry,
          outcome = result,
          error = after_error
        )
      )))
      result
    },
    label = "session-compaction"
  )
}

S7::method(rho_compact, RhoAgent) <- function(
  agent,
  custom_instructions = "",
  reason = RhoManualCompaction(),
  will_retry = FALSE,
  ...
) {
  if (!S7::S7_inherits(agent@state$phase, RhoAgentIdle)) {
    return(rho_task(rho_compaction_error(
      RhoCompactionBusy,
      "Compaction requires an idle agent"
    )))
  }
  agent@state$phase <- RhoAgentCompacting()
  rho_coro_task(
    function() {
      on.exit(rho_set_agent_idle(agent), add = TRUE)
      context <- coro::await(rho_as_promise(
        rho_transform_model_context(agent, rho_build_agent_context(agent))
      ))
      if (S7::S7_inherits(context, RhoAgentErrorValue)) {
        return(context)
      }
      coro::await(rho_as_promise(rho_run_compaction(
        agent,
        reason,
        custom_instructions,
        will_retry,
        context
      )))
    },
    label = "manual-session-compaction"
  )
}

S7::method(
  rho_error_requests_compaction,
  list(S7::class_any, Model)
) <- function(error, model, ...) {
  FALSE
}

S7::method(
  rho_error_requests_compaction,
  list(ProviderInputLimitError, Model)
) <- function(error, model, ...) {
  TRUE
}

S7::method(
  rho_error_requests_compaction,
  list(RhoAgentErrorValue, Model)
) <- function(error, model, ...) {
  provider_error <- error@details$provider_error
  !is.null(provider_error) && rho_error_requests_compaction(provider_error, model)
}

rho_context_after_threshold_compaction <- function(agent) {
  rho_coro_task(
    function() {
      context <- coro::await(rho_as_promise(
        rho_transform_model_context(agent, rho_build_agent_context(agent))
      ))
      if (S7::S7_inherits(context, RhoAgentErrorValue)) {
        return(context)
      }

      compaction <- rho_latest_compaction_entry(agent)
      after <- -Inf
      if (!is.null(compaction)) {
        after <- compaction@timestamp
      }
      usage <- rho_context_usage(
        context,
        after = after,
        model = agent@options@model
      )
      if (
        !rho_should_compact(
          agent@options@compaction,
          usage,
          agent@options@model
        )
      ) {
        return(context)
      }

      result <- coro::await(rho_as_promise(rho_run_compaction(
        agent,
        RhoThresholdCompaction(),
        context = context
      )))
      if (S7::S7_inherits(result, RhoCompactionResult)) {
        compacted_context <- coro::await(rho_as_promise(
          rho_transform_model_context(agent, rho_build_agent_context(agent))
        ))
        return(compacted_context)
      }
      if (S7::S7_inherits(result, RhoCompactionSkipped)) {
        return(context)
      }
      result
    },
    label = "context-after-threshold-compaction"
  )
}

rho_transform_model_context <- function(agent, context) {
  rho_coro_task(
    function() {
      transformed <- tryCatch(
        coro::await(rho_as_promise(rho_as_task(
          rho_transform_agent_context(
            agent@options@policy,
            agent,
            context
          )
        ))),
        error = function(error) error
      )
      if (inherits(transformed, "error")) {
        return(rho_agent_error(conditionMessage(transformed), "policy"))
      }
      if (!S7::S7_inherits(transformed, Context)) {
        return(rho_agent_error(
          "Agent context policy did not return a Context",
          "policy"
        ))
      }
      transformed
    },
    label = "transform-model-context"
  )
}
