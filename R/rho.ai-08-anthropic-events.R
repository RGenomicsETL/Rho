rho_anthropic_wire_index <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer"
    }
  }
)

AnthropicMessagesDecoder <- S7::new_class(
  "AnthropicMessagesDecoder",
  properties = list(model = AnthropicMessagesModel, state = S7::class_environment),
  validator = function(self) {
    required <- c(
      "started",
      "terminal",
      "content",
      "slots",
      "response_id",
      "usage",
      "stop_reason",
      "tool_names",
      "local_tool_names"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)

AnthropicResponseSlot <- S7::new_class(
  "AnthropicResponseSlot",
  properties = list(
    wire_index = rho_anthropic_wire_index,
    content_index = rho_positive_integer,
    buffer = S7::class_character
  )
)

AnthropicUsageSnapshot <- S7::new_class(
  "AnthropicUsageSnapshot",
  properties = list(
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double,
    cache_write_1h = rho_nonnegative_double,
    reported = S7::class_logical
  )
)

AnthropicIncomingBlock <- S7::new_class("AnthropicIncomingBlock", abstract = TRUE)
AnthropicIncomingText <- S7::new_class(
  "AnthropicIncomingText",
  parent = AnthropicIncomingBlock,
  properties = list(text = S7::class_character)
)
AnthropicIncomingThinking <- S7::new_class(
  "AnthropicIncomingThinking",
  parent = AnthropicIncomingBlock,
  properties = list(thinking = S7::class_character, signature = S7::class_character)
)
AnthropicIncomingRedactedThinking <- S7::new_class(
  "AnthropicIncomingRedactedThinking",
  parent = AnthropicIncomingBlock,
  properties = list(data = S7::class_character)
)
AnthropicIncomingToolUse <- S7::new_class(
  "AnthropicIncomingToolUse",
  parent = AnthropicIncomingBlock,
  properties = list(
    id = S7::class_character,
    name = S7::class_character,
    input = S7::class_list
  )
)
AnthropicIncomingWebSearchUse <- S7::new_class(
  "AnthropicIncomingWebSearchUse",
  parent = AnthropicIncomingBlock,
  properties = list(
    id = rho_non_empty_string,
    input = S7::class_list
  )
)
AnthropicIncomingUnknownServerToolUse <- S7::new_class(
  "AnthropicIncomingUnknownServerToolUse",
  parent = AnthropicIncomingBlock,
  properties = list(
    id = S7::class_character,
    name = S7::class_character,
    input = S7::class_list
  )
)
AnthropicIncomingWebSearchResult <- S7::new_class(
  "AnthropicIncomingWebSearchResult",
  parent = AnthropicIncomingBlock,
  properties = list(
    call_id = rho_non_empty_string,
    results = S7::class_list,
    error = S7::class_any
  )
)
AnthropicIncomingUnknownBlock <- S7::new_class(
  "AnthropicIncomingUnknownBlock",
  parent = AnthropicIncomingBlock,
  properties = list(type = S7::class_character, payload = S7::class_list)
)

AnthropicIncomingDelta <- S7::new_class("AnthropicIncomingDelta", abstract = TRUE)
AnthropicIncomingTextDelta <- S7::new_class(
  "AnthropicIncomingTextDelta",
  parent = AnthropicIncomingDelta,
  properties = list(text = S7::class_character)
)
AnthropicIncomingThinkingDelta <- S7::new_class(
  "AnthropicIncomingThinkingDelta",
  parent = AnthropicIncomingDelta,
  properties = list(thinking = S7::class_character)
)
AnthropicIncomingSignatureDelta <- S7::new_class(
  "AnthropicIncomingSignatureDelta",
  parent = AnthropicIncomingDelta,
  properties = list(signature = S7::class_character)
)
AnthropicIncomingJsonDelta <- S7::new_class(
  "AnthropicIncomingJsonDelta",
  parent = AnthropicIncomingDelta,
  properties = list(json = S7::class_character)
)
AnthropicIncomingUnknownDelta <- S7::new_class(
  "AnthropicIncomingUnknownDelta",
  parent = AnthropicIncomingDelta,
  properties = list(type = S7::class_character, payload = S7::class_list)
)

AnthropicStopReason <- S7::new_class("AnthropicStopReason", abstract = TRUE)
AnthropicEndTurn <- S7::new_class("AnthropicEndTurn", parent = AnthropicStopReason)
AnthropicMaxTokens <- S7::new_class("AnthropicMaxTokens", parent = AnthropicStopReason)
AnthropicToolUse <- S7::new_class("AnthropicToolUse", parent = AnthropicStopReason)
AnthropicRefusal <- S7::new_class("AnthropicRefusal", parent = AnthropicStopReason)
AnthropicPauseTurn <- S7::new_class("AnthropicPauseTurn", parent = AnthropicStopReason)
AnthropicStopSequence <- S7::new_class("AnthropicStopSequence", parent = AnthropicStopReason)
AnthropicSensitive <- S7::new_class("AnthropicSensitive", parent = AnthropicStopReason)
AnthropicUnknownStopReason <- S7::new_class(
  "AnthropicUnknownStopReason",
  parent = AnthropicStopReason,
  properties = list(value = S7::class_character)
)

AnthropicWireEvent <- S7::new_class("AnthropicWireEvent", abstract = TRUE)
AnthropicPing <- S7::new_class("AnthropicPing", parent = AnthropicWireEvent)
AnthropicMessageStarted <- S7::new_class(
  "AnthropicMessageStarted",
  parent = AnthropicWireEvent,
  properties = list(response_id = S7::class_character, usage = AnthropicUsageSnapshot)
)
AnthropicContentStarted <- S7::new_class(
  "AnthropicContentStarted",
  parent = AnthropicWireEvent,
  properties = list(index = rho_anthropic_wire_index, block = AnthropicIncomingBlock)
)
AnthropicContentDelta <- S7::new_class(
  "AnthropicContentDelta",
  parent = AnthropicWireEvent,
  properties = list(index = rho_anthropic_wire_index, delta = AnthropicIncomingDelta)
)
AnthropicContentStopped <- S7::new_class(
  "AnthropicContentStopped",
  parent = AnthropicWireEvent,
  properties = list(index = rho_anthropic_wire_index)
)
AnthropicMessageChanged <- S7::new_class(
  "AnthropicMessageChanged",
  parent = AnthropicWireEvent,
  properties = list(
    stop_reason = AnthropicStopReason,
    output_tokens = rho_nonnegative_double,
    reported = S7::class_logical
  )
)
AnthropicMessageStopped <- S7::new_class("AnthropicMessageStopped", parent = AnthropicWireEvent)
AnthropicWireError <- S7::new_class(
  "AnthropicWireError",
  parent = AnthropicWireEvent,
  properties = list(error = ProviderErrorValue)
)

rho_start_anthropic_block <- S7::new_generic(
  "rho_start_anthropic_block",
  "block",
  function(block, decoder, wire_index, ...) S7::S7_dispatch()
)
rho_apply_anthropic_delta <- S7::new_generic(
  "rho_apply_anthropic_delta",
  c("delta", "content"),
  function(delta, content, decoder, slot, ...) S7::S7_dispatch()
)
rho_finish_anthropic_block <- S7::new_generic(
  "rho_finish_anthropic_block",
  "content",
  function(content, decoder, slot, ...) S7::S7_dispatch()
)
rho_anthropic_stop_reason_value <- S7::new_generic(
  "rho_anthropic_stop_reason_value",
  "reason",
  function(reason, ...) S7::S7_dispatch()
)
rho_anthropic_stop_reason_error <- S7::new_generic(
  "rho_anthropic_stop_reason_error",
  "reason",
  function(reason, ...) S7::S7_dispatch()
)
rho_anthropic_event_requires_start <- S7::new_generic(
  "rho_anthropic_event_requires_start",
  "event",
  function(event, ...) S7::S7_dispatch()
)

rho_anthropic_usage_snapshot <- function(payload = NULL) {
  reported <- is.list(payload) && length(payload)
  payload <- payload %||% list()
  creation <- payload[["cache_creation"]] %||% list()
  AnthropicUsageSnapshot(
    input = as.double(payload$input_tokens %||% 0),
    output = as.double(payload$output_tokens %||% 0),
    cache_read = as.double(payload$cache_read_input_tokens %||% 0),
    cache_write = as.double(payload$cache_creation_input_tokens %||% 0),
    cache_write_1h = as.double(creation$ephemeral_1h_input_tokens %||% 0),
    reported = reported
  )
}

rho_anthropic_text_started <- function(payload) {
  AnthropicIncomingText(text = as.character(payload$text %||% ""))
}

rho_anthropic_thinking_started <- function(payload) {
  AnthropicIncomingThinking(
    thinking = as.character(payload$thinking %||% ""),
    signature = as.character(payload$signature %||% "")
  )
}

rho_anthropic_redacted_thinking_started <- function(payload) {
  AnthropicIncomingRedactedThinking(data = as.character(payload$data %||% ""))
}

rho_anthropic_tool_started <- function(payload) {
  AnthropicIncomingToolUse(
    id = as.character(payload$id %||% ""),
    name = as.character(payload$name %||% ""),
    input = payload$input %||% list()
  )
}

rho_anthropic_web_search_started <- function(payload) {
  AnthropicIncomingWebSearchUse(
    id = as.character(payload$id %||% ""),
    input = payload$input %||% list()
  )
}

rho_anthropic_unknown_server_tool_started <- function(payload) {
  AnthropicIncomingUnknownServerToolUse(
    id = as.character(payload$id %||% ""),
    name = as.character(payload$name %||% ""),
    input = payload$input %||% list()
  )
}

rho_anthropic_server_tool_factories <- list(
  web_search = rho_anthropic_web_search_started
)

rho_anthropic_server_tool_started <- function(payload) {
  factory <- rho_anthropic_server_tool_factories[[as.character(payload$name %||% "")]] %||%
    rho_anthropic_unknown_server_tool_started
  factory(payload)
}

rho_anthropic_web_search_result <- function(payload) {
  WebSearchResult(
    url = as.character(payload$url %||% ""),
    title = as.character(payload$title %||% ""),
    age = as.character(payload$page_age %||% payload$age %||% ""),
    encrypted_content = as.character(payload$encrypted_content %||% "")
  )
}

rho_anthropic_web_search_result_started <- function(payload) {
  content <- payload$content %||% list()
  failed <- identical(content$type, "web_search_tool_result_error")
  error <- if (failed) {
    rho_provider_error(
      "Anthropic web search failed",
      kind = "provider_operation",
      code = as.character(content$error_code %||% "web_search_error"),
      details = content
    )
  } else {
    NULL
  }
  results <- if (failed) {
    list()
  } else {
    lapply(content, rho_anthropic_web_search_result)
  }
  AnthropicIncomingWebSearchResult(
    call_id = as.character(payload$tool_use_id %||% ""),
    results = results,
    error = error
  )
}

rho_anthropic_unknown_block <- function(payload) {
  AnthropicIncomingUnknownBlock(
    type = as.character(payload$type %||% ""),
    payload = payload
  )
}

rho_anthropic_block_factories <- list(
  text = rho_anthropic_text_started,
  thinking = rho_anthropic_thinking_started,
  redacted_thinking = rho_anthropic_redacted_thinking_started,
  tool_use = rho_anthropic_tool_started,
  server_tool_use = rho_anthropic_server_tool_started,
  web_search_tool_result = rho_anthropic_web_search_result_started
)

rho_anthropic_incoming_block <- function(payload) {
  factory <- rho_anthropic_block_factories[[as.character(payload$type %||% "")]] %||%
    rho_anthropic_unknown_block
  factory(payload)
}

rho_anthropic_text_delta <- function(payload) {
  AnthropicIncomingTextDelta(text = as.character(payload$text %||% ""))
}

rho_anthropic_thinking_delta <- function(payload) {
  AnthropicIncomingThinkingDelta(thinking = as.character(payload$thinking %||% ""))
}

rho_anthropic_signature_delta <- function(payload) {
  AnthropicIncomingSignatureDelta(signature = as.character(payload$signature %||% ""))
}

rho_anthropic_json_delta <- function(payload) {
  AnthropicIncomingJsonDelta(json = as.character(payload$partial_json %||% ""))
}

rho_anthropic_unknown_delta <- function(payload) {
  AnthropicIncomingUnknownDelta(
    type = as.character(payload$type %||% ""),
    payload = payload
  )
}

rho_anthropic_delta_factories <- list(
  text_delta = rho_anthropic_text_delta,
  thinking_delta = rho_anthropic_thinking_delta,
  signature_delta = rho_anthropic_signature_delta,
  input_json_delta = rho_anthropic_json_delta
)

rho_anthropic_incoming_delta <- function(payload) {
  factory <- rho_anthropic_delta_factories[[as.character(payload$type %||% "")]] %||%
    rho_anthropic_unknown_delta
  factory(payload)
}

rho_anthropic_stop_reason_factories <- list(
  end_turn = AnthropicEndTurn,
  max_tokens = AnthropicMaxTokens,
  tool_use = AnthropicToolUse,
  refusal = AnthropicRefusal,
  pause_turn = AnthropicPauseTurn,
  stop_sequence = AnthropicStopSequence,
  sensitive = AnthropicSensitive
)

rho_anthropic_stop_reason <- function(value) {
  value <- as.character(value %||% "")
  factory <- rho_anthropic_stop_reason_factories[[value]]
  if (is.null(factory)) AnthropicUnknownStopReason(value = value) else factory()
}

rho_anthropic_protocol_wire_error <- function(message, details = list()) {
  AnthropicWireError(
    error = rho_provider_error(
      message,
      kind = "protocol",
      code = "anthropic_stream_protocol",
      details = details
    )
  )
}

rho_anthropic_event_index <- function(payload) {
  value <- payload$index
  if (is.null(value) || length(value) != 1L || is.na(value) || value < 0) {
    return(NULL)
  }
  as.integer(value)
}

rho_anthropic_message_started_event <- function(payload) {
  message <- payload$message %||% list()
  AnthropicMessageStarted(
    response_id = as.character(message$id %||% ""),
    usage = rho_anthropic_usage_snapshot(message$usage)
  )
}

rho_anthropic_content_started_event <- function(payload) {
  index <- rho_anthropic_event_index(payload)
  if (is.null(index)) {
    return(rho_anthropic_protocol_wire_error(
      "Anthropic content_block_start is missing a valid index",
      payload
    ))
  }
  AnthropicContentStarted(
    index = index,
    block = rho_anthropic_incoming_block(payload$content_block %||% list())
  )
}

rho_anthropic_content_delta_event <- function(payload) {
  index <- rho_anthropic_event_index(payload)
  if (is.null(index)) {
    return(rho_anthropic_protocol_wire_error(
      "Anthropic content_block_delta is missing a valid index",
      payload
    ))
  }
  AnthropicContentDelta(
    index = index,
    delta = rho_anthropic_incoming_delta(payload$delta %||% list())
  )
}

rho_anthropic_content_stopped_event <- function(payload) {
  index <- rho_anthropic_event_index(payload)
  if (is.null(index)) {
    return(rho_anthropic_protocol_wire_error(
      "Anthropic content_block_stop is missing a valid index",
      payload
    ))
  }
  AnthropicContentStopped(index = index)
}

rho_anthropic_message_changed_event <- function(payload) {
  delta <- payload$delta %||% list()
  usage <- payload$usage
  AnthropicMessageChanged(
    stop_reason = rho_anthropic_stop_reason(delta$stop_reason),
    output_tokens = as.double(usage$output_tokens %||% 0),
    reported = is.list(usage) && length(usage)
  )
}

rho_anthropic_error_factories <- list(
  request_too_large = function(message, code, details) {
    rho_provider_request_too_large(message, code, details)
  }
)

rho_anthropic_api_error_value <- function(message, code, details) {
  factory <- rho_anthropic_error_factories[[code]]
  if (!is.null(factory)) {
    return(factory(message, code, details))
  }
  rho_provider_error(
    message,
    kind = "api",
    code = code,
    retryable = identical(code, "overloaded_error"),
    details = details
  )
}

rho_anthropic_api_error_event <- function(payload) {
  error <- payload$error %||% list()
  AnthropicWireError(
    error = rho_anthropic_api_error_value(
      as.character(error$message %||% "Anthropic request failed"),
      code = as.character(error$type %||% ""),
      details = payload
    )
  )
}

S7::method(
  rho_provider_http_error,
  list(AnthropicMessagesModel, RhoHttpStatusError)
) <- function(model, error, ...) {
  document <- rho_http_error_document(error)
  nested <- if (is.list(document$error)) document$error else NULL
  if (is.null(nested)) {
    return(rho_http_status_provider_error(error))
  }
  rho_anthropic_api_error_value(
    message = as.character(nested$message %||% error@message),
    code = as.character(nested$type %||% error@status),
    details = rho_http_error_details(error)
  )
}

rho_anthropic_wire_event_factories <- list(
  ping = function(payload) AnthropicPing(),
  message_start = rho_anthropic_message_started_event,
  content_block_start = rho_anthropic_content_started_event,
  content_block_delta = rho_anthropic_content_delta_event,
  content_block_stop = rho_anthropic_content_stopped_event,
  message_delta = rho_anthropic_message_changed_event,
  message_stop = function(payload) AnthropicMessageStopped(),
  error = rho_anthropic_api_error_event
)

rho_anthropic_wire_event <- function(payload) {
  type <- as.character(payload$type %||% "")
  factory <- rho_anthropic_wire_event_factories[[type]]
  if (is.null(factory)) {
    return(rho_anthropic_protocol_wire_error(
      sprintf("Unknown Anthropic stream event type `%s`", type),
      payload
    ))
  }
  factory(payload)
}

rho_anthropic_decode_wire_event <- function(event) {
  payload <- tryCatch(
    yyjsonr::read_json_str(
      event@data,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(payload, "error")) {
    return(rho_anthropic_protocol_wire_error(
      sprintf("Invalid Anthropic Messages SSE JSON: %s", conditionMessage(payload)),
      details = list(data = event@data)
    ))
  }
  rho_anthropic_wire_event(payload)
}

rho_anthropic_messages_decoder <- function(
  model,
  tool_names = rho_anthropic_exact_tool_names(),
  tools = list()
) {
  state <- new.env(parent = emptyenv())
  state$started <- FALSE
  state$terminal <- FALSE
  state$content <- list()
  state$slots <- list()
  state$response_id <- ""
  state$usage <- rho_anthropic_usage_snapshot()
  state$stop_reason <- NULL
  state$tool_names <- tool_names
  state$local_tool_names <- vapply(tools, function(tool) tool@name, character(1))
  AnthropicMessagesDecoder(model = model, state = state)
}

rho_anthropic_usage_value <- function(decoder, priced = FALSE) {
  snapshot <- decoder@state$usage
  if (!snapshot@reported) {
    return(rho_usage_unavailable(
      decoder@model@provider,
      "Anthropic stream did not report token usage"
    ))
  }
  usage <- rho_provider_usage(
    provider = decoder@model@provider,
    input = snapshot@input,
    output = snapshot@output,
    cache_read = snapshot@cache_read,
    cache_write = snapshot@cache_write,
    cache_write_1h = snapshot@cache_write_1h
  )
  if (isTRUE(priced)) rho_price_usage(decoder@model, usage) else usage
}

rho_anthropic_messages_partial <- function(decoder, stop_reason = "stop", priced = FALSE) {
  rho_assistant_message(
    content = decoder@state$content,
    provider = decoder@model@provider,
    model = decoder@model@id,
    stop_reason = stop_reason,
    usage = rho_anthropic_usage_value(decoder, priced),
    response_id = decoder@state$response_id
  )
}

rho_anthropic_begin_events <- function(decoder) {
  if (decoder@state$started) {
    return(list())
  }
  decoder@state$started <- TRUE
  list(rho_assistant_start_event(rho_anthropic_messages_partial(decoder)))
}

rho_anthropic_slot_key <- function(wire_index) as.character(wire_index)

rho_anthropic_slot <- function(decoder, wire_index) {
  decoder@state$slots[[rho_anthropic_slot_key(wire_index)]]
}

rho_anthropic_store_slot <- function(decoder, slot) {
  decoder@state$slots[[rho_anthropic_slot_key(slot@wire_index)]] <- slot
  invisible(slot)
}

rho_anthropic_remove_slot <- function(decoder, wire_index) {
  decoder@state$slots[[rho_anthropic_slot_key(wire_index)]] <- NULL
  invisible(decoder)
}

rho_anthropic_start_slot <- function(decoder, wire_index, content, buffer = "") {
  decoder@state$content[[length(decoder@state$content) + 1L]] <- content
  slot <- AnthropicResponseSlot(
    wire_index = wire_index,
    content_index = as.integer(length(decoder@state$content)),
    buffer = buffer
  )
  rho_anthropic_store_slot(decoder, slot)
  slot
}

rho_anthropic_slot_content <- function(decoder, slot) {
  decoder@state$content[[slot@content_index]]
}

rho_anthropic_store_content <- function(decoder, slot, content) {
  decoder@state$content[[slot@content_index]] <- content
  invisible(content)
}

rho_anthropic_error_events <- function(decoder, error) {
  decoder@state$terminal <- TRUE
  c(
    rho_anthropic_begin_events(decoder),
    list(rho_assistant_error_event(
      error,
      rho_anthropic_messages_partial(decoder, stop_reason = "error")
    ))
  )
}

rho_anthropic_protocol_events <- function(decoder, message, details = list()) {
  rho_anthropic_error_events(
    decoder,
    rho_provider_error(
      message,
      kind = "protocol",
      code = "anthropic_stream_protocol",
      details = details
    )
  )
}

S7::method(
  rho_decode_provider_event,
  list(AnthropicMessagesDecoder, RhoSseEvent)
) <- function(decoder, event, ...) {
  if (decoder@state$terminal) {
    return(list())
  }
  wire_event <- rho_anthropic_decode_wire_event(event)
  if (
    rho_anthropic_event_requires_start(wire_event) &&
      !decoder@state$started
  ) {
    return(rho_anthropic_protocol_events(
      decoder,
      sprintf(
        "Anthropic event %s arrived before message_start",
        S7::S7_class(wire_event)@name
      )
    ))
  }
  rho_reduce_provider_event(wire_event, decoder)
}

S7::method(
  rho_decode_provider_event,
  list(AnthropicMessagesDecoder, RhoHttpError)
) <- function(decoder, event, ...) {
  rho_anthropic_error_events(
    decoder,
    rho_provider_http_error(decoder@model, event)
  )
}

S7::method(
  rho_decode_provider_event,
  list(AnthropicMessagesDecoder, S7::class_any)
) <- function(decoder, event, ...) {
  rho_anthropic_protocol_events(
    decoder,
    sprintf(
      "Anthropic response decoder cannot consume an event of class %s",
      rho_class_label(event)
    ),
    list(event_class = rho_class_label(event))
  )
}

S7::method(rho_reduce_provider_event, AnthropicPing) <- function(event, decoder, ...) {
  list()
}

S7::method(
  rho_anthropic_event_requires_start,
  AnthropicWireEvent
) <- function(event, ...) {
  TRUE
}

S7::method(
  rho_anthropic_event_requires_start,
  AnthropicPing
) <- function(event, ...) {
  FALSE
}

S7::method(
  rho_anthropic_event_requires_start,
  AnthropicMessageStarted
) <- function(event, ...) {
  FALSE
}

S7::method(
  rho_anthropic_event_requires_start,
  AnthropicWireError
) <- function(event, ...) {
  FALSE
}

S7::method(rho_reduce_provider_event, AnthropicMessageStarted) <- function(
  event,
  decoder,
  ...
) {
  if (decoder@state$started) {
    return(rho_anthropic_protocol_events(
      decoder,
      "Anthropic message_start was received twice"
    ))
  }
  decoder@state$response_id <- event@response_id
  decoder@state$usage <- event@usage
  rho_anthropic_begin_events(decoder)
}

S7::method(rho_reduce_provider_event, AnthropicContentStarted) <- function(
  event,
  decoder,
  ...
) {
  if (!is.null(rho_anthropic_slot(decoder, event@index))) {
    return(rho_anthropic_protocol_events(
      decoder,
      sprintf("Anthropic content index %d was started twice", event@index),
      list(index = event@index)
    ))
  }
  rho_start_anthropic_block(event@block, decoder, event@index)
}

S7::method(rho_reduce_provider_event, AnthropicContentDelta) <- function(
  event,
  decoder,
  ...
) {
  slot <- rho_anthropic_slot(decoder, event@index)
  if (is.null(slot)) {
    return(rho_anthropic_protocol_events(
      decoder,
      sprintf("Anthropic content delta has no block at index %d", event@index),
      list(index = event@index)
    ))
  }
  rho_apply_anthropic_delta(
    event@delta,
    rho_anthropic_slot_content(decoder, slot),
    decoder,
    slot
  )
}

S7::method(rho_reduce_provider_event, AnthropicContentStopped) <- function(
  event,
  decoder,
  ...
) {
  slot <- rho_anthropic_slot(decoder, event@index)
  if (is.null(slot)) {
    return(rho_anthropic_protocol_events(
      decoder,
      sprintf("Anthropic content stop has no block at index %d", event@index),
      list(index = event@index)
    ))
  }
  rho_finish_anthropic_block(rho_anthropic_slot_content(decoder, slot), decoder, slot)
}

S7::method(rho_reduce_provider_event, AnthropicMessageChanged) <- function(
  event,
  decoder,
  ...
) {
  usage <- decoder@state$usage
  if (event@reported) {
    usage@output <- event@output_tokens
    usage@reported <- TRUE
  }
  decoder@state$usage <- usage
  decoder@state$stop_reason <- event@stop_reason
  list()
}

S7::method(rho_reduce_provider_event, AnthropicWireError) <- function(event, decoder, ...) {
  rho_anthropic_error_events(decoder, event@error)
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingText
) <- function(block, decoder, wire_index, ...) {
  content <- rho_text(block@text)
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  events <- list(rho_assistant_text_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index
  ))
  if (nzchar(block@text)) {
    events[[length(events) + 1L]] <- rho_assistant_text_delta_event(
      rho_anthropic_messages_partial(decoder),
      slot@content_index,
      block@text
    )
  }
  events
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingWebSearchUse
) <- function(block, decoder, wire_index, ...) {
  query <- as.character(block@input$query %||% "")
  content <- WebSearchCallContent(
    id = block@id,
    status = OperationInProgress(),
    action = WebSearchSearchAction(queries = query, sources = list())
  )
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  list(rho_assistant_operation_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingWebSearchResult
) <- function(block, decoder, wire_index, ...) {
  content <- WebSearchResultContent(
    call_id = block@call_id,
    results = block@results,
    error = block@error
  )
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  list(rho_assistant_operation_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingUnknownServerToolUse
) <- function(block, decoder, wire_index, ...) {
  rho_anthropic_protocol_events(
    decoder,
    sprintf("Unknown Anthropic server tool `%s`", block@name),
    list(id = block@id, name = block@name, input = block@input)
  )
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingThinking
) <- function(block, decoder, wire_index, ...) {
  content <- rho_thinking(block@thinking, signature = block@signature)
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  events <- list(rho_assistant_thinking_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index
  ))
  if (nzchar(block@thinking)) {
    events[[length(events) + 1L]] <- rho_assistant_thinking_delta_event(
      rho_anthropic_messages_partial(decoder),
      slot@content_index,
      block@thinking
    )
  }
  events
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingRedactedThinking
) <- function(block, decoder, wire_index, ...) {
  if (!nzchar(block@data)) {
    return(rho_anthropic_protocol_events(
      decoder,
      "Anthropic redacted thinking is missing its opaque data"
    ))
  }
  content <- rho_thinking(
    "[Reasoning redacted]",
    signature = block@data,
    redacted = TRUE
  )
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  list(rho_assistant_thinking_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index
  ))
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingToolUse
) <- function(block, decoder, wire_index, ...) {
  if (!nzchar(block@id) || !nzchar(block@name)) {
    return(rho_anthropic_protocol_events(
      decoder,
      "Anthropic tool use is missing its id or name",
      list(id = block@id, name = block@name)
    ))
  }
  local_name <- rho_anthropic_local_tool_name(
    decoder@state$tool_names,
    block@name,
    decoder@state$local_tool_names
  )
  content <- ToolCall(id = block@id, name = local_name, arguments = block@input)
  slot <- rho_anthropic_start_slot(decoder, wire_index, content)
  list(rho_assistant_tool_call_start_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    block@id,
    local_name
  ))
}

S7::method(
  rho_start_anthropic_block,
  AnthropicIncomingUnknownBlock
) <- function(block, decoder, wire_index, ...) {
  rho_anthropic_protocol_events(
    decoder,
    sprintf("Unknown Anthropic content block type `%s`", block@type),
    block@payload
  )
}

S7::method(
  rho_apply_anthropic_delta,
  list(AnthropicIncomingTextDelta, TextContent)
) <- function(delta, content, decoder, slot, ...) {
  content@text <- paste0(content@text, delta@text)
  rho_anthropic_store_content(decoder, slot, content)
  list(rho_assistant_text_delta_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    delta@text
  ))
}

S7::method(
  rho_apply_anthropic_delta,
  list(AnthropicIncomingThinkingDelta, ThinkingContent)
) <- function(delta, content, decoder, slot, ...) {
  content@text <- paste0(content@text, delta@thinking)
  rho_anthropic_store_content(decoder, slot, content)
  list(rho_assistant_thinking_delta_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    delta@thinking
  ))
}

S7::method(
  rho_apply_anthropic_delta,
  list(AnthropicIncomingSignatureDelta, ThinkingContent)
) <- function(delta, content, decoder, slot, ...) {
  content@signature <- paste0(content@signature, delta@signature)
  rho_anthropic_store_content(decoder, slot, content)
  list()
}

S7::method(
  rho_apply_anthropic_delta,
  list(AnthropicIncomingJsonDelta, ToolCall)
) <- function(delta, content, decoder, slot, ...) {
  slot@buffer <- paste0(slot@buffer, delta@json)
  rho_anthropic_store_slot(decoder, slot)
  list(rho_assistant_tool_call_delta_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    delta@json
  ))
}

S7::method(
  rho_apply_anthropic_delta,
  list(AnthropicIncomingDelta, S7::class_any)
) <- function(delta, content, decoder, slot, ...) {
  type <- S7::S7_class(delta)@name
  rho_anthropic_protocol_events(
    decoder,
    sprintf(
      "Anthropic delta %s does not apply to content class %s",
      type,
      rho_class_label(content)
    ),
    list(wire_index = slot@wire_index)
  )
}

S7::method(
  rho_finish_anthropic_block,
  TextContent
) <- function(content, decoder, slot, ...) {
  rho_anthropic_remove_slot(decoder, slot@wire_index)
  list(rho_assistant_text_end_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_finish_anthropic_block,
  WebSearchCallContent
) <- function(content, decoder, slot, ...) {
  content@status <- OperationCompleted()
  rho_anthropic_store_content(decoder, slot, content)
  rho_anthropic_remove_slot(decoder, slot@wire_index)
  list(rho_assistant_operation_end_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_finish_anthropic_block,
  WebSearchResultContent
) <- function(content, decoder, slot, ...) {
  rho_anthropic_remove_slot(decoder, slot@wire_index)
  list(rho_assistant_operation_end_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_finish_anthropic_block,
  ThinkingContent
) <- function(content, decoder, slot, ...) {
  rho_anthropic_remove_slot(decoder, slot@wire_index)
  list(rho_assistant_thinking_end_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

rho_anthropic_tool_arguments <- function(slot, content) {
  if (!nzchar(slot@buffer)) {
    return(content@arguments)
  }
  value <- tryCatch(
    yyjsonr::read_json_str(
      slot@buffer,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(value, "error") || !is.list(value)) {
    return(rho_provider_error(
      "Anthropic tool arguments are not a JSON object",
      kind = "protocol",
      code = "anthropic_tool_arguments",
      details = list(arguments = slot@buffer)
    ))
  }
  value
}

S7::method(
  rho_finish_anthropic_block,
  ToolCall
) <- function(content, decoder, slot, ...) {
  arguments <- rho_anthropic_tool_arguments(slot, content)
  if (S7::S7_inherits(arguments, ProviderErrorValue)) {
    return(rho_anthropic_error_events(decoder, arguments))
  }
  content@arguments <- arguments
  rho_anthropic_store_content(decoder, slot, content)
  rho_anthropic_remove_slot(decoder, slot@wire_index)
  list(rho_assistant_tool_call_end_event(
    rho_anthropic_messages_partial(decoder),
    slot@content_index,
    content
  ))
}

S7::method(
  rho_finish_anthropic_block,
  S7::class_any
) <- function(content, decoder, slot, ...) {
  rho_anthropic_protocol_events(
    decoder,
    sprintf("Anthropic cannot finish content class %s", rho_class_label(content)),
    list(wire_index = slot@wire_index)
  )
}

S7::method(rho_anthropic_stop_reason_value, AnthropicEndTurn) <- function(reason, ...) "stop"
S7::method(rho_anthropic_stop_reason_value, AnthropicMaxTokens) <- function(reason, ...) {
  "length"
}
S7::method(rho_anthropic_stop_reason_value, AnthropicToolUse) <- function(reason, ...) {
  "toolUse"
}
S7::method(rho_anthropic_stop_reason_value, AnthropicPauseTurn) <- function(reason, ...) {
  "stop"
}
S7::method(rho_anthropic_stop_reason_value, AnthropicStopSequence) <- function(reason, ...) {
  "stop"
}
S7::method(rho_anthropic_stop_reason_value, AnthropicRefusal) <- function(reason, ...) "error"
S7::method(rho_anthropic_stop_reason_value, AnthropicSensitive) <- function(reason, ...) {
  "error"
}
S7::method(
  rho_anthropic_stop_reason_value,
  AnthropicUnknownStopReason
) <- function(reason, ...) {
  "error"
}

S7::method(rho_anthropic_stop_reason_error, AnthropicStopReason) <- function(reason, ...) NULL
S7::method(rho_anthropic_stop_reason_error, AnthropicRefusal) <- function(reason, ...) {
  rho_provider_error(
    "Anthropic refused the response",
    kind = "api",
    code = "refusal"
  )
}
S7::method(rho_anthropic_stop_reason_error, AnthropicSensitive) <- function(reason, ...) {
  rho_provider_error(
    "Anthropic stopped the response because it was classified as sensitive",
    kind = "api",
    code = "sensitive"
  )
}
S7::method(
  rho_anthropic_stop_reason_error,
  AnthropicUnknownStopReason
) <- function(reason, ...) {
  rho_provider_error(
    sprintf("Unknown Anthropic stop reason `%s`", reason@value),
    kind = "protocol",
    code = "anthropic_stop_reason",
    details = list(stop_reason = reason@value)
  )
}

S7::method(rho_reduce_provider_event, AnthropicMessageStopped) <- function(
  event,
  decoder,
  ...
) {
  if (decoder@state$terminal) {
    return(list())
  }
  if (length(decoder@state$slots)) {
    return(rho_anthropic_protocol_events(
      decoder,
      "Anthropic message stopped before every content block was closed",
      list(open_indexes = names(decoder@state$slots))
    ))
  }
  reason <- decoder@state$stop_reason %||% AnthropicUnknownStopReason(value = "")
  error <- rho_anthropic_stop_reason_error(reason)
  if (!is.null(error)) {
    return(rho_anthropic_error_events(decoder, error))
  }
  stop_reason <- rho_anthropic_stop_reason_value(reason)
  decoder@state$terminal <- TRUE
  message <- rho_anthropic_messages_partial(
    decoder,
    stop_reason = stop_reason,
    priced = TRUE
  )
  list(rho_assistant_done_event(message, stop_reason))
}
