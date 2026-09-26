OpenAIChatCompletionsDecoder <- S7::new_class(
  "OpenAIChatCompletionsDecoder",
  properties = list(model = Model, state = S7::class_environment),
  validator = function(self) {
    required <- c(
      "started",
      "completed",
      "content",
      "thinking_index",
      "text_index",
      "tool_slots",
      "finish_reason",
      "response_id",
      "usage"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)

OpenAIChatWireEvent <- S7::new_class("OpenAIChatWireEvent", abstract = TRUE)

OpenAIChatIgnored <- S7::new_class("OpenAIChatIgnored", parent = OpenAIChatWireEvent)

OpenAIChatThinkingDelta <- S7::new_class(
  "OpenAIChatThinkingDelta",
  parent = OpenAIChatWireEvent,
  properties = list(delta = S7::class_character)
)

OpenAIChatTextDelta <- S7::new_class(
  "OpenAIChatTextDelta",
  parent = OpenAIChatWireEvent,
  properties = list(delta = S7::class_character)
)

OpenAIChatToolDelta <- S7::new_class(
  "OpenAIChatToolDelta",
  parent = OpenAIChatWireEvent,
  properties = list(
    tool_index = rho_openai_output_index,
    id = S7::class_character,
    name = S7::class_character,
    arguments_delta = S7::class_character
  )
)

OpenAIChatFinishSignal <- S7::new_class(
  "OpenAIChatFinishSignal",
  parent = OpenAIChatWireEvent,
  properties = list(reason = S7::class_character)
)

OpenAIChatUsageUpdate <- S7::new_class(
  "OpenAIChatUsageUpdate",
  parent = OpenAIChatWireEvent,
  properties = list(usage = S7::class_list)
)

OpenAIChatDone <- S7::new_class("OpenAIChatDone", parent = OpenAIChatWireEvent)

OpenAIChatError <- S7::new_class(
  "OpenAIChatError",
  parent = OpenAIChatWireEvent,
  properties = list(error = ProviderErrorValue)
)

rho_openai_chat_decoder <- function(model) {
  state <- new.env(parent = emptyenv())
  state$started <- FALSE
  state$completed <- FALSE
  state$content <- list()
  state$thinking_index <- 0L
  state$text_index <- 0L
  state$tool_slots <- list()
  state$finish_reason <- "stop"
  state$response_id <- ""
  state$usage <- NULL
  OpenAIChatCompletionsDecoder(model = model, state = state)
}

rho_openai_chat_partial_message <- function(decoder, stop_reason = "stop", usage = NULL) {
  rho_assistant_message(
    content = decoder@state$content,
    provider = decoder@model@provider,
    model = decoder@model@id,
    stop_reason = stop_reason,
    usage = usage,
    response_id = decoder@state$response_id
  )
}

rho_openai_chat_begin_events <- function(decoder) {
  if (decoder@state$started) {
    return(list())
  }
  decoder@state$started <- TRUE
  list(rho_assistant_start_event(rho_openai_chat_partial_message(decoder)))
}

rho_openai_chat_add_content <- function(decoder, content) {
  decoder@state$content[[length(decoder@state$content) + 1L]] <- content
  as.integer(length(decoder@state$content))
}

rho_openai_chat_store_content <- function(decoder, index, content) {
  decoder@state$content[[index]] <- content
  invisible(content)
}

rho_openai_chat_tool_key <- function(index) as.character(index)

rho_openai_chat_tool_slot <- function(decoder, index) {
  decoder@state$tool_slots[[rho_openai_chat_tool_key(index)]]
}

rho_openai_chat_store_tool_slot <- function(decoder, index, slot) {
  decoder@state$tool_slots[[rho_openai_chat_tool_key(index)]] <- slot
  invisible(slot)
}

rho_openai_chat_wire_error <- function(
  message,
  code = "protocol",
  details = list(),
  kind = "protocol"
) {
  OpenAIChatError(
    error = rho_openai_api_error_value(
      message = message,
      kind = kind,
      code = code,
      retryable = FALSE,
      details = details
    )
  )
}

rho_openai_chat_tool_events <- function(tool_calls) {
  if (!is.list(tool_calls)) {
    return(list())
  }
  lapply(tool_calls, function(tool_call) {
    function_value <- tool_call[["function"]] %||% list()
    OpenAIChatToolDelta(
      tool_index = as.integer(tool_call$index %||% 0L),
      id = as.character(tool_call$id %||% ""),
      name = as.character(function_value$name %||% ""),
      arguments_delta = as.character(function_value$arguments %||% "")
    )
  })
}

rho_openai_chat_choice_events <- function(choice) {
  delta <- choice$delta %||% list()
  events <- list()
  thinking <- delta$reasoning_content %||% delta$reasoning
  if (is.character(thinking) && length(thinking) == 1L && nzchar(thinking)) {
    events[[length(events) + 1L]] <- OpenAIChatThinkingDelta(delta = thinking)
  }
  text <- delta$content
  if (is.character(text) && length(text) == 1L && nzchar(text)) {
    events[[length(events) + 1L]] <- OpenAIChatTextDelta(delta = text)
  }
  events <- c(events, rho_openai_chat_tool_events(delta$tool_calls))
  finish_reason <- choice$finish_reason
  if (is.character(finish_reason) && length(finish_reason) == 1L && nzchar(finish_reason)) {
    events[[length(events) + 1L]] <- OpenAIChatFinishSignal(reason = finish_reason)
  }
  events
}

rho_openai_chat_wire_events <- function(payload) {
  error <- payload$error
  if (is.list(error)) {
    return(list(rho_openai_chat_wire_error(
      as.character(error$message %||% "OpenAI-compatible provider returned an error"),
      code = as.character(error$code %||% "provider"),
      details = error,
      kind = "api"
    )))
  }
  events <- unlist(
    lapply(payload$choices %||% list(), rho_openai_chat_choice_events),
    recursive = FALSE
  )
  usage <- payload$usage
  choices <- payload$choices %||% list()
  if ((!is.list(usage) || !length(usage)) && length(choices)) {
    usage <- choices[[1L]]$usage
  }
  if (is.list(usage) && length(usage)) {
    events[[length(events) + 1L]] <- OpenAIChatUsageUpdate(usage = usage)
  }
  if (!length(events)) list(OpenAIChatIgnored()) else events
}

S7::method(
  rho_provider_http_error,
  list(OpenAIChatCompletionsModel, RhoHttpStatusError)
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

rho_openai_chat_decode_sse <- function(event) {
  if (identical(trimws(event@data), "[DONE]")) {
    return(list(OpenAIChatDone()))
  }
  payload <- tryCatch(
    yyjsonr::read_json_str(
      event@data,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(payload, "error") || !is.list(payload)) {
    return(list(rho_openai_chat_wire_error(
      "OpenAI Chat Completions stream returned invalid JSON",
      code = "response_format",
      details = list(data = event@data)
    )))
  }
  rho_openai_chat_wire_events(payload)
}

rho_openai_chat_error_events <- function(decoder, error) {
  c(
    rho_openai_chat_begin_events(decoder),
    list(rho_assistant_error_event(
      error,
      rho_openai_chat_partial_message(decoder, stop_reason = "error")
    ))
  )
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIChatCompletionsDecoder, RhoSseEvent)
) <- function(decoder, event, ...) {
  wire_events <- rho_openai_chat_decode_sse(event)
  events <- rho_openai_chat_begin_events(decoder)
  for (wire_event in wire_events) {
    events <- c(events, rho_reduce_provider_event(wire_event, decoder))
  }
  events
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIChatCompletionsDecoder, RhoHttpError)
) <- function(decoder, event, ...) {
  rho_openai_chat_error_events(
    decoder,
    rho_provider_http_error(decoder@model, event)
  )
}

S7::method(
  rho_decode_provider_event,
  list(OpenAIChatCompletionsDecoder, S7::class_any)
) <- function(decoder, event, ...) {
  rho_openai_chat_error_events(
    decoder,
    rho_provider_error(
      message = sprintf(
        "OpenAI Chat Completions decoder cannot consume an event of class %s",
        rho_class_label(event)
      ),
      kind = "protocol",
      code = "unsupported_event",
      details = list(event_class = rho_class_label(event))
    )
  )
}

S7::method(rho_reduce_provider_event, OpenAIChatIgnored) <- function(event, decoder, ...) {
  list()
}

S7::method(
  rho_reduce_provider_event,
  OpenAIChatThinkingDelta
) <- function(event, decoder, ...) {
  events <- list()
  if (decoder@state$thinking_index == 0L) {
    decoder@state$thinking_index <- rho_openai_chat_add_content(
      decoder,
      rho_thinking("")
    )
    events[[length(events) + 1L]] <- rho_assistant_thinking_start_event(
      rho_openai_chat_partial_message(decoder),
      decoder@state$thinking_index
    )
  }
  index <- decoder@state$thinking_index
  current <- decoder@state$content[[index]]
  rho_openai_chat_store_content(
    decoder,
    index,
    rho_thinking(
      paste0(current@text, event@delta),
      signature = current@signature,
      redacted = current@redacted
    )
  )
  events[[length(events) + 1L]] <- rho_assistant_thinking_delta_event(
    rho_openai_chat_partial_message(decoder),
    index,
    event@delta
  )
  events
}

S7::method(rho_reduce_provider_event, OpenAIChatTextDelta) <- function(event, decoder, ...) {
  events <- list()
  if (decoder@state$text_index == 0L) {
    decoder@state$text_index <- rho_openai_chat_add_content(decoder, rho_text(""))
    events[[length(events) + 1L]] <- rho_assistant_text_start_event(
      rho_openai_chat_partial_message(decoder),
      decoder@state$text_index
    )
  }
  index <- decoder@state$text_index
  current <- decoder@state$content[[index]]
  rho_openai_chat_store_content(
    decoder,
    index,
    rho_text(paste0(current@text, event@delta), signature = current@signature)
  )
  events[[length(events) + 1L]] <- rho_assistant_text_delta_event(
    rho_openai_chat_partial_message(decoder),
    index,
    event@delta
  )
  events
}

S7::method(rho_reduce_provider_event, OpenAIChatToolDelta) <- function(event, decoder, ...) {
  slot <- rho_openai_chat_tool_slot(decoder, event@tool_index)
  events <- list()
  if (is.null(slot)) {
    if (!nzchar(event@id) || !nzchar(event@name)) {
      return(list(rho_assistant_error_event(
        rho_provider_error(
          "Tool-call stream started without an id or function name",
          kind = "protocol",
          code = "tool_call_fields"
        ),
        rho_openai_chat_partial_message(decoder, stop_reason = "error")
      )))
    }
    content_index <- rho_openai_chat_add_content(
      decoder,
      ToolCall(id = event@id, name = event@name, arguments = list())
    )
    slot <- list(
      content_index = content_index,
      id = event@id,
      name = event@name,
      arguments = "",
      ended = FALSE
    )
    events[[length(events) + 1L]] <- rho_assistant_tool_call_start_event(
      rho_openai_chat_partial_message(decoder),
      content_index,
      event@id,
      event@name
    )
  }
  if (nzchar(event@id)) {
    slot$id <- event@id
  }
  if (nzchar(event@name)) {
    slot$name <- event@name
  }
  slot$arguments <- paste0(slot$arguments, event@arguments_delta)
  call <- ToolCall(
    id = slot$id,
    name = slot$name,
    arguments = list()
  )
  rho_openai_chat_store_content(decoder, slot$content_index, call)
  rho_openai_chat_store_tool_slot(decoder, event@tool_index, slot)
  if (nzchar(event@arguments_delta)) {
    events[[length(events) + 1L]] <- rho_assistant_tool_call_delta_event(
      rho_openai_chat_partial_message(decoder),
      slot$content_index,
      event@arguments_delta
    )
  }
  events
}

rho_openai_chat_close_content <- function(decoder) {
  events <- list()
  thinking_index <- decoder@state$thinking_index
  if (thinking_index > 0L) {
    content <- decoder@state$content[[thinking_index]]
    events[[length(events) + 1L]] <- rho_assistant_thinking_end_event(
      rho_openai_chat_partial_message(decoder),
      thinking_index,
      content
    )
    decoder@state$thinking_index <- -thinking_index
  }
  text_index <- decoder@state$text_index
  if (text_index > 0L) {
    content <- decoder@state$content[[text_index]]
    events[[length(events) + 1L]] <- rho_assistant_text_end_event(
      rho_openai_chat_partial_message(decoder),
      text_index,
      content
    )
    decoder@state$text_index <- -text_index
  }
  for (key in names(decoder@state$tool_slots)) {
    slot <- decoder@state$tool_slots[[key]]
    if (isTRUE(slot$ended)) {
      next
    }
    call <- ToolCall(
      id = slot$id,
      name = slot$name,
      arguments = rho_openai_parse_arguments(slot$arguments)
    )
    rho_openai_chat_store_content(decoder, slot$content_index, call)
    events[[length(events) + 1L]] <- rho_assistant_tool_call_end_event(
      rho_openai_chat_partial_message(decoder),
      slot$content_index,
      call
    )
    slot$ended <- TRUE
    decoder@state$tool_slots[[key]] <- slot
  }
  events
}

S7::method(
  rho_reduce_provider_event,
  OpenAIChatFinishSignal
) <- function(event, decoder, ...) {
  decoder@state$finish_reason <- event@reason
  rho_openai_chat_close_content(decoder)
}

S7::method(
  rho_reduce_provider_event,
  OpenAIChatUsageUpdate
) <- function(event, decoder, ...) {
  decoder@state$usage <- event@usage
  list()
}

rho_openai_chat_usage <- function(decoder) {
  usage <- decoder@state$usage
  if (!is.list(usage) || !length(usage)) {
    return(rho_usage_unavailable(
      decoder@model@provider,
      "OpenAI-compatible stream did not report token usage"
    ))
  }
  input_total <- as.double(usage$prompt_tokens %||% usage$input_tokens %||% 0)
  output <- as.double(usage$completion_tokens %||% usage$output_tokens %||% 0)
  input_details <- usage$prompt_tokens_details %||% usage$input_tokens_details %||% list()
  output_details <- usage$completion_tokens_details %||%
    usage$output_tokens_details %||%
    list()
  cached <- as.double(input_details$cached_tokens %||% 0)
  cache_write <- as.double(input_details$cache_write_tokens %||% 0)
  reasoning <- output_details$reasoning_tokens
  rho_price_usage(
    decoder@model,
    rho_provider_usage(
      provider = decoder@model@provider,
      input = max(0, input_total - cached - cache_write),
      output = output,
      cache_read = cached,
      cache_write = cache_write,
      reasoning = if (is.null(reasoning)) NULL else as.double(reasoning)
    )
  )
}

rho_openai_chat_stop_reason <- function(reason) {
  switch(
    reason,
    tool_calls = "toolUse",
    function_call = "toolUse",
    length = "length",
    stop = "stop",
    "stop"
  )
}

S7::method(rho_reduce_provider_event, OpenAIChatDone) <- function(event, decoder, ...) {
  if (decoder@state$completed) {
    return(list())
  }
  decoder@state$completed <- TRUE
  events <- rho_openai_chat_close_content(decoder)
  reason <- decoder@state$finish_reason
  if (reason %in% c("network_error", "sensitive")) {
    error <- rho_provider_error(
      sprintf("Provider ended generation with finish reason %s", reason),
      kind = "provider",
      code = reason,
      retryable = identical(reason, "network_error")
    )
    return(c(
      events,
      list(rho_assistant_error_event(
        error,
        rho_openai_chat_partial_message(decoder, stop_reason = "error")
      ))
    ))
  }
  stop_reason <- rho_openai_chat_stop_reason(reason)
  message <- rho_openai_chat_partial_message(
    decoder,
    stop_reason = stop_reason,
    usage = rho_openai_chat_usage(decoder)
  )
  c(events, list(rho_assistant_done_event(message, stop_reason)))
}

S7::method(rho_reduce_provider_event, OpenAIChatError) <- function(event, decoder, ...) {
  decoder@state$completed <- TRUE
  list(rho_assistant_error_event(
    event@error,
    rho_openai_chat_partial_message(decoder, stop_reason = "error")
  ))
}
