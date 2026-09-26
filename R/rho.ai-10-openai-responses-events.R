rho_openai_output_index <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer"
    }
  }
)

OpenAIResponseDecoder <- S7::new_class(
  "OpenAIResponseDecoder",
  properties = list(
    model = Model,
    state = S7::class_environment
  ),
  validator = function(self) {
    required <- c("started", "content", "slots", "response_id")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)

OpenAIResponseSlot <- S7::new_class(
  "OpenAIResponseSlot",
  properties = list(
    output_index = rho_openai_output_index,
    content_index = rho_openai_output_index,
    buffer = S7::class_character
  )
)

OpenAIResponseItem <- S7::new_class(
  "OpenAIResponseItem",
  abstract = TRUE,
  properties = list(payload = S7::class_list)
)

OpenAIReasoningItem <- S7::new_class(
  "OpenAIReasoningItem",
  parent = OpenAIResponseItem,
  properties = list(
    id = S7::class_character,
    summary = S7::class_list,
    content = S7::class_list
  )
)

OpenAIMessageItem <- S7::new_class(
  "OpenAIMessageItem",
  parent = OpenAIResponseItem,
  properties = list(
    id = S7::class_character,
    content = S7::class_list,
    phase = S7::class_character
  )
)

OpenAIFunctionCallItem <- S7::new_class(
  "OpenAIFunctionCallItem",
  parent = OpenAIResponseItem,
  properties = list(
    id = S7::class_character,
    call_id = S7::class_character,
    name = S7::class_character,
    arguments = S7::class_character
  )
)

OpenAIWebSearchCallItem <- S7::new_class(
  "OpenAIWebSearchCallItem",
  parent = OpenAIResponseItem,
  properties = list(
    id = rho_non_empty_string,
    status = OperationStatus,
    action = WebSearchAction
  )
)

OpenAIUnsupportedItem <- S7::new_class(
  "OpenAIUnsupportedItem",
  parent = OpenAIResponseItem,
  properties = list(type = S7::class_character)
)

OpenAIResponseWireEvent <- S7::new_class("OpenAIResponseWireEvent", abstract = TRUE)

OpenAIResponseJsonEvent <- S7::new_class(
  "OpenAIResponseJsonEvent",
  properties = list(
    data = rho_non_empty_string,
    transport = ProviderTransport
  )
)

OpenAIResponseIgnored <- S7::new_class(
  "OpenAIResponseIgnored",
  parent = OpenAIResponseWireEvent,
  properties = list(type = S7::class_character, payload = S7::class_list)
)

OpenAIResponseCreated <- S7::new_class(
  "OpenAIResponseCreated",
  parent = OpenAIResponseWireEvent,
  properties = list(response = S7::class_list)
)

OpenAIResponseOutputItemAdded <- S7::new_class(
  "OpenAIResponseOutputItemAdded",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, item = OpenAIResponseItem)
)

OpenAIResponseThinkingDelta <- S7::new_class(
  "OpenAIResponseThinkingDelta",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, delta = S7::class_character)
)

OpenAIResponseThinkingBreak <- S7::new_class(
  "OpenAIResponseThinkingBreak",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index)
)

OpenAIResponseTextDelta <- S7::new_class(
  "OpenAIResponseTextDelta",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, delta = S7::class_character)
)

OpenAIResponseToolArgumentsDelta <- S7::new_class(
  "OpenAIResponseToolArgumentsDelta",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, delta = S7::class_character)
)

OpenAIResponseToolArgumentsDone <- S7::new_class(
  "OpenAIResponseToolArgumentsDone",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, arguments = S7::class_character)
)

OpenAIResponseOutputItemDone <- S7::new_class(
  "OpenAIResponseOutputItemDone",
  parent = OpenAIResponseWireEvent,
  properties = list(output_index = rho_openai_output_index, item = OpenAIResponseItem)
)

OpenAIResponseCompleted <- S7::new_class(
  "OpenAIResponseCompleted",
  parent = OpenAIResponseWireEvent,
  properties = list(response = S7::class_list)
)

OpenAIResponseIncomplete <- S7::new_class(
  "OpenAIResponseIncomplete",
  parent = OpenAIResponseWireEvent,
  properties = list(response = S7::class_list)
)

OpenAIResponseError <- S7::new_class(
  "OpenAIResponseError",
  parent = OpenAIResponseWireEvent,
  properties = list(error = ProviderErrorValue)
)

rho_openai_reasoning_item <- function(payload) {
  OpenAIReasoningItem(
    payload = payload,
    id = as.character(payload$id %||% ""),
    summary = payload$summary %||% list(),
    content = payload$content %||% list()
  )
}

rho_openai_message_item <- function(payload) {
  OpenAIMessageItem(
    payload = payload,
    id = as.character(payload$id %||% ""),
    content = payload$content %||% list(),
    phase = as.character(payload$phase %||% "")
  )
}

rho_openai_function_call_item <- function(payload) {
  OpenAIFunctionCallItem(
    payload = payload,
    id = as.character(payload$id %||% ""),
    call_id = as.character(payload$call_id %||% payload$id %||% ""),
    name = as.character(payload$name %||% ""),
    arguments = as.character(payload$arguments %||% "")
  )
}

rho_openai_operation_status_factories <- list(
  queued = OperationPending,
  in_progress = OperationInProgress,
  searching = OperationInProgress,
  completed = OperationCompleted,
  failed = OperationFailed
)

rho_openai_operation_status <- function(value) {
  factory <- rho_openai_operation_status_factories[[as.character(value %||% "queued")]] %||%
    OperationPending
  factory()
}

rho_openai_web_search_search_action <- function(payload) {
  queries <- payload$queries %||% payload$query %||% character()
  WebSearchSearchAction(
    queries = as.character(queries),
    sources = payload$sources %||% list()
  )
}

rho_openai_web_search_open_action <- function(payload) {
  WebSearchOpenPageAction(url = as.character(payload$url %||% ""))
}

rho_openai_web_search_find_action <- function(payload) {
  WebSearchFindInPageAction(
    url = as.character(payload$url %||% ""),
    pattern = as.character(payload$pattern %||% "")
  )
}

rho_openai_web_search_unknown_action <- function(payload) {
  WebSearchUnknownAction(payload = payload)
}

rho_openai_web_search_action_factories <- list(
  search = rho_openai_web_search_search_action,
  open_page = rho_openai_web_search_open_action,
  find_in_page = rho_openai_web_search_find_action
)

rho_openai_web_search_action <- function(payload = NULL) {
  if (is.null(payload)) {
    return(WebSearchActionUnspecified())
  }
  factory <- rho_openai_web_search_action_factories[[as.character(payload$type %||% "")]] %||%
    rho_openai_web_search_unknown_action
  factory(payload)
}

rho_openai_web_search_call_item <- function(payload) {
  OpenAIWebSearchCallItem(
    payload = payload,
    id = as.character(payload$id %||% ""),
    status = rho_openai_operation_status(payload$status),
    action = rho_openai_web_search_action(payload$action)
  )
}

rho_openai_unsupported_item <- function(payload) {
  OpenAIUnsupportedItem(
    payload = payload,
    type = as.character(payload$type %||% "")
  )
}

rho_openai_response_item_factories <- list(
  reasoning = rho_openai_reasoning_item,
  message = rho_openai_message_item,
  function_call = rho_openai_function_call_item,
  web_search_call = rho_openai_web_search_call_item
)

rho_openai_response_item <- function(payload) {
  type <- as.character(payload$type %||% "")
  factory <- rho_openai_response_item_factories[[type]] %||% rho_openai_unsupported_item
  factory(payload)
}

rho_openai_response_created <- function(payload) {
  OpenAIResponseCreated(response = payload$response %||% list())
}

rho_openai_response_output_item_added <- function(payload) {
  OpenAIResponseOutputItemAdded(
    output_index = as.integer(payload$output_index %||% 0L),
    item = rho_openai_response_item(payload$item %||% list())
  )
}

rho_openai_response_thinking_delta <- function(payload) {
  OpenAIResponseThinkingDelta(
    output_index = as.integer(payload$output_index %||% 0L),
    delta = as.character(payload$delta %||% "")
  )
}

rho_openai_response_thinking_break <- function(payload) {
  OpenAIResponseThinkingBreak(output_index = as.integer(payload$output_index %||% 0L))
}

rho_openai_response_text_delta <- function(payload) {
  OpenAIResponseTextDelta(
    output_index = as.integer(payload$output_index %||% 0L),
    delta = as.character(payload$delta %||% "")
  )
}

rho_openai_response_tool_arguments_delta <- function(payload) {
  OpenAIResponseToolArgumentsDelta(
    output_index = as.integer(payload$output_index %||% 0L),
    delta = as.character(payload$delta %||% "")
  )
}

rho_openai_response_tool_arguments_done <- function(payload) {
  OpenAIResponseToolArgumentsDone(
    output_index = as.integer(payload$output_index %||% 0L),
    arguments = as.character(payload$arguments %||% "{}")
  )
}

rho_openai_response_output_item_done <- function(payload) {
  OpenAIResponseOutputItemDone(
    output_index = as.integer(payload$output_index %||% 0L),
    item = rho_openai_response_item(payload$item %||% list())
  )
}

rho_openai_response_completed <- function(payload) {
  OpenAIResponseCompleted(response = payload$response %||% list())
}

rho_openai_response_incomplete <- function(payload) {
  OpenAIResponseIncomplete(response = payload$response %||% list())
}

rho_openai_input_limit_error_factories <- list(
  context_length_exceeded = function(message, code, details) {
    rho_provider_context_overflow(message, code, details)
  },
  model_context_window_exceeded = function(message, code, details) {
    rho_provider_context_overflow(message, code, details)
  }
)

rho_openai_api_error_value <- function(
  message,
  code,
  details,
  kind = "api",
  retryable = FALSE
) {
  factory <- rho_openai_input_limit_error_factories[[code]]
  if (!is.null(factory)) {
    return(factory(message, code, details))
  }
  rho_provider_error(
    message = message,
    kind = kind,
    code = code,
    retryable = retryable,
    details = details
  )
}

rho_openai_response_api_error <- function(payload) {
  nested <- payload$error %||% list()
  OpenAIResponseError(
    error = rho_openai_api_error_value(
      message = as.character(
        payload$message %||% nested$message %||% "OpenAI Codex request failed"
      ),
      code = as.character(payload$code %||% nested$code %||% ""),
      details = payload
    )
  )
}

rho_openai_response_failed <- function(payload) {
  response <- payload$response %||% list()
  nested <- response$error %||% list()
  OpenAIResponseError(
    error = rho_openai_api_error_value(
      message = as.character(nested$message %||% "OpenAI Codex response failed"),
      code = as.character(nested$code %||% ""),
      details = payload
    )
  )
}

S7::method(
  rho_provider_http_error,
  list(OpenAIResponsesModel, RhoHttpStatusError)
) <- function(model, error, ...) {
  document <- rho_http_error_document(error)
  nested <- if (is.list(document$error)) document$error else NULL
  if (is.null(nested)) {
    return(rho_http_status_provider_error(error))
  }
  rho_openai_api_error_value(
    message = as.character(nested$message %||% error@message),
    code = as.character(nested$code %||% error@status),
    details = rho_http_error_details(error),
    retryable = rho_http_status_retryable(error)
  )
}

rho_openai_response_event_factories <- list(
  "response.created" = rho_openai_response_created,
  "response.output_item.added" = rho_openai_response_output_item_added,
  "response.reasoning_summary_text.delta" = rho_openai_response_thinking_delta,
  "response.reasoning_text.delta" = rho_openai_response_thinking_delta,
  "response.reasoning_summary_part.done" = rho_openai_response_thinking_break,
  "response.output_text.delta" = rho_openai_response_text_delta,
  "response.refusal.delta" = rho_openai_response_text_delta,
  "response.function_call_arguments.delta" = rho_openai_response_tool_arguments_delta,
  "response.function_call_arguments.done" = rho_openai_response_tool_arguments_done,
  "response.output_item.done" = rho_openai_response_output_item_done,
  "response.completed" = rho_openai_response_completed,
  "response.done" = rho_openai_response_completed,
  "response.incomplete" = rho_openai_response_incomplete,
  "error" = rho_openai_response_api_error,
  "response.failed" = rho_openai_response_failed
)

rho_openai_response_wire_event <- function(payload) {
  type <- as.character(payload$type %||% "")
  factory <- rho_openai_response_event_factories[[type]]
  if (is.null(factory)) {
    return(OpenAIResponseIgnored(type = type, payload = payload))
  }
  factory(payload)
}

rho_openai_response_protocol_error <- function(message, details = list()) {
  OpenAIResponseError(
    error = rho_provider_error(
      message = message,
      kind = "protocol",
      details = details
    )
  )
}

rho_openai_decode_response_json <- function(data, source) {
  if (!nzchar(data) || identical(data, "[DONE]")) {
    return(OpenAIResponseIgnored(type = "", payload = list()))
  }
  payload <- tryCatch(
    yyjsonr::read_json_str(
      data,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(payload, "error")) {
    return(rho_openai_response_protocol_error(
      sprintf("Invalid OpenAI Responses %s JSON: %s", source, conditionMessage(payload)),
      details = list(data = data, source = source)
    ))
  }
  rho_openai_response_wire_event(payload)
}

rho_openai_decode_wire_event <- function(event) {
  rho_openai_decode_response_json(event@data, "SSE")
}

rho_openai_responses_decoder <- function(model) {
  state <- new.env(parent = emptyenv())
  state$started <- FALSE
  state$content <- list()
  state$slots <- list()
  state$response_id <- ""
  OpenAIResponseDecoder(model = model, state = state)
}

rho_openai_responses_partial_message <- function(decoder, stop_reason = "stop", usage = NULL) {
  rho_assistant_message(
    content = decoder@state$content,
    provider = decoder@model@provider,
    model = decoder@model@id,
    stop_reason = stop_reason,
    usage = usage,
    response_id = decoder@state$response_id
  )
}

rho_openai_begin_events <- function(decoder) {
  if (decoder@state$started) {
    return(list())
  }
  decoder@state$started <- TRUE
  list(rho_assistant_start_event(rho_openai_responses_partial_message(decoder)))
}

rho_openai_response_slot_key <- function(output_index) as.character(output_index)

rho_openai_response_slot <- function(decoder, output_index) {
  decoder@state$slots[[rho_openai_response_slot_key(output_index)]]
}

rho_openai_store_response_slot <- function(decoder, slot) {
  decoder@state$slots[[rho_openai_response_slot_key(slot@output_index)]] <- slot
  invisible(slot)
}

rho_openai_remove_response_slot <- function(decoder, output_index) {
  decoder@state$slots[[rho_openai_response_slot_key(output_index)]] <- NULL
  invisible(decoder)
}

rho_openai_start_response_slot <- function(decoder, output_index, content, buffer = "") {
  decoder@state$content[[length(decoder@state$content) + 1L]] <- content
  slot <- OpenAIResponseSlot(
    output_index = output_index,
    content_index = as.integer(length(decoder@state$content)),
    buffer = buffer
  )
  rho_openai_store_response_slot(decoder, slot)
  slot
}

rho_openai_response_slot_content <- function(decoder, slot) {
  decoder@state$content[[slot@content_index]]
}

rho_openai_store_response_content <- function(decoder, slot, content) {
  decoder@state$content[[slot@content_index]] <- content
  invisible(content)
}

rho_openai_parse_arguments <- function(text, default_value = list()) {
  if (!nzchar(text)) {
    return(default_value)
  }
  value <- tryCatch(
    yyjsonr::read_json_str(text, arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE),
    error = function(error) default_value
  )
  if (is.list(value)) value else default_value
}

rho_openai_item_text <- function(parts, separator = "") {
  paste(
    vapply(
      parts,
      function(part) {
        as.character(part$text %||% part$refusal %||% "")
      },
      character(1)
    ),
    collapse = separator
  )
}

rho_openai_ensure_response_slot <- function(item, decoder, output_index) {
  slot <- rho_openai_response_slot(decoder, output_index)
  events <- list()
  if (is.null(slot)) {
    events <- rho_start_response_item(item, decoder, output_index)
    slot <- rho_openai_response_slot(decoder, output_index)
  }
  list(events = events, slot = slot)
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIResponseDecoder, RhoSseEvent)
) <- function(decoder, event, ...) {
  wire_event <- rho_openai_decode_wire_event(event)
  c(rho_openai_begin_events(decoder), rho_reduce_provider_event(wire_event, decoder))
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIResponseDecoder, OpenAIResponseJsonEvent)
) <- function(decoder, event, ...) {
  wire_event <- rho_openai_decode_response_json(event@data, rho_transport_id(event@transport))
  c(rho_openai_begin_events(decoder), rho_reduce_provider_event(wire_event, decoder))
}

rho_openai_error_events <- function(decoder, error) {
  c(
    rho_openai_begin_events(decoder),
    list(rho_assistant_error_event(
      error,
      rho_openai_responses_partial_message(decoder, stop_reason = "error")
    ))
  )
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIResponseDecoder, RhoHttpError)
) <- function(decoder, event, ...) {
  rho_openai_error_events(
    decoder,
    rho_provider_http_error(decoder@model, event)
  )
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIResponseDecoder, ProviderErrorValue)
) <- function(decoder, event, ...) {
  rho_openai_error_events(decoder, event)
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIResponseDecoder, S7::class_any)
) <- function(decoder, event, ...) {
  rho_openai_error_events(
    decoder,
    rho_provider_error(
      message = sprintf(
        "OpenAI response decoder cannot consume an event of class %s",
        rho_class_label(event)
      ),
      kind = "protocol",
      code = "unsupported_event",
      details = list(event_class = rho_class_label(event))
    )
  )
}

S7::method(rho_reduce_provider_event, OpenAIResponseIgnored) <- function(event, decoder, ...) list()

S7::method(rho_reduce_provider_event, OpenAIResponseCreated) <- function(event, decoder, ...) {
  decoder@state$response_id <- as.character(event@response$id %||% "")
  list()
}

S7::method(rho_reduce_provider_event, OpenAIResponseOutputItemAdded) <- function(
  event,
  decoder,
  ...
) {
  rho_start_response_item(event@item, decoder, event@output_index)
}

S7::method(rho_reduce_provider_event, OpenAIResponseThinkingDelta) <- function(
  event,
  decoder,
  ...
) {
  slot <- rho_openai_response_slot(decoder, event@output_index)
  if (is.null(slot)) {
    return(list())
  }
  content <- rho_openai_response_slot_content(decoder, slot)
  if (!S7::S7_inherits(content, ThinkingContent)) {
    return(list())
  }
  content@text <- paste0(content@text, event@delta)
  rho_openai_store_response_content(decoder, slot, content)
  list(rho_assistant_thinking_delta_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    event@delta
  ))
}

S7::method(rho_reduce_provider_event, OpenAIResponseThinkingBreak) <- function(
  event,
  decoder,
  ...
) {
  rho_reduce_provider_event(
    OpenAIResponseThinkingDelta(output_index = event@output_index, delta = "\n\n"),
    decoder
  )
}

S7::method(rho_reduce_provider_event, OpenAIResponseTextDelta) <- function(event, decoder, ...) {
  slot <- rho_openai_response_slot(decoder, event@output_index)
  if (is.null(slot)) {
    return(list())
  }
  content <- rho_openai_response_slot_content(decoder, slot)
  if (!S7::S7_inherits(content, TextContent)) {
    return(list())
  }
  content@text <- paste0(content@text, event@delta)
  rho_openai_store_response_content(decoder, slot, content)
  list(rho_assistant_text_delta_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    event@delta
  ))
}

S7::method(rho_reduce_provider_event, OpenAIResponseToolArgumentsDelta) <- function(
  event,
  decoder,
  ...
) {
  slot <- rho_openai_response_slot(decoder, event@output_index)
  if (is.null(slot)) {
    return(list())
  }
  content <- rho_openai_response_slot_content(decoder, slot)
  if (!S7::S7_inherits(content, ToolCall)) {
    return(list())
  }
  slot@buffer <- paste0(slot@buffer, event@delta)
  content@arguments <- rho_openai_parse_arguments(slot@buffer, content@arguments)
  rho_openai_store_response_slot(decoder, slot)
  rho_openai_store_response_content(decoder, slot, content)
  list(rho_assistant_tool_call_delta_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    event@delta
  ))
}

S7::method(rho_reduce_provider_event, OpenAIResponseToolArgumentsDone) <- function(
  event,
  decoder,
  ...
) {
  slot <- rho_openai_response_slot(decoder, event@output_index)
  if (is.null(slot)) {
    return(list())
  }
  content <- rho_openai_response_slot_content(decoder, slot)
  if (!S7::S7_inherits(content, ToolCall)) {
    return(list())
  }
  previous <- slot@buffer
  slot@buffer <- event@arguments
  content@arguments <- rho_openai_parse_arguments(event@arguments, content@arguments)
  rho_openai_store_response_slot(decoder, slot)
  rho_openai_store_response_content(decoder, slot, content)
  if (!startsWith(event@arguments, previous)) {
    return(list())
  }
  delta <- substr(event@arguments, nchar(previous) + 1L, nchar(event@arguments))
  if (!nzchar(delta)) {
    return(list())
  }
  list(rho_assistant_tool_call_delta_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    delta
  ))
}

S7::method(rho_reduce_provider_event, OpenAIResponseOutputItemDone) <- function(
  event,
  decoder,
  ...
) {
  rho_finish_response_item(event@item, decoder, event@output_index)
}

rho_openai_responses_usage <- function(decoder, response) {
  usage_data <- response$usage
  if (!is.list(usage_data) || !length(usage_data)) {
    return(rho_usage_unavailable(
      decoder@model@provider,
      "OpenAI Responses did not report token usage"
    ))
  }

  input_details <- usage_data$input_tokens_details %||% list()
  output_details <- usage_data$output_tokens_details %||% list()
  input_tokens <- as.double(usage_data$input_tokens %||% 0)
  output_tokens <- as.double(usage_data$output_tokens %||% 0)
  cached_tokens <- as.double(input_details$cached_tokens %||% 0)
  cache_write_tokens <- as.double(input_details$cache_write_tokens %||% 0)
  reasoning_tokens <- output_details$reasoning_tokens
  rho_price_usage(
    decoder@model,
    rho_provider_usage(
      provider = decoder@model@provider,
      input = max(0, input_tokens - cached_tokens - cache_write_tokens),
      output = output_tokens,
      cache_read = cached_tokens,
      cache_write = cache_write_tokens,
      reasoning = if (is.null(reasoning_tokens)) NULL else as.double(reasoning_tokens)
    )
  )
}

rho_openai_terminal_events <- function(decoder, response, incomplete = FALSE) {
  if (nzchar(as.character(response$id %||% ""))) {
    decoder@state$response_id <- as.character(response$id)
  }
  usage <- rho_openai_responses_usage(decoder, response)
  status <- as.character(response$status %||% if (incomplete) "incomplete" else "completed")
  stop_reasons <- c(
    completed = "stop",
    incomplete = "length",
    failed = "error",
    cancelled = "error",
    in_progress = "stop",
    queued = "stop"
  )
  stop_reason <- unname(stop_reasons[[status]] %||% "stop")
  has_tool_call <- any(vapply(
    decoder@state$content,
    function(content) S7::S7_inherits(content, ToolCall),
    logical(1)
  ))
  if (has_tool_call && identical(stop_reason, "stop")) {
    stop_reason <- "toolUse"
  }
  message <- rho_openai_responses_partial_message(decoder, stop_reason, usage)
  list(rho_assistant_done_event(message, stop_reason))
}

S7::method(rho_reduce_provider_event, OpenAIResponseCompleted) <- function(event, decoder, ...) {
  rho_openai_terminal_events(decoder, event@response)
}

S7::method(rho_reduce_provider_event, OpenAIResponseIncomplete) <- function(event, decoder, ...) {
  rho_openai_terminal_events(decoder, event@response, incomplete = TRUE)
}

S7::method(rho_reduce_provider_event, OpenAIResponseError) <- function(event, decoder, ...) {
  list(rho_assistant_error_event(
    event@error,
    rho_openai_responses_partial_message(decoder, stop_reason = "error")
  ))
}

S7::method(rho_start_response_item, OpenAIReasoningItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  slot <- rho_openai_start_response_slot(decoder, output_index, rho_thinking(""))
  list(rho_assistant_thinking_start_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index
  ))
}

S7::method(rho_start_response_item, OpenAIMessageItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  slot <- rho_openai_start_response_slot(decoder, output_index, rho_text(""))
  list(rho_assistant_text_start_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index
  ))
}

S7::method(rho_start_response_item, OpenAIFunctionCallItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  if (!nzchar(item@call_id) || !nzchar(item@name)) {
    error <- rho_provider_error(
      "OpenAI function call is missing `call_id` or `name`",
      kind = "protocol",
      details = item@payload
    )
    return(list(rho_assistant_error_event(
      error,
      rho_openai_responses_partial_message(decoder, stop_reason = "error")
    )))
  }
  content <- ToolCall(
    id = item@call_id,
    name = item@name,
    arguments = rho_openai_parse_arguments(item@arguments)
  )
  slot <- rho_openai_start_response_slot(decoder, output_index, content, item@arguments)
  list(rho_assistant_tool_call_start_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    item@call_id,
    item@name
  ))
}

S7::method(rho_start_response_item, OpenAIWebSearchCallItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  content <- WebSearchCallContent(
    id = item@id,
    status = item@status,
    action = item@action
  )
  slot <- rho_openai_start_response_slot(decoder, output_index, content)
  list(rho_assistant_operation_start_event(
    rho_openai_responses_partial_message(decoder),
    slot@content_index,
    content
  ))
}

S7::method(rho_start_response_item, OpenAIUnsupportedItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  list()
}

S7::method(rho_finish_response_item, OpenAIReasoningItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  resolved <- rho_openai_ensure_response_slot(item, decoder, output_index)
  slot <- resolved$slot
  if (is.null(slot)) {
    return(resolved$events)
  }
  current <- rho_openai_response_slot_content(decoder, slot)
  summary <- rho_openai_item_text(item@summary, "\n\n")
  detail <- rho_openai_item_text(item@content, "\n\n")
  text <- if (nzchar(summary)) {
    summary
  } else if (nzchar(detail)) {
    detail
  } else {
    current@text
  }
  content <- rho_thinking(
    text,
    signature = yyjsonr::write_json_str(item@payload, auto_unbox = TRUE)
  )
  rho_openai_store_response_content(decoder, slot, content)
  rho_openai_remove_response_slot(decoder, output_index)
  c(
    resolved$events,
    list(rho_assistant_thinking_end_event(
      rho_openai_responses_partial_message(decoder),
      slot@content_index,
      content
    ))
  )
}

S7::method(rho_finish_response_item, OpenAIMessageItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  resolved <- rho_openai_ensure_response_slot(item, decoder, output_index)
  slot <- resolved$slot
  if (is.null(slot)) {
    return(resolved$events)
  }
  current <- rho_openai_response_slot_content(decoder, slot)
  final <- rho_openai_item_text(item@content)
  text <- if (nzchar(final)) final else current@text
  signature <- yyjsonr::write_json_str(list(id = item@id, phase = item@phase), auto_unbox = TRUE)
  content <- rho_text(text, signature = signature)
  rho_openai_store_response_content(decoder, slot, content)
  rho_openai_remove_response_slot(decoder, output_index)
  c(
    resolved$events,
    list(rho_assistant_text_end_event(
      rho_openai_responses_partial_message(decoder),
      slot@content_index,
      content
    ))
  )
}

S7::method(rho_finish_response_item, OpenAIFunctionCallItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  resolved <- rho_openai_ensure_response_slot(item, decoder, output_index)
  slot <- resolved$slot
  if (is.null(slot)) {
    return(resolved$events)
  }
  content <- rho_openai_response_slot_content(decoder, slot)
  arguments <- item@arguments %||% slot@buffer %||% "{}"
  content@arguments <- rho_openai_parse_arguments(arguments, content@arguments)
  rho_openai_store_response_content(decoder, slot, content)
  rho_openai_remove_response_slot(decoder, output_index)
  c(
    resolved$events,
    list(rho_assistant_tool_call_end_event(
      rho_openai_responses_partial_message(decoder),
      slot@content_index,
      content
    ))
  )
}

S7::method(rho_finish_response_item, OpenAIWebSearchCallItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  resolved <- rho_openai_ensure_response_slot(item, decoder, output_index)
  slot <- resolved$slot
  if (is.null(slot)) {
    return(resolved$events)
  }
  content <- WebSearchCallContent(
    id = item@id,
    status = item@status,
    action = item@action
  )
  rho_openai_store_response_content(decoder, slot, content)
  rho_openai_remove_response_slot(decoder, output_index)
  c(
    resolved$events,
    list(rho_assistant_operation_end_event(
      rho_openai_responses_partial_message(decoder),
      slot@content_index,
      content
    ))
  )
}

S7::method(rho_finish_response_item, OpenAIUnsupportedItem) <- function(
  item,
  decoder,
  output_index,
  ...
) {
  list()
}
