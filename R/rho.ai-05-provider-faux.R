FauxProvider <- S7::new_class(
  "FauxProvider",
  properties = list(
    script = S7::class_list,
    provider_id = S7::class_character
  )
)

rho_faux_provider <- function(script = list(), provider_id = "faux") {
  FauxProvider(script = script, provider_id = provider_id)
}

rho_faux_content_events <- S7::new_generic(
  "rho_faux_content_events",
  "content",
  function(content, message, content_index, ...) S7::S7_dispatch()
)

S7::method(rho_faux_content_events, TextContent) <- function(content, message, content_index, ...) {
  list(
    rho_assistant_text_start_event(message, content_index),
    rho_assistant_text_delta_event(message, content_index, content@text),
    rho_assistant_text_end_event(message, content_index, content)
  )
}

S7::method(rho_faux_content_events, ThinkingContent) <- function(
  content,
  message,
  content_index,
  ...
) {
  list(
    rho_assistant_thinking_start_event(message, content_index),
    rho_assistant_thinking_delta_event(message, content_index, content@text),
    rho_assistant_thinking_end_event(message, content_index, content)
  )
}

S7::method(rho_faux_content_events, ToolCall) <- function(content, message, content_index, ...) {
  list(
    rho_assistant_tool_call_start_event(
      message,
      content_index,
      content@id,
      content@name
    ),
    rho_assistant_tool_call_end_event(message, content_index, content)
  )
}

S7::method(
  rho_faux_content_events,
  WebSearchCallContent
) <- function(content, message, content_index, ...) {
  list(
    rho_assistant_operation_start_event(message, content_index, content),
    rho_assistant_operation_end_event(message, content_index, content)
  )
}

S7::method(
  rho_faux_content_events,
  WebSearchResultContent
) <- function(content, message, content_index, ...) {
  list(
    rho_assistant_operation_start_event(message, content_index, content),
    rho_assistant_operation_end_event(message, content_index, content)
  )
}

S7::method(rho_faux_content_events, S7::class_any) <- function(
  content,
  message,
  content_index,
  ...
) {
  list()
}

rho_faux_message_events <- function(message) {
  empty <- rho_assistant_message(
    provider = message@provider,
    model = message@model,
    response_id = message@response_id
  )
  updates <- unlist(
    Map(
      function(content, content_index) {
        rho_faux_content_events(content, message, content_index)
      },
      message@content,
      seq_along(message@content)
    ),
    recursive = FALSE
  )
  c(
    list(rho_assistant_start_event(empty)),
    updates,
    list(rho_assistant_done_event(message))
  )
}

S7::method(
  rho_open_provider_transport,
  list(EmbeddedTransport, FauxProvider, Model, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  script <- provider@script
  if (!length(script)) {
    prompt <- context@messages[[length(context@messages)]]@content
    message <- rho_assistant_message(
      content = list(rho_text(paste("faux:", prompt))),
      provider = provider@provider_id,
      model = model@id
    )
    script <- rho_faux_message_events(message)
  }
  rho_list_stream(script)
}
