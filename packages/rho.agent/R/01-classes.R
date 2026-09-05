RhoToolExecutionMode <- S7::new_class("RhoToolExecutionMode", abstract = TRUE)
RhoParallelToolExecution <- S7::new_class(
  "RhoParallelToolExecution",
  parent = RhoToolExecutionMode
)
RhoSequentialToolExecution <- S7::new_class(
  "RhoSequentialToolExecution",
  parent = RhoToolExecutionMode
)

RhoQueueMode <- S7::new_class("RhoQueueMode", abstract = TRUE)
RhoOneAtATimeQueue <- S7::new_class("RhoOneAtATimeQueue", parent = RhoQueueMode)
RhoAllQueue <- S7::new_class("RhoAllQueue", parent = RhoQueueMode)

RhoAgentPhase <- S7::new_class("RhoAgentPhase", abstract = TRUE)
RhoAgentIdle <- S7::new_class("RhoAgentIdle", parent = RhoAgentPhase)
RhoAgentRunning <- S7::new_class("RhoAgentRunning", parent = RhoAgentPhase)
RhoAgentCompacting <- S7::new_class(
  "RhoAgentCompacting",
  parent = RhoAgentPhase
)

rho_agent_run_status <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !value %in% c("completed", "error", "aborted")) {
      "must be 'completed', 'error', or 'aborted'"
    }
  }
)

rho_nonnegative_integer <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) "must be one non-negative integer"
  }
)

rho_positive_integer <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) {
      "must be one positive integer"
    }
  }
)

rho_nonnegative_double <- S7::new_property(
  S7::class_double,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0) {
      "must be one non-negative number"
    }
  }
)

rho_scalar_double <- S7::new_property(
  S7::class_double,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing number"
    }
  }
)

rho_scalar_logical <- S7::new_property(
  S7::class_logical,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing logical value"
    }
  }
)

rho_optional_positive_integer <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (
      !is.null(value) &&
        (!is.integer(value) || length(value) != 1L || is.na(value) || value <= 0L)
    ) {
      "must be NULL or one positive integer"
    }
  }
)

rho_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

RhoCompactionReason <- S7::new_class("RhoCompactionReason", abstract = TRUE)
RhoManualCompaction <- S7::new_class(
  "RhoManualCompaction",
  parent = RhoCompactionReason
)
RhoThresholdCompaction <- S7::new_class(
  "RhoThresholdCompaction",
  parent = RhoCompactionReason
)
RhoProviderInputLimitCompaction <- S7::new_class(
  "RhoProviderInputLimitCompaction",
  parent = RhoCompactionReason
)

RhoCompactionSource <- S7::new_class("RhoCompactionSource", abstract = TRUE)
RhoGeneratedCompaction <- S7::new_class(
  "RhoGeneratedCompaction",
  parent = RhoCompactionSource
)
RhoProvidedCompaction <- S7::new_class(
  "RhoProvidedCompaction",
  parent = RhoCompactionSource
)

RhoCompactionOutcome <- S7::new_class("RhoCompactionOutcome", abstract = TRUE)
RhoCompactionSkipped <- S7::new_class(
  "RhoCompactionSkipped",
  parent = RhoCompactionOutcome,
  properties = list(
    message = rho_non_empty_string,
    details = S7::class_list
  )
)
RhoNothingToCompact <- S7::new_class(
  "RhoNothingToCompact",
  parent = RhoCompactionSkipped
)
RhoCompactionCancelled <- S7::new_class(
  "RhoCompactionCancelled",
  parent = RhoCompactionSkipped
)

RhoCompactor <- S7::new_class("RhoCompactor", abstract = TRUE)
RhoSummaryCompactor <- S7::new_class("RhoSummaryCompactor", parent = RhoCompactor)

RhoCompactionSettings <- S7::new_class(
  "RhoCompactionSettings",
  properties = list(
    enabled = rho_scalar_logical,
    reserve_tokens = rho_positive_integer,
    keep_recent_tokens = rho_positive_integer
  )
)

RhoContextUsage <- S7::new_class(
  "RhoContextUsage",
  properties = list(
    tokens = rho_nonnegative_double,
    usage_tokens = rho_nonnegative_double,
    trailing_tokens = rho_nonnegative_double,
    last_usage_index = rho_optional_positive_integer
  )
)

RhoSessionEntry <- S7::new_class(
  "RhoSessionEntry",
  abstract = TRUE,
  properties = list(
    id = rho_non_empty_string,
    timestamp = rho_nonnegative_double
  )
)

rho_session_parent_id <- S7::new_property(
  S7::class_character,
  default = "",
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing entry identifier or the empty root identifier"
    }
  }
)

RhoSessionNodeEntry <- S7::new_class(
  "RhoSessionNodeEntry",
  parent = RhoSessionEntry,
  abstract = TRUE,
  properties = list(parent_id = rho_session_parent_id)
)

rho_session_message <- S7::new_property(
  S7::class_any,
  validator = function(value) {
    if (
      !S7::S7_inherits(value, rho.ai::UserMessage) &&
        !S7::S7_inherits(value, rho.ai::AssistantMessage) &&
        !S7::S7_inherits(value, rho.ai::ToolResultMessage)
    ) {
      "must be a UserMessage, AssistantMessage, or ToolResultMessage"
    }
  }
)

rho_session_messages <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    invalid <- Filter(
      function(message) {
        !S7::S7_inherits(message, rho.ai::UserMessage) &&
          !S7::S7_inherits(message, rho.ai::AssistantMessage) &&
          !S7::S7_inherits(message, rho.ai::ToolResultMessage)
      },
      value
    )
    if (length(invalid)) {
      "must contain only UserMessage, AssistantMessage, or ToolResultMessage values"
    }
  }
)

RhoSessionMessageEntry <- S7::new_class(
  "RhoSessionMessageEntry",
  parent = RhoSessionNodeEntry,
  properties = list(message = rho_session_message)
)

RhoCompactionPreparation <- S7::new_class(
  "RhoCompactionPreparation",
  properties = list(
    first_kept_entry_id = rho_non_empty_string,
    messages = rho_session_messages,
    turn_prefix = rho_session_messages,
    split_turn = rho_scalar_logical,
    tokens_before = rho_nonnegative_double,
    previous_summary = S7::class_character,
    settings = RhoCompactionSettings
  )
)

RhoCompactionCheckpoint <- S7::new_class(
  "RhoCompactionCheckpoint",
  properties = list(
    start = rho_positive_integer,
    previous_summary = S7::class_character,
    timestamp = rho_scalar_double
  )
)

RhoCompactionCut <- S7::new_class(
  "RhoCompactionCut",
  properties = list(
    first_kept = rho_positive_integer,
    turn_start = rho_optional_positive_integer,
    split_turn = rho_scalar_logical
  )
)

RhoCompactionResult <- S7::new_class(
  "RhoCompactionResult",
  parent = RhoCompactionOutcome,
  properties = list(
    summary = rho_non_empty_string,
    first_kept_entry_id = rho_non_empty_string,
    tokens_before = rho_nonnegative_double,
    details = S7::class_any,
    source = RhoCompactionSource
  )
)

RhoSessionCompactionEntry <- S7::new_class(
  "RhoSessionCompactionEntry",
  parent = RhoSessionNodeEntry,
  properties = list(
    result = RhoCompactionResult,
    reason = RhoCompactionReason,
    will_retry = rho_scalar_logical
  )
)

RhoSessionContextExclusionEntry <- S7::new_class(
  "RhoSessionContextExclusionEntry",
  parent = RhoSessionNodeEntry,
  properties = list(
    target_entry_id = rho_non_empty_string,
    reason = RhoCompactionReason
  )
)

RhoSessionResetEntry <- S7::new_class(
  "RhoSessionResetEntry",
  parent = RhoSessionNodeEntry
)

RhoSessionLeafEntry <- S7::new_class(
  "RhoSessionLeafEntry",
  parent = RhoSessionEntry,
  properties = list(
    previous_leaf_id = rho_session_parent_id,
    target_leaf_id = rho_session_parent_id
  )
)

rho_session_identifier <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty session identifier"
    }
  }
)

rho_optional_session_identifier <- S7::new_property(
  S7::class_character,
  default = "",
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing session identifier or the empty root identifier"
    }
  }
)

RhoSessionIdentity <- S7::new_class(
  "RhoSessionIdentity",
  properties = list(
    id = rho_session_identifier,
    parent_id = rho_optional_session_identifier
  )
)

rho_session_entry_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    invalid <- Filter(
      function(entry) !S7::S7_inherits(entry, RhoSessionEntry),
      value
    )
    if (length(invalid)) {
      "must contain only RhoSessionEntry values"
    }
  }
)

RhoSessionCommit <- S7::new_class(
  "RhoSessionCommit",
  properties = list(
    identity = RhoSessionIdentity,
    entry = RhoSessionEntry,
    position = rho_positive_integer,
    leaf_id = rho_session_parent_id
  )
)

RhoSessionAppend <- S7::new_class(
  "RhoSessionAppend",
  properties = list(
    entry = RhoSessionEntry,
    after = rho_nonnegative_integer
  )
)

RhoSessionSnapshot <- S7::new_class(
  "RhoSessionSnapshot",
  properties = list(
    identity = RhoSessionIdentity,
    entries = rho_session_entry_list,
    position = rho_nonnegative_integer,
    leaf_id = rho_session_parent_id
  ),
  validator = function(self) {
    if (length(self@entries) != self@position) {
      return("@position must equal the number of committed entries")
    }
    ids <- vapply(self@entries, function(entry) entry@id, character(1))
    if (anyDuplicated(ids)) {
      return("@entries must have unique identifiers")
    }
    replay <- rho_replay_session_entries(self@entries)
    if (is.character(replay)) {
      return(replay)
    }
    if (!identical(replay@leaf_id, self@leaf_id)) {
      "@leaf_id must equal the selected leaf after replaying @entries"
    }
  }
)

RhoSessionReplay <- S7::new_class(
  "RhoSessionReplay",
  properties = list(
    leaf_id = rho_session_parent_id,
    node_ids = S7::class_character
  )
)

RhoSessionTrajectory <- S7::new_class(
  "RhoSessionTrajectory",
  properties = list(
    identity = RhoSessionIdentity,
    source_position = rho_nonnegative_integer,
    leaf_id = rho_session_parent_id,
    entries = rho_session_entry_list
  ),
  validator = function(self) {
    invalid <- Filter(
      function(entry) !S7::S7_inherits(entry, RhoSessionNodeEntry),
      self@entries
    )
    if (length(invalid)) {
      return("@entries must contain only context-bearing session nodes")
    }
    if (length(self@entries)) {
      terminal <- self@entries[[length(self@entries)]]@id
      if (!identical(terminal, self@leaf_id)) {
        return("@leaf_id must identify the final trajectory entry")
      }
    } else if (nzchar(self@leaf_id)) {
      return("an empty trajectory must have the empty root leaf")
    }
  }
)

rho_memory_session_state <- S7::new_property(
  S7::class_environment,
  validator = function(value) {
    if (
      !exists("current", value, inherits = FALSE) ||
        !S7::S7_inherits(value$current, RhoSessionSnapshot)
    ) {
      "must contain a validated RhoSessionSnapshot at `current`"
    }
  }
)

RhoMemorySessionJournal <- S7::new_class(
  "RhoMemorySessionJournal",
  properties = list(state = rho_memory_session_state)
)

rho_session_journal <- S7::new_property(
  S7::class_any,
  validator = function(value) {
    if (!s7contract::implements(value, SessionJournal)) {
      missing <- s7contract::missing_requirements(value, SessionJournal)
      paste(missing$message[!missing$ok], collapse = "; ")
    }
  }
)

rho_optional_session_entry_id <- S7::new_property(
  S7::class_character,
  default = "",
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing string"
    }
  }
)

RhoAgentPolicy <- S7::new_class("RhoAgentPolicy", abstract = TRUE)
RhoDefaultAgentPolicy <- S7::new_class("RhoDefaultAgentPolicy", parent = RhoAgentPolicy)

RhoAgentOptions <- S7::new_class(
  "RhoAgentOptions",
  properties = list(
    provider = S7::class_any,
    model = rho.ai::Model,
    system_prompt = S7::class_character,
    operations = S7::class_list,
    tool_execution = RhoToolExecutionMode,
    steering_mode = RhoQueueMode,
    follow_up_mode = RhoQueueMode,
    policy = RhoAgentPolicy,
    compaction = RhoCompactionSettings,
    compactor = RhoCompactor,
    stream_options = S7::class_list
  )
)

RhoAgent <- S7::new_class(
  "RhoAgent",
  properties = list(
    state = S7::class_environment,
    options = RhoAgentOptions,
    journal = rho_session_journal
  ),
  validator = function(self) {
    required <- c(
      "messages",
      "entries",
      "session_id",
      "parent_session_id",
      "leaf_id",
      "journal_position",
      "tools",
      "listeners",
      "steering_queue",
      "follow_up_queue",
      "phase",
      "pending_tool_calls",
      "active_tool_tasks",
      "active_tool_sequence",
      "events",
      "event_sequence",
      "run_sequence",
      "idle_condition",
      "idle_waiters",
      "cancelled",
      "cancel_reason"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
  }
)

rho_run_context_id <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

rho_optional_update_handler <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !is.function(value)) "must be NULL or a function"
  }
)

RhoRunContext <- S7::new_class(
  "RhoRunContext",
  properties = list(
    id = rho_run_context_id,
    agent = RhoAgent,
    application = S7::class_any,
    state = S7::class_environment
  )
)

RhoToolContext <- S7::new_class(
  "RhoToolContext",
  properties = list(
    run = RhoRunContext,
    model_context = rho.ai::Context,
    assistant = rho.ai::AssistantMessage,
    tool = rho.ai::ToolSpec,
    call = rho.ai::ToolCall,
    arguments = S7::class_list,
    signal = S7::new_property(S7::class_any, default = NULL),
    on_update = rho_optional_update_handler
  )
)

RhoCompletedToolContext <- S7::new_class(
  "RhoCompletedToolContext",
  parent = RhoToolContext,
  properties = list(
    result = rho.ai::ToolResult,
    is_error = S7::class_logical
  )
)

rho_optional_run_context <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, RhoRunContext)) {
      "must be NULL or a RhoRunContext value"
    }
  }
)

RhoAgentErrorValue <- S7::new_class(
  "RhoAgentErrorValue",
  properties = list(
    kind = S7::class_character,
    message = S7::class_character,
    retryable = S7::class_logical,
    details = S7::class_list
  )
)

RhoSessionJournalErrorValue <- S7::new_class(
  "RhoSessionJournalErrorValue",
  parent = RhoAgentErrorValue
)

RhoSessionConflictErrorValue <- S7::new_class(
  "RhoSessionConflictErrorValue",
  parent = RhoSessionJournalErrorValue
)

RhoCompactionErrorValue <- S7::new_class(
  "RhoCompactionErrorValue",
  parent = RhoAgentErrorValue
)
RhoCompactionFailure <- S7::new_class(
  "RhoCompactionFailure",
  parent = RhoCompactionErrorValue
)
RhoCompactionBusy <- S7::new_class(
  "RhoCompactionBusy",
  parent = RhoCompactionErrorValue
)

RhoAgentRunResult <- S7::new_class(
  "RhoAgentRunResult",
  properties = list(
    messages = S7::class_list,
    entries = S7::class_list,
    tool_results = S7::class_list,
    events = S7::class_list,
    status = rho_agent_run_status,
    error = S7::class_any,
    context = rho_optional_run_context,
    usage = rho.ai::UsageSummary
  )
)

RhoBeforeToolCallDecision <- S7::new_class(
  "RhoBeforeToolCallDecision",
  properties = list(block = S7::class_logical, reason = S7::class_character)
)

RhoAfterToolCallDecision <- S7::new_class(
  "RhoAfterToolCallDecision",
  properties = list(result = rho.ai::ToolResult, is_error = S7::class_logical)
)

RhoNextTurnDecision <- S7::new_class(
  "RhoNextTurnDecision",
  properties = list(
    stop = S7::class_logical,
    context = S7::class_any,
    model = S7::class_any,
    stream_options = S7::class_list
  )
)

RhoAssistantTurn <- S7::new_class(
  "RhoAssistantTurn",
  properties = list(state = S7::class_environment),
  validator = function(self) {
    required <- c(
      "agent",
      "started",
      "commit",
      "message",
      "terminal",
      "error"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
  }
)

RhoAssistantResponse <- S7::new_class(
  "RhoAssistantResponse",
  properties = list(
    message = rho.ai::AssistantMessage,
    error = S7::class_any,
    entry_id = rho_optional_session_entry_id
  )
)

RhoToolBatch <- S7::new_class(
  "RhoToolBatch",
  properties = list(messages = S7::class_list, terminate = S7::class_logical)
)

rho_optional_compaction_result <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, RhoCompactionResult)) {
      "must be NULL or a RhoCompactionResult"
    }
  }
)

rho_optional_compaction_outcome <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, RhoCompactionOutcome)) {
      "must be NULL or a RhoCompactionOutcome"
    }
  }
)

rho_optional_compaction_error <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, RhoCompactionErrorValue)) {
      "must be NULL or a RhoCompactionErrorValue"
    }
  }
)

RhoBeforeCompactionContext <- S7::new_class(
  "RhoBeforeCompactionContext",
  properties = list(
    agent = RhoAgent,
    preparation = RhoCompactionPreparation,
    reason = RhoCompactionReason,
    will_retry = rho_scalar_logical,
    custom_instructions = S7::class_character
  )
)

RhoBeforeCompactionDecision <- S7::new_class(
  "RhoBeforeCompactionDecision",
  properties = list(
    cancel = rho_scalar_logical,
    result = rho_optional_compaction_result
  ),
  validator = function(self) {
    if (self@cancel && !is.null(self@result)) {
      "@result must be NULL when @cancel is TRUE"
    }
  }
)

RhoAfterCompactionContext <- S7::new_class(
  "RhoAfterCompactionContext",
  properties = list(
    agent = RhoAgent,
    entry = RhoSessionCompactionEntry,
    result = RhoCompactionResult,
    reason = RhoCompactionReason,
    will_retry = rho_scalar_logical
  )
)

RhoAgentEvent <- S7::new_class(
  "RhoAgentEvent",
  abstract = TRUE,
  properties = list(
    type = S7::class_character,
    sequence = rho_nonnegative_integer,
    timestamp = S7::class_double
  )
)

RhoAgentStartEvent <- S7::new_class("RhoAgentStartEvent", parent = RhoAgentEvent)
RhoAgentEndEvent <- S7::new_class(
  "RhoAgentEndEvent",
  parent = RhoAgentEvent,
  properties = list(messages = S7::class_list)
)
RhoAgentSettledEvent <- S7::new_class(
  "RhoAgentSettledEvent",
  parent = RhoAgentEvent,
  properties = list(status = rho_agent_run_status)
)
RhoTurnStartEvent <- S7::new_class(
  "RhoTurnStartEvent",
  parent = RhoAgentEvent,
  properties = list(turn = rho_nonnegative_integer)
)
RhoTurnEndEvent <- S7::new_class(
  "RhoTurnEndEvent",
  parent = RhoAgentEvent,
  properties = list(
    turn = rho_nonnegative_integer,
    message = rho.ai::AssistantMessage,
    tool_results = S7::class_list
  )
)
RhoMessageEvent <- S7::new_class(
  "RhoMessageEvent",
  abstract = TRUE,
  parent = RhoAgentEvent,
  properties = list(message = S7::class_any)
)
RhoMessageStartEvent <- S7::new_class("RhoMessageStartEvent", parent = RhoMessageEvent)
RhoMessageEndEvent <- S7::new_class("RhoMessageEndEvent", parent = RhoMessageEvent)
RhoMessageUpdateEvent <- S7::new_class(
  "RhoMessageUpdateEvent",
  parent = RhoMessageEvent,
  properties = list(assistant_event = rho.ai::AssistantUpdateEvent)
)
RhoToolExecutionStartEvent <- S7::new_class(
  "RhoToolExecutionStartEvent",
  parent = RhoAgentEvent,
  properties = list(call = rho.ai::ToolCall)
)
RhoToolExecutionUpdateEvent <- S7::new_class(
  "RhoToolExecutionUpdateEvent",
  parent = RhoAgentEvent,
  properties = list(call = rho.ai::ToolCall, partial_result = S7::class_any)
)
RhoToolExecutionEndEvent <- S7::new_class(
  "RhoToolExecutionEndEvent",
  parent = RhoAgentEvent,
  properties = list(
    call = rho.ai::ToolCall,
    result = rho.ai::ToolResult,
    is_error = S7::class_logical
  )
)
RhoQueueUpdateEvent <- S7::new_class(
  "RhoQueueUpdateEvent",
  parent = RhoAgentEvent,
  properties = list(queue = S7::class_character, size = rho_nonnegative_integer)
)
RhoCompactionStartEvent <- S7::new_class(
  "RhoCompactionStartEvent",
  parent = RhoAgentEvent,
  properties = list(
    reason = RhoCompactionReason,
    will_retry = rho_scalar_logical,
    preparation = RhoCompactionPreparation
  )
)
RhoCompactionEndEvent <- S7::new_class(
  "RhoCompactionEndEvent",
  parent = RhoAgentEvent,
  properties = list(
    reason = RhoCompactionReason,
    will_retry = rho_scalar_logical,
    outcome = rho_optional_compaction_outcome,
    error = rho_optional_compaction_error
  )
)
