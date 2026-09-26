rho_provider_transport_unsupported <- function(provider, model, requested, available) {
  requested_id <- rho_transport_id(requested)
  available_ids <- vapply(available, rho_transport_id, character(1))
  ProviderTransportUnsupported(
    kind = "unsupported_transport",
    message = sprintf(
      "%s does not implement %s transport for %s",
      rho_class_label(provider),
      requested_id,
      model@id
    ),
    code = "unsupported_provider_transport",
    retryable = FALSE,
    details = list(
      provider_class = rho_class_label(provider),
      model = model@id,
      requested = requested_id,
      available = available_ids
    )
  )
}

rho_same_transport <- function(left, right) {
  identical(S7::S7_class(left), S7::S7_class(right))
}

S7::method(
  rho_select_provider_transport,
  list(S7::class_any, Model, AutomaticTransport)
) <- function(provider, model, requested, ...) {
  available <- rho_provider_transports(provider, model)
  compatible <- Filter(
    function(transport) rho_model_supports_transport(model, transport),
    available
  )
  if (!length(compatible)) {
    return(rho_provider_transport_unsupported(
      provider,
      model,
      requested,
      available
    ))
  }
  selected <- compatible[[1L]]
  ProviderTransportSelection(
    transport = selected,
    reason = sprintf(
      "%s is the first provider implementation accepted by model %s",
      rho_transport_id(selected),
      model@id
    )
  )
}

S7::method(
  rho_select_provider_transport,
  list(S7::class_any, Model, ProviderTransport)
) <- function(provider, model, requested, ...) {
  available <- rho_provider_transports(provider, model)
  implemented <- any(vapply(
    available,
    rho_same_transport,
    logical(1),
    right = requested
  ))
  if (!implemented || !rho_model_supports_transport(model, requested)) {
    return(rho_provider_transport_unsupported(
      provider,
      model,
      requested,
      available
    ))
  }
  ProviderTransportSelection(
    transport = requested,
    reason = sprintf(
      "%s was explicitly requested and is implemented for model %s",
      rho_transport_id(requested),
      model@id
    )
  )
}

rho_stream_with_transport <- function(provider, model, context, options) {
  requested <- options$transport %||% AutomaticTransport()
  if (
    !S7::S7_inherits(requested, AutomaticTransport) &&
      !S7::S7_inherits(requested, ProviderTransport)
  ) {
    error <- rho_provider_error(
      "Provider transport must be an AutomaticTransport or ProviderTransport value",
      kind = "unsupported_transport",
      code = "transport_value",
      details = list(value_class = rho_class_label(requested))
    )
    return(rho_provider_error_stream(model, error))
  }
  selection <- rho_select_provider_transport(provider, model, requested)
  if (S7::S7_inherits(selection, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, selection))
  }
  options$transport_selection <- selection
  rho_open_provider_transport(
    selection@transport,
    provider,
    model,
    context,
    options = options
  )
}

S7::method(
  rho_stream,
  list(S7::class_any, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_stream_with_transport(provider, model, context, options)
}

S7::method(
  rho_provider_transports,
  list(S7::class_any, Model)
) <- function(provider, model, ...) {
  list()
}

S7::method(
  rho_open_provider_transport,
  list(ProviderTransport, S7::class_any, Model, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  rho_provider_error_stream(
    model,
    rho_provider_transport_unsupported(
      provider,
      model,
      transport,
      rho_provider_transports(provider, model)
    )
  )
}

S7::method(rho_provider_transports, list(FauxProvider, Model)) <- function(
  provider,
  model,
  ...
) {
  list(EmbeddedTransport())
}

S7::method(rho_provider_transports, list(OpenAIApi, OpenAIResponsesModel)) <- function(
  provider,
  model,
  ...
) {
  list(SseTransport())
}

S7::method(
  rho_provider_transports,
  list(OpenAICodexApi, OpenAICodexResponsesModel)
) <- function(provider, model, ...) {
  if (s7contract::implements(provider@http, WebSocketClient)) {
    return(list(WebSocketTransport(), SseTransport()))
  }
  list(SseTransport())
}

S7::method(
  rho_provider_transports,
  list(GitHubCopilotApi, GitHubCopilotResponsesModel)
) <- function(provider, model, ...) {
  list(SseTransport())
}

S7::method(
  rho_provider_transports,
  list(GitHubCopilotAnthropicApi, AnthropicMessagesModel)
) <- function(provider, model, ...) {
  list(SseTransport())
}

S7::method(
  rho_provider_transports,
  list(AnthropicApi, AnthropicMessagesModel)
) <- function(provider, model, ...) {
  list(SseTransport())
}

S7::method(rho_provider_transports, list(ZaiApi, ZaiChatCompletionsModel)) <- function(
  provider,
  model,
  ...
) {
  list(SseTransport())
}

S7::method(
  rho_provider_transports,
  list(OllamaProvider, OpenAIChatCompletionsModel)
) <- function(provider, model, ...) {
  list(SseTransport())
}
