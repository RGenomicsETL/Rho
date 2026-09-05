rho_agent_run_result <- function(
  agent,
  events_before,
  tool_results,
  status = "completed",
  error = NULL,
  context = NULL
) {
  first_event <- events_before + 1L
  events <- if (first_event <= length(agent@state$events)) {
    agent@state$events[seq.int(first_event, length(agent@state$events))]
  } else {
    list()
  }
  RhoAgentRunResult(
    messages = agent@state$messages,
    entries = agent@state$entries,
    tool_results = tool_results,
    events = events,
    status = status,
    error = error,
    context = context,
    usage = rho.ai::rho_summarize_usage(agent@state$messages)
  )
}

rho_set_agent_idle <- function(agent) {
  agent@state$phase <- RhoAgentIdle()
  agent@state$current_stream <- NULL
  agent@state$pending_tool_calls <- character()
  agent@state$active_tool_tasks <- list()
  agent@state$active_tool_sequence <- 0L
  nanonext::cv_signal(agent@state$idle_condition)
  waiters <- agent@state$idle_waiters
  agent@state$idle_waiters <- list()
  for (resolve in waiters) {
    resolve(NULL)
  }
  invisible(agent)
}

rho_drain_agent_queue <- function(agent, field, label, count) {
  values <- agent@state[[field]]
  if (!length(values)) {
    return(rho.async::rho_task(list()))
  }
  count <- min(as.integer(count), length(values))
  selected <- values[seq_len(count)]
  agent@state[[field]] <- if (count == length(values)) {
    list()
  } else {
    values[-seq_len(count)]
  }
  rho.async::rho_then(
    rho_emit_agent_event(
      agent,
      rho_queue_update_event(label, length(agent@state[[field]]))
    ),
    function(ignored) selected
  )
}

S7::method(
  rho_take_agent_queue,
  RhoQueueMode
) <- function(mode, agent, field, label, ...) {
  rho_drain_agent_queue(agent, field, label, 1L)
}

S7::method(
  rho_take_agent_queue,
  RhoAllQueue
) <- function(mode, agent, field, label, ...) {
  rho_drain_agent_queue(agent, field, label, length(agent@state[[field]]))
}

rho_append_agent_messages <- function(agent, messages) {
  rho.async::rho_coro_task(
    function() {
      for (message in messages) {
        commit <- coro::await(rho.async::rho_as_promise(
          rho_record_agent_message(agent, message)
        ))
        if (S7::S7_inherits(commit, RhoSessionJournalErrorValue)) {
          return(commit)
        }
        coro::await(rho.async::rho_as_promise(
          rho_emit_agent_event(agent, rho_message_start_event(message))
        ))
        coro::await(rho.async::rho_as_promise(
          rho_emit_agent_event(agent, rho_message_end_event(message))
        ))
      }
      messages
    },
    label = "append-agent-messages"
  )
}

rho_invalid_agent_run <- function(agent, events_before, message) {
  error <- rho_agent_error(message, "invalid_state")
  rho_agent_run_result(agent, events_before, list(), status = "error", error = error)
}

rho_agent_run_status_from_error <- function(error) {
  if (is.null(error)) {
    "completed"
  } else if (identical(error@kind, "aborted")) {
    "aborted"
  } else {
    "error"
  }
}

rho_run_agent_loop <- function(
  agent,
  prompts,
  continue = FALSE,
  application = NULL
) {
  events_before <- length(agent@state$events)
  if (!S7::S7_inherits(agent@state$phase, RhoAgentIdle)) {
    return(rho.async::rho_task(rho_invalid_agent_run(
      agent,
      events_before,
      "Agent is already running"
    )))
  }
  if (continue && !length(agent@state$messages)) {
    return(rho.async::rho_task(rho_invalid_agent_run(
      agent,
      events_before,
      "Cannot continue without messages"
    )))
  }
  if (
    continue &&
      S7::S7_inherits(
        agent@state$messages[[length(agent@state$messages)]],
        rho.ai::AssistantMessage
      )
  ) {
    return(rho.async::rho_task(rho_invalid_agent_run(
      agent,
      events_before,
      "Cannot continue from an assistant message"
    )))
  }

  run_context <- rho_run_context(agent, application)
  agent@state$phase <- RhoAgentRunning()
  agent@state$cancelled <- FALSE
  agent@state$cancel_reason <- NULL

  rho.async::rho_coro_task(
    function() {
      on.exit(rho_set_agent_idle(agent), add = TRUE)
      tool_results <- list()
      run_error <- NULL
      turn <- 0L
      input_limit_recovery_attempted <- FALSE

      coro::await(rho.async::rho_as_promise(
        rho_emit_agent_event(agent, rho_agent_start_event())
      ))
      pending <- prompts
      if (!length(pending)) {
        pending <- coro::await(rho.async::rho_as_promise(rho_take_agent_queue(
          agent@options@steering_mode,
          agent,
          "steering_queue",
          "steering"
        )))
      }

      repeat {
        turn <- turn + 1L
        coro::await(rho.async::rho_as_promise(
          rho_emit_agent_event(agent, rho_turn_start_event(turn))
        ))
        if (length(pending)) {
          appended <- coro::await(rho.async::rho_as_promise(
            rho_append_agent_messages(agent, pending)
          ))
          if (S7::S7_inherits(appended, RhoSessionJournalErrorValue)) {
            run_error <- appended
            break
          }
          pending <- list()
        }

        model_context <- coro::await(rho.async::rho_as_promise(
          rho_context_after_threshold_compaction(agent)
        ))
        if (
          S7::S7_inherits(model_context, RhoCompactionErrorValue) ||
            S7::S7_inherits(model_context, RhoAgentErrorValue)
        ) {
          run_error <- model_context
          break
        }
        response <- coro::await(rho.async::rho_as_promise(
          rho_receive_assistant(agent, model_context)
        ))
        assistant <- response@message
        if (!is.null(response@error)) {
          coro::await(rho.async::rho_as_promise(
            rho_emit_agent_event(agent, rho_turn_end_event(turn, assistant, list()))
          ))
          compact_for_error <- rho_error_requests_compaction(
            response@error,
            agent@options@model
          )
          if (compact_for_error && !input_limit_recovery_attempted) {
            input_limit_recovery_attempted <- TRUE
            coro::await(rho.async::rho_as_promise(
              rho_exclude_session_entry(
                agent,
                response@entry_id,
                RhoProviderInputLimitCompaction()
              )
            ))
            compacted <- coro::await(rho.async::rho_as_promise(
              rho_run_compaction(
                agent,
                RhoProviderInputLimitCompaction(),
                will_retry = TRUE,
                context = model_context
              )
            ))
            if (S7::S7_inherits(compacted, RhoCompactionResult)) {
              next
            }
            if (S7::S7_inherits(compacted, RhoCompactionErrorValue)) {
              run_error <- compacted
              break
            }
          }
          run_error <- response@error
          break
        }

        batch <- tryCatch(
          coro::await(rho.async::rho_as_promise(
            rho_execute_assistant_tools(
              agent,
              assistant,
              run_context,
              model_context
            )
          )),
          error = function(error) error
        )
        if (inherits(batch, "error")) {
          run_error <- rho_agent_error(conditionMessage(batch), "tool_execution")
          coro::await(rho.async::rho_as_promise(
            rho_emit_agent_event(agent, rho_turn_end_event(turn, assistant, list()))
          ))
          break
        }

        journal_error <- NULL
        for (message in batch@messages) {
          commit <- coro::await(rho.async::rho_as_promise(
            rho_record_agent_message(agent, message)
          ))
          if (S7::S7_inherits(commit, RhoSessionJournalErrorValue)) {
            journal_error <- commit
            break
          }
        }
        if (!is.null(journal_error)) {
          run_error <- journal_error
          break
        }
        tool_results <- c(tool_results, batch@messages)
        coro::await(rho.async::rho_as_promise(
          rho_emit_agent_event(
            agent,
            rho_turn_end_event(turn, assistant, batch@messages)
          )
        ))

        decision <- tryCatch(
          coro::await(rho.async::rho_as_promise(rho_prepare_next_turn(
            agent@options@policy,
            agent,
            assistant,
            batch@messages,
            model_context,
            agent@state$messages
          ))),
          error = function(error) error
        )
        if (
          inherits(decision, "error") ||
            !S7::S7_inherits(decision, RhoNextTurnDecision)
        ) {
          if (inherits(decision, "error")) {
            message <- conditionMessage(decision)
          } else {
            message <- "next-turn policy returned an invalid decision"
          }
          run_error <- rho_agent_error(message, "policy")
          break
        }
        if (!is.null(decision@model)) {
          agent@options@model <- decision@model
        }
        if (length(decision@stream_options)) {
          agent@options@stream_options <- utils::modifyList(
            agent@options@stream_options,
            decision@stream_options
          )
        }
        if (decision@stop || isTRUE(agent@state$cancelled)) {
          if (isTRUE(agent@state$cancelled)) {
            run_error <- rho_agent_error(
              rho_agent_cancel_message(agent, "Agent run was cancelled"),
              "aborted"
            )
          }
          break
        }

        pending <- coro::await(rho.async::rho_as_promise(rho_take_agent_queue(
          agent@options@steering_mode,
          agent,
          "steering_queue",
          "steering"
        )))
        continue_tools <- length(rho_tool_calls(assistant)) > 0L && !batch@terminate
        if (continue_tools || length(pending)) {
          next
        }

        pending <- coro::await(rho.async::rho_as_promise(rho_take_agent_queue(
          agent@options@follow_up_mode,
          agent,
          "follow_up_queue",
          "follow_up"
        )))
        if (!length(pending)) break
      }

      run_status <- rho_agent_run_status_from_error(run_error)
      coro::await(rho.async::rho_as_promise(
        rho_emit_agent_event(agent, rho_agent_end_event(agent@state$messages))
      ))
      rho_set_agent_idle(agent)
      coro::await(rho.async::rho_as_promise(
        rho_emit_agent_event(agent, rho_agent_settled_event(run_status))
      ))
      rho_agent_run_result(
        agent,
        events_before,
        tool_results,
        status = run_status,
        error = run_error,
        context = run_context
      )
    },
    label = "agent-loop"
  )
}
