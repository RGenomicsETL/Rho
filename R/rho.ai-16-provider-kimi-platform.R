KimiPlatformEndpoint <- S7::new_class(
  "KimiPlatformEndpoint",
  abstract = TRUE,
  properties = list(
    provider_id = rho_non_empty_string,
    name = rho_non_empty_string,
    base_url = rho_non_empty_string
  )
)

KimiPlatformGlobalEndpoint <- S7::new_class(
  "KimiPlatformGlobalEndpoint",
  parent = KimiPlatformEndpoint
)
KimiPlatformChinaEndpoint <- S7::new_class(
  "KimiPlatformChinaEndpoint",
  parent = KimiPlatformEndpoint
)

KimiPlatformApi <- S7::new_class(
  "KimiPlatformApi",
  properties = list(
    endpoint = KimiPlatformEndpoint,
    http = RhoHttpClient
  )
)

KimiPlatformApiKeyAuth <- S7::new_class(
  "KimiPlatformApiKeyAuth",
  properties = list(
    name = rho_non_empty_string,
    provider_id = rho_non_empty_string
  )
)

KimiPlatformChatCompletionsModel <- S7::new_class(
  "KimiPlatformChatCompletionsModel",
  parent = OpenAIChatCompletionsModel
)

KimiPlatformThinkingRequest <- S7::new_class(
  "KimiPlatformThinkingRequest",
  parent = ProviderRequestSection,
  abstract = TRUE
)
KimiPlatformThinkingUnspecified <- S7::new_class(
  "KimiPlatformThinkingUnspecified",
  parent = KimiPlatformThinkingRequest
)
KimiPlatformThinkingDisabled <- S7::new_class(
  "KimiPlatformThinkingDisabled",
  parent = KimiPlatformThinkingRequest
)
KimiPlatformThinkingEnabled <- S7::new_class(
  "KimiPlatformThinkingEnabled",
  parent = KimiPlatformThinkingRequest
)
KimiPlatformThinkingEffort <- S7::new_class(
  "KimiPlatformThinkingEffort",
  parent = KimiPlatformThinkingEnabled,
  properties = list(effort = rho_non_empty_string)
)

rho_kimi_platform_thinking <- S7::new_generic(
  "rho_kimi_platform_thinking",
  c("model", "level"),
  function(model, level, ...) S7::S7_dispatch()
)

S7::method(
  rho_model_expression,
  list(
    KimiPlatformModelCatalogProvider,
    OpenAIChatCompletionsProtocol,
    ModelCatalogRecord
  )
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "KimiPlatformChatCompletionsModel",
    record,
    api = "kimi-chat-completions"
  )
}

rho_kimi_platform_global_endpoint <- function() {
  KimiPlatformGlobalEndpoint(
    provider_id = "moonshotai",
    name = "Kimi Platform",
    base_url = "https://api.moonshot.ai/v1"
  )
}

rho_kimi_platform_china_endpoint <- function() {
  KimiPlatformChinaEndpoint(
    provider_id = "moonshotai-cn",
    name = "Kimi Platform China",
    base_url = "https://api.moonshot.cn/v1"
  )
}

rho_kimi_platform_model <- function(
  id,
  endpoint = rho_kimi_platform_global_endpoint(),
  catalog = rho_default_model_catalog()
) {
  rho_catalog_model(catalog, endpoint@provider_id, id)
}

rho_kimi_platform_provider <- function(
  endpoint = rho_kimi_platform_global_endpoint(),
  http = rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  rho_provider(
    id = endpoint@provider_id,
    name = endpoint@name,
    implementation = KimiPlatformApi(endpoint = endpoint, http = http),
    auth = rho_provider_auth(
      api_key = KimiPlatformApiKeyAuth(
        name = endpoint@name,
        provider_id = endpoint@provider_id
      )
    ),
    models = rho_catalog_models(
      catalog,
      provider = endpoint@provider_id,
      protocol = OpenAIChatCompletionsProtocol()
    )
  )
}

S7::method(
  rho_kimi_platform_thinking,
  list(KimiPlatformChatCompletionsModel, ThinkingUnspecified)
) <- function(model, level, ...) {
  KimiPlatformThinkingUnspecified()
}

S7::method(
  rho_kimi_platform_thinking,
  list(KimiPlatformChatCompletionsModel, ThinkingOff)
) <- function(model, level, ...) {
  if (model@capabilities@reasoning) {
    KimiPlatformThinkingDisabled()
  } else {
    KimiPlatformThinkingUnspecified()
  }
}

S7::method(
  rho_kimi_platform_thinking,
  list(KimiPlatformChatCompletionsModel, ThinkingEnabled)
) <- function(model, level, ...) {
  if (!model@capabilities@reasoning) {
    return(rho_unsupported_provider_operation(
      "kimi_platform_thinking",
      sprintf("Kimi Platform model %s does not declare thinking support", model@id)
    ))
  }
  if (!length(model@capabilities@thinking_level_map)) {
    return(KimiPlatformThinkingEnabled())
  }
  KimiPlatformThinkingEffort(
    effort = rho_map_thinking_level(model, level@name)
  )
}

S7::method(rho_request_fields, KimiPlatformThinkingUnspecified) <- function(section, ...) {
  list()
}

S7::method(rho_request_fields, KimiPlatformThinkingDisabled) <- function(section, ...) {
  list(thinking = list(type = "disabled"))
}

S7::method(rho_request_fields, KimiPlatformThinkingEnabled) <- function(section, ...) {
  list(thinking = list(type = "enabled"))
}

S7::method(rho_request_fields, KimiPlatformThinkingEffort) <- function(section, ...) {
  list(thinking = list(type = "enabled", effort = section@effort))
}

S7::method(
  rho_openai_chat_request_body,
  list(KimiPlatformChatCompletionsModel, Context)
) <- function(model, context, options = list(), ...) {
  request <- rho_openai_chat_core_request_body(model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(request)
  }
  request$max_completion_tokens <- request$max_tokens
  request$max_tokens <- NULL
  thinking <- rho_kimi_platform_thinking(
    model,
    rho_thinking_level(options$reasoning_effort)
  )
  if (S7::S7_inherits(thinking, ProviderErrorValue)) {
    return(thinking)
  }
  utils::modifyList(request, rho_request_fields(thinking))
}

S7::method(rho_auth_login, KimiPlatformApiKeyAuth) <- function(
  auth,
  provider_id,
  io,
  ...
) {
  rho_then(
    rho_auth_prompt(
      io,
      RhoSecretAuthPrompt(
        message = sprintf("Enter the API key for %s:", auth@name),
        placeholder = ""
      )
    ),
    function(key) {
      if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
        return(rho_auth_error("Kimi Platform API key was not supplied", code = "missing"))
      }
      rho_api_key_credential(auth@provider_id, key, source = "login")
    }
  )
}

S7::method(rho_auth_to_request, KimiPlatformApiKeyAuth) <- function(
  auth,
  credential,
  ...
) {
  valid <- S7::S7_inherits(credential, RhoApiKeyCredential) &&
    identical(credential@provider, auth@provider_id) &&
    nzchar(credential@state$key)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "Kimi Platform request auth requires a matching API-key credential",
      code = "credential_type"
    )))
  }
  rho_task(rho_model_auth(
    api_key = credential@state$key,
    metadata = list(
      provider = credential@provider,
      source = credential@source,
      product = "kimi-platform"
    )
  ))
}

S7::method(rho_credential_decode, KimiPlatformApiKeyAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  rho_decode_api_key_credential(document, provider_id, source)
}

S7::method(
  rho_provider_headers,
  list(KimiPlatformApi, KimiPlatformChatCompletionsModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  utils::modifyList(model@headers, options$headers %||% list())
}

rho_kimi_platform_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

S7::method(
  rho_build_provider_request,
  list(KimiPlatformApi, KimiPlatformChatCompletionsModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "Kimi Platform requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }
  operation_plan <- rho_bound_operation_plan(provider, model, context, options)
  if (S7::S7_inherits(operation_plan, ProviderErrorValue)) {
    return(operation_plan)
  }
  options$operation_plan <- operation_plan
  body <- rho_openai_chat_request_body(model, context, options = options)
  if (S7::S7_inherits(body, ProviderErrorValue)) {
    return(body)
  }
  base_url <- if (nzchar(auth@base_url)) {
    auth@base_url
  } else {
    provider@endpoint@base_url
  }
  headers <- utils::modifyList(
    list(
      Authorization = paste("Bearer", auth@api_key),
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    ),
    rho_provider_headers(provider, model, context, options = options)
  )
  headers <- utils::modifyList(headers, auth@headers)
  rho_http_request(
    method = "POST",
    url = paste0(sub("/+$", "", base_url), "/chat/completions"),
    headers = headers,
    body = body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after", "x-trace-id"),
    convert = TRUE
  )
}

S7::method(
  rho_provider_transports,
  list(KimiPlatformApi, KimiPlatformChatCompletionsModel)
) <- function(provider, model, ...) {
  list(SseTransport())
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, KimiPlatformApi, KimiPlatformChatCompletionsModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_kimi_platform_request(provider, model, context, options)
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
