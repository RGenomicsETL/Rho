OllamaProvider <- S7::new_class(
  "OllamaProvider",
  properties = list(
    base_url = rho_non_empty_string,
    http = RhoHttpClient
  )
)

rho_ollama_provider <- function(
  base_url = "http://localhost:11434",
  http = rho_http_client()
) {
  OllamaProvider(base_url = base_url, http = http)
}

rho_ollama_model <- function(
  id,
  name = id,
  base_url = "http://localhost:11434/v1",
  context_window = 128000L,
  max_tokens = 4096L,
  reasoning = FALSE,
  tools = TRUE
) {
  rho_new_model(
    OpenAIChatCompletionsModel,
    provider = "ollama",
    id = id,
    name = name,
    api = "openai-chat-completions",
    base_url = base_url,
    context_window = context_window,
    max_tokens = max_tokens,
    reasoning = reasoning,
    tools = tools,
    transports = list(SseTransport()),
    pricing = rho_model_pricing()
  )
}

rho_ollama_chat_request <- function(
  provider,
  model,
  context,
  stream = TRUE,
  options = list()
) {
  request_options <- options
  request_options$stream <- isTRUE(stream)
  rho_build_provider_request(
    provider,
    model,
    context,
    options = request_options
  )
}

S7::method(
  rho_build_provider_request,
  list(OllamaProvider, OpenAIChatCompletionsModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  operation_plan <- rho_bound_operation_plan(
    provider,
    model,
    context,
    options
  )
  if (S7::S7_inherits(operation_plan, ProviderErrorValue)) {
    return(operation_plan)
  }
  options$operation_plan <- operation_plan
  request_body <- rho_openai_chat_request_body(model, context, options = options)
  if (S7::S7_inherits(request_body, ProviderErrorValue)) {
    return(request_body)
  }
  request_body$stream <- options$stream %||% TRUE
  rho_http_request(
    method = "POST",
    url = paste0(sub("/+$", "", provider@base_url), "/v1/chat/completions"),
    headers = list(
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    ),
    body = request_body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after"),
    convert = TRUE
  )
}

rho_ollama_chat_task <- function(provider, model, context, options = list()) {
  rho_complete(provider, model, context, options = options)
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, OllamaProvider, OpenAIChatCompletionsModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_ollama_chat_request(
    provider,
    model,
    context,
    stream = TRUE,
    options = options
  )
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  stream <- rho_sse_connect(provider@http, request)
  decoder <- rho_openai_chat_decoder(model)
  rho_stream_flat_map(
    stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}
