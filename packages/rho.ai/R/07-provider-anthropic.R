AnthropicApi <- S7::new_class(
  "AnthropicApi",
  properties = list(
    base_url = rho_non_empty_string,
    version = rho_non_empty_string,
    http = rho.http::RhoHttpClient
  )
)

AnthropicApiKeyAuth <- S7::new_class(
  "AnthropicApiKeyAuth",
  properties = list(
    name = rho_non_empty_string,
    provider_id = rho_non_empty_string
  )
)

AnthropicOAuthCredential <- S7::new_class(
  "AnthropicOAuthCredential",
  parent = RhoOAuthCredential
)

AnthropicOAuthModelAuth <- S7::new_class(
  "AnthropicOAuthModelAuth",
  parent = RhoModelAuth,
  properties = list(client_version = rho_non_empty_string)
)

AnthropicOAuthAuth <- S7::new_class(
  "AnthropicOAuthAuth",
  parent = RhoOAuthAuth,
  properties = list(
    authorize_url = rho_non_empty_string,
    token_url = rho_non_empty_string,
    client_id = rho_non_empty_string,
    client_version = rho_non_empty_string,
    http = rho.http::RhoHttpClient
  )
)

rho_anthropic_oauth_client_id <- "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
rho_anthropic_oauth_scopes <- paste(
  "org:create_api_key",
  "user:profile",
  "user:inference",
  "user:sessions:claude_code",
  "user:mcp_servers",
  "user:file_upload"
)
rho_anthropic_oauth_redirect_uri <- "http://localhost:53692/callback"

rho_anthropic_oauth_auth <- function(
  authorize_url = "https://claude.ai/oauth/authorize",
  token_url = "https://platform.claude.com/v1/oauth/token",
  client_id = rho_anthropic_oauth_client_id,
  client_version = "2.1.75",
  http = rho.http::rho_http_client(timeout_ms = 30000L)
) {
  AnthropicOAuthAuth(
    name = "Anthropic (Claude Pro/Max)",
    authorize_url = authorize_url,
    token_url = token_url,
    client_id = client_id,
    client_version = client_version,
    http = http
  )
}

rho_anthropic_oauth_credential <- function(
  access_token,
  refresh_token,
  expires,
  source = ""
) {
  state <- new.env(parent = emptyenv())
  state$access <- access_token
  state$refresh <- refresh_token
  AnthropicOAuthCredential(
    provider = "anthropic",
    account_id = "",
    expires = as.double(expires),
    source = source,
    metadata = list(subscription = TRUE),
    state = state
  )
}

rho_anthropic_endpoint_url <- S7::new_generic(
  "rho_anthropic_endpoint_url",
  "provider",
  function(provider, model, auth, ...) S7::S7_dispatch()
)

rho_anthropic_endpoint_headers <- S7::new_generic(
  "rho_anthropic_endpoint_headers",
  "provider",
  function(provider, model, context, auth, beta_features, options = list(), ...) {
    S7::S7_dispatch()
  }
)

rho_anthropic_endpoint_http <- S7::new_generic(
  "rho_anthropic_endpoint_http",
  "provider",
  function(provider, ...) S7::S7_dispatch()
)

rho_anthropic_auth_headers <- S7::new_generic(
  "rho_anthropic_auth_headers",
  "auth",
  function(auth, beta_features, ...) S7::S7_dispatch()
)

rho_anthropic_system_identity <- S7::new_generic(
  "rho_anthropic_system_identity",
  "auth",
  function(auth, ...) S7::S7_dispatch()
)

AnthropicMessagesEndpoint <- s7contract::new_interface(
  "AnthropicMessagesEndpoint",
  generics = list(
    rho_anthropic_endpoint_url = rho_anthropic_endpoint_url,
    rho_anthropic_endpoint_headers = rho_anthropic_endpoint_headers,
    rho_anthropic_endpoint_http = rho_anthropic_endpoint_http
  )
)

rho_anthropic_model <- function(id, catalog = rho_default_model_catalog()) {
  rho_catalog_model(catalog, "anthropic", id)
}

rho_anthropic_provider <- function(
  base_url = "https://api.anthropic.com",
  version = "2023-06-01",
  http = rho.http::rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  api <- AnthropicApi(
    base_url = base_url,
    version = version,
    http = http
  )
  rho_provider(
    id = "anthropic",
    name = "Anthropic",
    implementation = api,
    auth = rho_provider_auth(
      api_key = AnthropicApiKeyAuth(
        name = "Anthropic",
        provider_id = "anthropic"
      ),
      oauth = rho_anthropic_oauth_auth(http = http)
    ),
    models = rho_catalog_models(
      catalog,
      provider = "anthropic",
      protocol = AnthropicMessagesProtocol()
    )
  )
}

S7::method(rho_auth_login, AnthropicApiKeyAuth) <- function(auth, provider_id, io, ...) {
  rho.async::rho_then(
    rho_auth_prompt(
      io,
      RhoSecretAuthPrompt(
        message = sprintf("Enter the API key for %s:", auth@name),
        placeholder = ""
      )
    ),
    function(key) {
      if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
        return(rho_auth_error("Anthropic API key was not supplied", code = "missing"))
      }
      rho_api_key_credential(auth@provider_id, key, source = "login")
    }
  )
}

S7::method(rho_auth_to_request, AnthropicApiKeyAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, RhoApiKeyCredential) &&
    identical(credential@provider, auth@provider_id) &&
    nzchar(credential@state$key)
  if (!valid) {
    return(rho.async::rho_task(rho_auth_error(
      "Anthropic request auth requires a matching API-key credential",
      code = "credential_type"
    )))
  }
  rho.async::rho_task(rho_model_auth(
    api_key = credential@state$key,
    metadata = list(provider = credential@provider, source = credential@source)
  ))
}

S7::method(rho_credential_decode, AnthropicApiKeyAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  rho_decode_api_key_credential(document, provider_id, source)
}

rho_anthropic_oauth_document <- function(response, operation) {
  if (is.na(response@status) || response@status < 200L || response@status >= 300L) {
    return(rho_auth_error(
      sprintf("Anthropic OAuth %s failed with HTTP status %s", operation, response@status),
      code = "http",
      retryable = response@status %in% c(408L, 409L, 425L, 429L) || response@status >= 500L,
      details = list(status = response@status)
    ))
  }
  if (is.list(response@data)) {
    return(response@data)
  }
  text <- if (is.raw(response@data)) rawToChar(response@data) else as.character(response@data)
  document <- tryCatch(
    yyjsonr::read_json_str(text, arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE),
    error = function(error) error
  )
  if (inherits(document, "error") || !is.list(document)) {
    return(rho_auth_error(
      sprintf("Anthropic OAuth %s returned invalid JSON", operation),
      code = "response_format"
    ))
  }
  document
}

rho_anthropic_oauth_http_task <- function(auth, request, operation) {
  rho.async::rho_then(
    rho.http::rho_http_send(auth@http, request),
    function(response) rho_anthropic_oauth_document(response, operation),
    function(error) {
      rho_auth_error(
        sprintf("Anthropic OAuth %s transport failed: %s", operation, conditionMessage(error)),
        code = "transport",
        retryable = TRUE
      )
    }
  )
}

rho_anthropic_oauth_token <- function(auth, fields, source, operation) {
  request <- rho.http::rho_http_request(
    method = "POST",
    url = auth@token_url,
    headers = list(
      Accept = "application/json",
      `Content-Type` = "application/json"
    ),
    body = fields,
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho_anthropic_oauth_http_task(auth, request, operation),
    function(document) {
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      expires_in <- suppressWarnings(as.double(document$expires_in))
      if (
        !rho_valid_oauth_token_fields(
          document$access_token,
          document$refresh_token,
          expires_in
        )
      ) {
        return(rho_auth_error(
          sprintf("Anthropic OAuth %s response is missing token fields", operation),
          code = "response_fields"
        ))
      }
      rho_anthropic_oauth_credential(
        access_token = document$access_token,
        refresh_token = document$refresh_token,
        expires = as.double(Sys.time()) * 1000 + expires_in * 1000 - 5 * 60 * 1000,
        source = source
      )
    }
  )
}

rho_anthropic_oauth_login <- function(auth, io) {
  pkce <- rho_pkce()
  authorize_url <- paste0(
    auth@authorize_url,
    "?",
    rho_form_urlencode(list(
      code = "true",
      client_id = auth@client_id,
      response_type = "code",
      redirect_uri = rho_anthropic_oauth_redirect_uri,
      scope = rho_anthropic_oauth_scopes,
      code_challenge = pkce$challenge,
      code_challenge_method = "S256",
      state = pkce$state
    ))
  )
  rho.async::rho_then(
    rho_auth_notify(
      io,
      RhoAuthUrlEvent(
        url = authorize_url,
        instructions = paste(
          "Complete login in your browser, then paste the authorization code",
          "or redirect URL."
        )
      )
    ),
    function(ignored) {
      rho.async::rho_then(
        rho_auth_prompt(
          io,
          RhoManualCodeAuthPrompt(
            message = "Paste the Anthropic authorization code or redirect URL:",
            placeholder = rho_anthropic_oauth_redirect_uri
          )
        ),
        function(input) {
          code <- rho_authorization_code(input, pkce$state, "Anthropic")
          if (S7::S7_inherits(code, ProviderErrorValue)) {
            return(code)
          }
          rho_anthropic_oauth_token(
            auth,
            list(
              grant_type = "authorization_code",
              client_id = auth@client_id,
              code = code,
              state = pkce$state,
              redirect_uri = rho_anthropic_oauth_redirect_uri,
              code_verifier = pkce$verifier
            ),
            source = "login",
            operation = "authorization-code exchange"
          )
        }
      )
    }
  )
}

S7::method(rho_auth_login, AnthropicOAuthAuth) <- function(auth, provider_id, io, ...) {
  rho_anthropic_oauth_login(auth, io)
}

S7::method(rho_auth_refresh, AnthropicOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, AnthropicOAuthCredential) &&
    nzchar(credential@state$refresh)
  if (!valid) {
    return(rho.async::rho_task(rho_auth_error(
      "Anthropic OAuth refresh requires an AnthropicOAuthCredential",
      code = "credential_type"
    )))
  }
  rho_anthropic_oauth_token(
    auth,
    list(
      grant_type = "refresh_token",
      client_id = auth@client_id,
      refresh_token = credential@state$refresh
    ),
    source = credential@source,
    operation = "token refresh"
  )
}

S7::method(rho_auth_to_request, AnthropicOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, AnthropicOAuthCredential) &&
    nzchar(credential@state$access)
  if (!valid) {
    return(rho.async::rho_task(rho_auth_error(
      "Anthropic OAuth request auth requires an AnthropicOAuthCredential",
      code = "credential_type"
    )))
  }
  rho.async::rho_task(AnthropicOAuthModelAuth(
    api_key = credential@state$access,
    headers = list(),
    base_url = "",
    metadata = list(provider = credential@provider, source = credential@source),
    client_version = auth@client_version
  ))
}

S7::method(rho_credential_decode, AnthropicOAuthAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  tryCatch(
    rho_anthropic_oauth_credential(
      access_token = document$access,
      refresh_token = document$refresh %||% "",
      expires = as.double(document$expires %||% NA_real_),
      source = source
    ),
    error = function(error) {
      rho_auth_error(conditionMessage(error), code = "credential_store_format")
    }
  )
}

rho_anthropic_credential_from_document <- function(document, source) {
  value <- document$anthropic
  if (!is.list(value) || !identical(value$type, "oauth")) {
    return(rho_auth_error(
      "The supplied file contains no Anthropic OAuth credential",
      code = "credential_format"
    ))
  }
  tryCatch(
    rho_anthropic_oauth_credential(
      access_token = value$access,
      refresh_token = value$refresh,
      expires = value$expires %||% NA_real_,
      source = source
    ),
    error = function(error) {
      rho_auth_error(conditionMessage(error), code = "credential_format")
    }
  )
}

rho_load_anthropic_credential <- function(path) {
  rho.async::rho_task_from_function(
    function() {
      if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
        return(rho_auth_error("`path` must be supplied explicitly", "credential_path"))
      }
      if (!file.exists(path)) {
        return(rho_auth_error(
          sprintf("Credential file does not exist: %s", path),
          "credential_path"
        ))
      }
      document <- tryCatch(
        yyjsonr::read_json_file(path, arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE),
        error = function(error) error
      )
      if (inherits(document, "error")) {
        return(rho_auth_error(
          sprintf("Could not parse credential file: %s", conditionMessage(document)),
          "credential_format"
        ))
      }
      source <- normalizePath(path, winslash = "/", mustWork = TRUE)
      rho_anthropic_credential_from_document(document, source)
    },
    label = "anthropic-credential-import"
  )
}

S7::method(
  rho_provider_headers,
  list(AnthropicApi, AnthropicMessagesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  utils::modifyList(model@headers, options$headers %||% list())
}

S7::method(rho_anthropic_auth_headers, RhoModelAuth) <- function(
  auth,
  beta_features,
  ...
) {
  headers <- list(`x-api-key` = auth@api_key)
  if (length(beta_features)) {
    headers$`anthropic-beta` <- paste(
      vapply(beta_features, rho_anthropic_beta_name, character(1)),
      collapse = ","
    )
  }
  headers
}

S7::method(rho_anthropic_auth_headers, AnthropicOAuthModelAuth) <- function(
  auth,
  beta_features,
  ...
) {
  beta <- c(
    "claude-code-20250219",
    "oauth-2025-04-20",
    vapply(beta_features, rho_anthropic_beta_name, character(1))
  )
  list(
    Authorization = paste("Bearer", auth@api_key),
    `anthropic-dangerous-direct-browser-access` = "true",
    `anthropic-beta` = paste(unique(beta), collapse = ","),
    `user-agent` = paste0("claude-cli/", auth@client_version),
    `x-app` = "cli"
  )
}

S7::method(rho_anthropic_system_identity, S7::class_any) <- function(auth, ...) {
  character()
}

S7::method(
  rho_anthropic_system_identity,
  AnthropicOAuthModelAuth
) <- function(auth, ...) {
  "You are Claude Code, Anthropic's official CLI for Claude."
}

S7::method(rho_anthropic_tool_name_policy, S7::class_any) <- function(auth, ...) {
  rho_anthropic_exact_tool_names()
}

S7::method(
  rho_anthropic_tool_name_policy,
  AnthropicOAuthModelAuth
) <- function(auth, ...) {
  rho_anthropic_claude_code_tool_names()
}

S7::method(
  rho_provider_support,
  list(S7::class_any, AnthropicMessagesModel, RhoToolReferencesOperation)
) <- function(provider, model, operation, ...) {
  rho_provider_support_value(
    model@compatibility@supports_tool_references,
    source = "anthropic-messages-capability-profile",
    details = list(model = model@id)
  )
}

S7::method(
  rho_provider_support,
  list(AnthropicApi, AnthropicMessagesModel, RhoWebSearchOperation)
) <- function(provider, model, operation, ...) {
  capability <- model@compatibility@web_search
  rho_provider_support_value(
    S7::S7_inherits(capability, AnthropicWebSearchProtocol),
    source = "anthropic-messages-model-profile",
    details = list(model = model@id, capability = rho_class_label(capability))
  )
}

S7::method(
  rho_bind_operation,
  list(AnthropicApi, AnthropicMessagesModel, RhoWebSearchOperation)
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
  AnthropicWebSearchProtocol
) <- function(capability, handler, model, operation, context, ...) {
  AnthropicWebSearchBinding(
    operation = operation,
    handler = handler,
    reason = paste(
      "The selected Anthropic Messages endpoint implements this search",
      "as a server tool"
    ),
    protocol = capability
  )
}

S7::method(
  rho_provider_support,
  list(S7::class_any, AnthropicMessagesModel, RhoCacheRetentionOperation)
) <- function(provider, model, operation, ...) {
  rho_provider_support_value(
    TRUE,
    source = "anthropic-messages-capability-profile",
    details = list(
      model = model@id,
      short = TRUE,
      long = model@compatibility@cache@long_retention
    )
  )
}

S7::method(
  rho_plan_tools,
  list(S7::class_any, AnthropicMessagesModel, Context)
) <- function(provider, model, context, ...) {
  rho_anthropic_plan_tools(provider, model, context)
}

rho_anthropic_plan_tools <- function(provider, model, context) {
  support <- rho_provider_support(provider, model, RhoToolReferencesOperation())
  if (!support@supported) {
    return(rho_full_tool_placement(
      context@tools,
      reason = sprintf(
        "Anthropic tool references are not verified for %s; all active definitions are advertised",
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
  rho_anthropic_tool_reference_placement(placement$immediate, placement$deferred)
}

S7::method(
  rho_anthropic_endpoint_url,
  AnthropicApi
) <- function(provider, model, auth, ...) {
  base_url <- if (nzchar(auth@base_url)) auth@base_url else provider@base_url
  rho_anthropic_messages_url(base_url)
}

rho_anthropic_messages_url <- function(base_url) {
  normalized <- sub("/+$", "", base_url)
  if (endsWith(normalized, "/v1/messages")) {
    return(normalized)
  }
  if (endsWith(normalized, "/v1")) {
    return(paste0(normalized, "/messages"))
  }
  paste0(normalized, "/v1/messages")
}

S7::method(
  rho_anthropic_endpoint_headers,
  AnthropicApi
) <- function(
  provider,
  model,
  context,
  auth,
  beta_features,
  options = list(),
  ...
) {
  headers <- utils::modifyList(
    rho_anthropic_auth_headers(auth, beta_features),
    list(
      `anthropic-version` = provider@version,
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    )
  )
  headers <- utils::modifyList(
    headers,
    rho_provider_headers(provider, model, context, options = options)
  )
  utils::modifyList(headers, auth@headers)
}

S7::method(rho_anthropic_endpoint_http, AnthropicApi) <- function(provider, ...) {
  provider@http
}

rho_anthropic_messages_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

S7::method(
  rho_build_provider_request,
  list(AnthropicApi, AnthropicMessagesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_anthropic_build_request(provider, model, context, options)
}

rho_anthropic_build_request <- function(provider, model, context, options = list()) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "Anthropic requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }
  placement <- options$tool_placement %||% rho_plan_tools(provider, model, context)
  if (!S7::S7_inherits(placement, RhoToolPlacement)) {
    return(rho_provider_error(
      "Anthropic `tool_placement` must inherit from RhoToolPlacement",
      kind = "configuration",
      code = "anthropic_tool_placement"
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
  plan <- rho_anthropic_request_plan(model, context, placement, options)
  if (S7::S7_inherits(plan, ProviderErrorValue)) {
    return(plan)
  }
  rho.http::rho_http_request(
    method = "POST",
    url = rho_anthropic_endpoint_url(provider, model, auth),
    headers = rho_anthropic_endpoint_headers(
      provider,
      model,
      context,
      auth,
      plan@beta_features,
      options
    ),
    body = rho_request_body(plan),
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after"),
    convert = TRUE
  )
}

rho_anthropic_sse_stream <- function(provider, model, context, options) {
  request <- rho_anthropic_messages_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  stream <- rho.http::rho_sse_connect(rho_anthropic_endpoint_http(provider), request)
  decoder <- rho_anthropic_messages_decoder(
    model,
    tool_names = rho_anthropic_tool_name_policy(options$auth),
    tools = context@tools
  )
  rho.async::rho_stream_flat_map(
    stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, AnthropicApi, AnthropicMessagesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  rho_anthropic_sse_stream(provider, model, context, options)
}
