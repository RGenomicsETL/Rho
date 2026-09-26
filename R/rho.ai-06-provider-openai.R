OpenAIApi <- S7::new_class(
  "OpenAIApi",
  properties = list(
    base_url = rho_non_empty_string,
    http = RhoHttpClient
  )
)

OpenAIApiKeyAuth <- S7::new_class(
  "OpenAIApiKeyAuth",
  properties = list(
    name = rho_non_empty_string,
    provider_id = rho_non_empty_string
  )
)

rho_openai_model <- function(id, catalog = rho_default_model_catalog()) {
  rho_catalog_model(catalog, "openai", id)
}

rho_openai_provider <- function(
  base_url = "https://api.openai.com/v1",
  http = rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  api <- OpenAIApi(base_url = base_url, http = http)
  rho_provider(
    id = "openai",
    name = "OpenAI",
    implementation = api,
    auth = rho_provider_auth(
      api_key = OpenAIApiKeyAuth(
        name = "OpenAI",
        provider_id = "openai"
      )
    ),
    models = rho_catalog_models(
      catalog,
      provider = "openai",
      protocol = OpenAIResponsesProtocol()
    )
  )
}

S7::method(rho_auth_login, OpenAIApiKeyAuth) <- function(auth, provider_id, io, ...) {
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
        return(rho_auth_error("OpenAI API key was not supplied", code = "missing"))
      }
      rho_api_key_credential(auth@provider_id, key, source = "login")
    }
  )
}

S7::method(rho_auth_to_request, OpenAIApiKeyAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, RhoApiKeyCredential) &&
    identical(credential@provider, auth@provider_id) &&
    nzchar(credential@state$key)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "OpenAI request auth requires a matching API-key credential",
      code = "credential_type"
    )))
  }
  rho_task(rho_model_auth(
    api_key = credential@state$key,
    metadata = list(provider = credential@provider, source = credential@source)
  ))
}

S7::method(rho_credential_decode, OpenAIApiKeyAuth) <- function(
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
  list(OpenAIApi, OpenAIResponsesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  utils::modifyList(model@headers, options$headers %||% list())
}

S7::method(
  rho_provider_support,
  list(OpenAIApi, OpenAIResponsesModel, RhoToolSearchOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_tool_search
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(model = model@id)
  )
}

S7::method(
  rho_provider_support,
  list(OpenAIApi, OpenAIResponsesModel, RhoWebSearchOperation)
) <- function(provider, model, operation, ...) {
  capability <- model@compatibility@web_search
  rho_provider_support_value(
    S7::S7_inherits(capability, OpenAIWebSearchCapability),
    source = "openai-responses-model-profile",
    details = list(model = model@id, capability = rho_class_label(capability))
  )
}

S7::method(
  rho_bind_operation,
  list(OpenAIApi, OpenAIResponsesModel, RhoWebSearchOperation)
) <- function(handler, model, operation, context, ...) {
  rho_bind_web_search(
    model@compatibility@web_search,
    handler,
    model,
    operation,
    context,
    ...
  )
}

S7::method(
  rho_bind_web_search,
  OpenAIWebSearchCapability
) <- function(capability, handler, model, operation, context, ...) {
  rho_openai_web_search_binding(
    operation@domains,
    handler,
    model,
    operation
  )
}

S7::method(
  rho_provider_support,
  list(OpenAIApi, OpenAIResponsesModel, RhoNativeCompactionOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_native_compaction
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(model = model@id)
  )
}

S7::method(
  rho_plan_tools,
  list(OpenAIApi, OpenAIResponsesModel, Context)
) <- function(provider, model, context, ...) {
  support <- rho_provider_support(provider, model, RhoToolSearchOperation())
  if (!support@supported) {
    return(rho_full_tool_placement(
      context@tools,
      reason = sprintf(
        "OpenAI tool search is not verified for %s; every request advertises all active definitions",
        model@id
      ),
      cache_expectation = if (length(rho_deferred_tool_names(context))) {
        "replace-prefix"
      } else {
        "unchanged"
      }
    ))
  }
  placement <- rho_split_deferred_tools(context)
  rho_openai_tool_search_placement(placement$immediate, placement$deferred)
}

rho_openai_responses_url <- function(base_url) {
  normalized <- sub("/+$", "", base_url)
  if (endsWith(normalized, "/responses")) normalized else paste0(normalized, "/responses")
}

rho_openai_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

S7::method(
  rho_build_provider_request,
  list(OpenAIApi, OpenAIResponsesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "OpenAI requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }
  placement <- options$tool_placement %||% rho_plan_tools(provider, model, context)
  if (!S7::S7_inherits(placement, RhoToolPlacement)) {
    return(rho_provider_error(
      "OpenAI `tool_placement` must inherit from RhoToolPlacement",
      kind = "configuration",
      code = "openai_tool_placement"
    ))
  }
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
  body <- rho_openai_responses_body(model, context, placement, options)
  if (S7::S7_inherits(body, ProviderErrorValue)) {
    return(body)
  }
  base_url <- if (nzchar(auth@base_url)) auth@base_url else provider@base_url
  headers <- utils::modifyList(
    list(
      Authorization = paste("Bearer", auth@api_key),
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    ),
    rho_provider_headers(provider, model, context, options = options)
  )
  headers <- utils::modifyList(headers, auth@headers)
  if (!is.null(options$session_id)) {
    headers$`x-client-request-id` <- options$session_id
  }
  rho_http_request(
    method = "POST",
    url = rho_openai_responses_url(base_url),
    headers = headers,
    body = body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after", "retry-after-ms"),
    convert = TRUE
  )
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, OpenAIApi, OpenAIResponsesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_openai_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  stream <- rho_sse_connect(provider@http, request)
  decoder <- rho_openai_responses_decoder(model)
  rho_stream_flat_map(
    stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}
