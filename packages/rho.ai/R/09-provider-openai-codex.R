OpenAICodexApi <- S7::new_class(
  "OpenAICodexApi",
  properties = list(
    base_url = rho_non_empty_string,
    originator = rho_non_empty_string,
    http = rho.http::RhoHttpClient
  )
)

OpenAICodexOAuthAuth <- S7::new_class(
  "OpenAICodexOAuthAuth",
  parent = RhoOAuthAuth,
  properties = list(
    auth_base_url = rho_non_empty_string,
    originator = rho_non_empty_string,
    http = rho.http::RhoHttpClient
  )
)

rho_openai_codex_client_id <- "app_EMoamEEZ73f0CkXaXp7hrann"

rho_openai_codex_json_document <- function(response, operation) {
  if (is.na(response@status) || response@status < 200L || response@status >= 300L) {
    return(rho_auth_error(
      sprintf("OpenAI Codex %s failed with HTTP status %s", operation, response@status),
      code = "http",
      retryable = response@status %in% c(408L, 409L, 429L) || response@status >= 500L,
      details = list(status = response@status)
    ))
  }
  parsed <- tryCatch(
    yyjsonr::read_json_str(
      as.character(response@data),
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(parsed, "error")) {
    return(rho_auth_error(
      sprintf("OpenAI Codex %s returned invalid JSON", operation),
      code = "response_format"
    ))
  }
  parsed
}

rho_openai_codex_http_task <- function(auth, request, operation) {
  rho.async::rho_then(
    rho.http::rho_http_send(auth@http, request),
    function(response) rho_openai_codex_json_document(response, operation),
    function(error) {
      rho_auth_error(
        sprintf("OpenAI Codex %s transport failed: %s", operation, conditionMessage(error)),
        code = "transport",
        retryable = TRUE
      )
    }
  )
}

rho_openai_codex_token_request <- function(auth, fields, operation) {
  request <- rho.http::rho_http_request(
    method = "POST",
    url = paste0(auth@auth_base_url, "/oauth/token"),
    headers = list(`Content-Type` = "application/x-www-form-urlencoded"),
    body = rho_form_urlencode(fields),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho_openai_codex_http_task(auth, request, operation)
}

rho_openai_codex_credential_from_token <- function(document, source, refresh_token = NULL) {
  if (S7::S7_inherits(document, ProviderErrorValue)) {
    return(document)
  }
  access <- document$access_token
  refresh <- document$refresh_token %||% refresh_token
  expires_in <- suppressWarnings(as.double(document$expires_in))
  if (!rho_valid_oauth_token_fields(access, refresh, expires_in)) {
    return(rho_auth_error(
      "OpenAI Codex token response is missing access_token, refresh_token, or expires_in",
      code = "response_fields"
    ))
  }
  account_id <- tryCatch(rho_openai_codex_account_id(access), error = function(error) error)
  if (inherits(account_id, "error")) {
    return(rho_auth_error(conditionMessage(account_id), code = "token_claims"))
  }
  rho_openai_codex_credential(
    access_token = access,
    account_id = account_id,
    refresh_token = refresh,
    expires = as.double(Sys.time()) * 1000 + expires_in * 1000,
    source = source
  )
}

rho_openai_codex_exchange_code <- function(auth, code, verifier, redirect_uri, source = "login") {
  rho.async::rho_then(
    rho_openai_codex_token_request(
      auth,
      fields = list(
        grant_type = "authorization_code",
        client_id = rho_openai_codex_client_id,
        code = code,
        code_verifier = verifier,
        redirect_uri = redirect_uri
      ),
      operation = "authorization-code exchange"
    ),
    function(document) rho_openai_codex_credential_from_token(document, source)
  )
}

rho_openai_codex_authorization_input <- function(input, expected_state) {
  rho_authorization_code(input, expected_state, "OpenAI Codex")
}

rho_openai_codex_browser_login <- function(auth, io) {
  pkce <- rho_pkce()
  redirect_uri <- "http://localhost:1455/auth/callback"
  authorize_url <- paste0(
    auth@auth_base_url,
    "/oauth/authorize?",
    rho_form_urlencode(list(
      response_type = "code",
      client_id = rho_openai_codex_client_id,
      redirect_uri = redirect_uri,
      scope = "openid profile email offline_access",
      code_challenge = pkce$challenge,
      code_challenge_method = "S256",
      state = pkce$state,
      id_token_add_organizations = "true",
      codex_cli_simplified_flow = "true",
      originator = auth@originator
    ))
  )
  rho.async::rho_then(
    rho_auth_notify(
      io,
      RhoAuthUrlEvent(
        url = authorize_url,
        instructions = "Complete login, then paste the authorization code or redirect URL."
      )
    ),
    function(ignored) {
      rho.async::rho_then(
        rho_auth_prompt(
          io,
          RhoManualCodeAuthPrompt(
            message = "Paste the OpenAI authorization code or redirect URL:",
            placeholder = redirect_uri
          )
        ),
        function(input) {
          code <- rho_openai_codex_authorization_input(input, pkce$state)
          if (S7::S7_inherits(code, ProviderErrorValue)) {
            return(code)
          }
          rho_openai_codex_exchange_code(auth, code, pkce$verifier, redirect_uri)
        }
      )
    }
  )
}

rho_openai_codex_start_device_login <- function(auth) {
  request <- rho.http::rho_http_request(
    method = "POST",
    url = paste0(auth@auth_base_url, "/api/accounts/deviceauth/usercode"),
    headers = list(`Content-Type` = "application/json"),
    body = list(client_id = rho_openai_codex_client_id),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho_openai_codex_http_task(auth, request, "device-code start"),
    function(document) {
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      interval <- suppressWarnings(as.double(document$interval))
      if (
        !rho_non_empty_scalar_string(document$device_auth_id) ||
          !rho_non_empty_scalar_string(document$user_code) ||
          !rho_scalar_number(interval) ||
          interval < 0
      ) {
        return(rho_auth_error(
          "OpenAI Codex device-code response is missing fields",
          "response_fields"
        ))
      }
      list(
        device_auth_id = document$device_auth_id,
        user_code = document$user_code,
        interval_seconds = interval
      )
    }
  )
}

rho_openai_codex_poll_device_login <- function(auth, device) {
  interval_ms <- max(250L, as.integer(device$interval_seconds * 1000))
  rho.async::rho_poll(
    function(attempt) {
      request <- rho.http::rho_http_request(
        method = "POST",
        url = paste0(auth@auth_base_url, "/api/accounts/deviceauth/token"),
        headers = list(`Content-Type` = "application/json"),
        body = list(device_auth_id = device$device_auth_id, user_code = device$user_code),
        timeout_ms = 30000L,
        response_headers = "content-type",
        convert = TRUE
      )
      rho.async::rho_then(
        rho.http::rho_http_send(auth@http, request),
        function(response) {
          if (response@status >= 200L && response@status < 300L) {
            document <- rho_openai_codex_json_document(response, "device-code poll")
            if (S7::S7_inherits(document, ProviderErrorValue)) {
              return(rho.async::rho_poll_failed(document))
            }
            if (
              !rho_non_empty_scalar_string(document$authorization_code) ||
                !rho_non_empty_scalar_string(document$code_verifier)
            ) {
              return(rho.async::rho_poll_failed(rho_auth_error(
                "OpenAI Codex device authorization response is missing fields",
                "response_fields"
              )))
            }
            return(rho.async::rho_poll_complete(document))
          }
          if (response@status %in% c(403L, 404L)) {
            return(rho.async::rho_poll_pending(interval_ms))
          }
          document <- tryCatch(
            yyjsonr::read_json_str(
              as.character(response@data),
              arr_of_objs_to_df = FALSE,
              obj_of_arrs_to_df = FALSE
            ),
            error = function(error) list()
          )
          error_value <- document$error
          error_code <- if (is.list(error_value)) error_value$code else error_value
          if (identical(error_code, "deviceauth_authorization_pending")) {
            return(rho.async::rho_poll_pending(interval_ms))
          }
          if (identical(error_code, "slow_down")) {
            return(rho.async::rho_poll_pending(interval_ms + 5000L))
          }
          rho.async::rho_poll_failed(rho_auth_error(
            sprintf(
              "OpenAI Codex device authorization failed with HTTP status %s",
              response@status
            ),
            "device_authorization",
            details = list(status = response@status, attempt = attempt)
          ))
        },
        function(error) {
          rho.async::rho_poll_failed(rho_auth_error(
            sprintf(
              "OpenAI Codex device authorization transport failed: %s",
              conditionMessage(error)
            ),
            "transport",
            retryable = TRUE
          ))
        }
      )
    },
    timeout_ms = 15L * 60L * 1000L
  )
}

rho_openai_codex_device_login <- function(auth, io) {
  rho.async::rho_then(rho_openai_codex_start_device_login(auth), function(device) {
    if (S7::S7_inherits(device, ProviderErrorValue)) {
      return(device)
    }
    rho.async::rho_then(
      rho_auth_notify(
        io,
        RhoDeviceCodeEvent(
          user_code = device$user_code,
          verification_uri = paste0(auth@auth_base_url, "/codex/device"),
          interval_seconds = device$interval_seconds,
          expires_in_seconds = 15 * 60
        )
      ),
      function(ignored) {
        rho.async::rho_then(rho_openai_codex_poll_device_login(auth, device), function(code) {
          if (
            S7::S7_inherits(code, rho.async::RhoAsyncError) ||
              S7::S7_inherits(code, ProviderErrorValue)
          ) {
            return(code)
          }
          rho_openai_codex_exchange_code(
            auth,
            code$authorization_code,
            code$code_verifier,
            paste0(auth@auth_base_url, "/deviceauth/callback")
          )
        })
      }
    )
  })
}

rho_openai_codex_auth <- function(
  http = rho.http::rho_http_client(timeout_ms = 30000L),
  auth_base_url = "https://auth.openai.com",
  originator = "rho"
) {
  OpenAICodexOAuthAuth(
    name = "OpenAI (ChatGPT Plus/Pro)",
    auth_base_url = sub("/+$", "", auth_base_url),
    originator = originator,
    http = http
  )
}

S7::method(rho_auth_login, OpenAICodexOAuthAuth) <- function(auth, provider_id, io, ...) {
  rho.async::rho_then(
    rho_auth_prompt(
      io,
      RhoSelectAuthPrompt(
        message = "Select OpenAI Codex login method:",
        placeholder = "browser",
        options = list(
          list(id = "browser", label = "Browser login"),
          list(id = "device_code", label = "Device code login")
        )
      )
    ),
    function(method) {
      if (identical(method, "browser")) {
        return(rho_openai_codex_browser_login(auth, io))
      }
      if (identical(method, "device_code")) {
        return(rho_openai_codex_device_login(auth, io))
      }
      rho_auth_error(sprintf("Unknown OpenAI Codex login method: %s", method), "login_method")
    }
  )
}

S7::method(rho_auth_refresh, OpenAICodexOAuthAuth) <- function(auth, credential, ...) {
  if (!S7::S7_inherits(credential, RhoOAuthCredential) || !nzchar(credential@state$refresh)) {
    return(rho.async::rho_task(rho_auth_error(
      "OpenAI Codex refresh requires an OAuth credential with a refresh token",
      "credential_type"
    )))
  }
  rho.async::rho_then(
    rho_openai_codex_token_request(
      auth,
      fields = list(
        grant_type = "refresh_token",
        refresh_token = credential@state$refresh,
        client_id = rho_openai_codex_client_id
      ),
      operation = "token refresh"
    ),
    function(document) {
      rho_openai_codex_credential_from_token(
        document,
        source = credential@source,
        refresh_token = credential@state$refresh
      )
    }
  )
}

S7::method(rho_auth_to_request, OpenAICodexOAuthAuth) <- function(auth, credential, ...) {
  if (!S7::S7_inherits(credential, RhoOAuthCredential) || !nzchar(credential@state$access)) {
    return(rho.async::rho_task(rho_auth_error(
      "OpenAI Codex request auth requires an OAuth credential",
      "credential_type"
    )))
  }
  rho.async::rho_task(rho_model_auth(
    api_key = credential@state$access,
    headers = list(`chatgpt-account-id` = credential@account_id),
    metadata = list(provider = credential@provider, source = credential@source)
  ))
}

rho_decode_jwt_payload <- function(token) {
  parts <- strsplit(token, ".", fixed = TRUE)[[1L]]
  if (length(parts) != 3L) {
    rho.async::rho_signal_contract_violation("OAuth access token is not a JWT")
  }
  decoded <- rawToChar(rho_base64url_decode(parts[[2L]]))
  yyjsonr::read_json_str(decoded, arr_of_objs_to_df = FALSE, obj_of_arrs_to_df = FALSE)
}

rho_openai_codex_account_id <- function(access_token) {
  payload <- rho_decode_jwt_payload(access_token)
  account_id <- payload[["https://api.openai.com/auth"]]$chatgpt_account_id
  if (!is.character(account_id) || length(account_id) != 1L || !nzchar(account_id)) {
    rho.async::rho_signal_contract_violation(
      "OAuth token does not contain a ChatGPT account id"
    )
  }
  account_id
}

rho_openai_codex_credential <- function(
  access_token,
  account_id = NULL,
  refresh_token = "",
  expires = NA_real_,
  source = ""
) {
  account_id <- account_id %||% rho_openai_codex_account_id(access_token)
  secret_state <- new.env(parent = emptyenv())
  secret_state$access <- access_token
  secret_state$refresh <- refresh_token
  RhoOAuthCredential(
    provider = "openai-codex",
    account_id = account_id,
    expires = as.double(expires),
    source = source,
    metadata = list(),
    state = secret_state
  )
}

rho_openai_codex_credential_from_document <- function(document, source) {
  pi_credential <- document[["openai-codex"]]
  if (
    is.list(pi_credential) && is.character(pi_credential$access) && nzchar(pi_credential$access)
  ) {
    return(rho_openai_codex_credential(
      access_token = pi_credential$access,
      account_id = pi_credential$accountId,
      refresh_token = pi_credential$refresh %||% "",
      expires = pi_credential$expires %||% NA_real_,
      source = source
    ))
  }
  codex_tokens <- document$tokens
  if (
    is.list(codex_tokens) &&
      is.character(codex_tokens$access_token) &&
      nzchar(codex_tokens$access_token)
  ) {
    payload <- rho_decode_jwt_payload(codex_tokens$access_token)
    return(rho_openai_codex_credential(
      access_token = codex_tokens$access_token,
      account_id = codex_tokens$account_id,
      refresh_token = codex_tokens$refresh_token %||% "",
      expires = as.double(payload$exp %||% NA_real_) * 1000,
      source = source
    ))
  }
  rho_auth_error("The supplied file contains no OpenAI Codex credential", "credential_format")
}

rho_load_openai_codex_credential <- function(path) {
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
      rho_openai_codex_credential_from_document(document, source)
    },
    label = "openai-codex-credential-import"
  )
}

rho_openai_codex_provider <- function(
  base_url = "https://chatgpt.com/backend-api",
  originator = "rho",
  http = rho.http::rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  implementation <- OpenAICodexApi(
    base_url = base_url,
    originator = originator,
    http = http
  )
  rho_provider(
    id = "openai-codex",
    name = "OpenAI Codex",
    implementation = implementation,
    auth = rho_provider_auth(oauth = rho_openai_codex_auth(http)),
    models = rho_catalog_models(
      catalog,
      provider = "openai-codex",
      protocol = OpenAIResponsesProtocol()
    )
  )
}

rho_openai_codex_model <- function(id, catalog = rho_default_model_catalog()) {
  rho_catalog_model(
    catalog,
    "openai-codex",
    id
  )
}

rho_openai_codex_url <- function(base_url) {
  normalized <- sub("/+$", "", base_url)
  if (endsWith(normalized, "/codex/responses")) {
    return(normalized)
  }
  if (endsWith(normalized, "/codex")) {
    return(paste0(normalized, "/responses"))
  }
  paste0(normalized, "/codex/responses")
}

rho_openai_codex_websocket_url <- function(base_url) {
  endpoint <- rho_openai_codex_url(base_url)
  if (startsWith(endpoint, "https://")) {
    return(sub("^https://", "wss://", endpoint))
  }
  if (startsWith(endpoint, "http://")) {
    return(sub("^http://", "ws://", endpoint))
  }
  if (startsWith(endpoint, "ws://") || startsWith(endpoint, "wss://")) {
    return(endpoint)
  }
  NULL
}

rho_openai_codex_websocket_request_id <- function() {
  paste0("rho-", rho_base64url_encode(nanonext::random(16L, convert = FALSE)))
}

rho_openai_codex_websocket_headers <- function(headers, request_id) {
  excluded <- c("accept", "content-type", "openai-beta", "session-id", "x-client-request-id")
  retained <- headers[!tolower(names(headers)) %in% excluded]
  c(
    retained,
    list(
      `OpenAI-Beta` = "responses_websockets=2026-02-06",
      `session-id` = request_id,
      `x-client-request-id` = request_id
    )
  )
}

rho_openai_codex_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

rho_openai_codex_websocket_request <- function(provider, model, context, options = list()) {
  http_request <- rho_openai_codex_request(provider, model, context, options)
  if (S7::S7_inherits(http_request, ProviderErrorValue)) {
    return(http_request)
  }
  url <- rho_openai_codex_websocket_url(http_request@url)
  if (is.null(url)) {
    return(rho_provider_error(
      "OpenAI Codex WebSocket requires an http, https, ws, or wss endpoint",
      kind = "configuration",
      code = "codex_websocket_url",
      details = list(url = http_request@url)
    ))
  }
  request_id <- options$session_id %||% rho_openai_codex_websocket_request_id()
  payload <- tryCatch(
    yyjsonr::write_json_str(
      c(list(type = "response.create"), http_request@body),
      auto_unbox = TRUE,
      null = "null"
    ),
    error = identity
  )
  if (inherits(payload, "error")) {
    return(rho_provider_error(
      "OpenAI Codex WebSocket request could not be encoded as JSON",
      kind = "configuration",
      code = "codex_websocket_payload",
      details = list(parent = payload)
    ))
  }
  OpenAICodexWebSocketRequest(
    request = rho.http::rho_ws_request(
      url = url,
      headers = rho_openai_codex_websocket_headers(http_request@headers, request_id),
      timeout_ms = http_request@timeout_ms,
      textframes = TRUE
    ),
    message = payload
  )
}

S7::method(
  rho_provider_support,
  list(OpenAICodexApi, OpenAICodexResponsesModel, RhoToolSearchOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_tool_search
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(api = model@api, model = model@id)
  )
}

S7::method(
  rho_provider_support,
  list(OpenAICodexApi, OpenAICodexResponsesModel, RhoWebSearchOperation)
) <- function(provider, model, operation, ...) {
  capability <- model@compatibility@web_search
  rho_provider_support_value(
    S7::S7_inherits(capability, OpenAIWebSearchCapability),
    source = "openai-codex-model-profile",
    details = list(model = model@id, capability = rho_class_label(capability))
  )
}

S7::method(
  rho_bind_operation,
  list(OpenAICodexApi, OpenAICodexResponsesModel, RhoWebSearchOperation)
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
  rho_provider_support,
  list(OpenAICodexApi, OpenAICodexResponsesModel, RhoNativeCompactionOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_native_compaction
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(api = model@api, model = model@id)
  )
}

S7::method(
  rho_plan_tools,
  list(OpenAICodexApi, OpenAICodexResponsesModel, Context)
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

S7::method(
  rho_build_provider_request,
  list(OpenAICodexApi, OpenAICodexResponsesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "OpenAI Codex requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }

  placement <- options$tool_placement %||% rho_plan_tools(provider, model, context)
  if (!S7::S7_inherits(placement, RhoToolPlacement)) {
    return(rho_provider_error(
      "OpenAI Codex `tool_placement` must inherit from RhoToolPlacement",
      kind = "configuration",
      code = "openai_codex_tool_placement"
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

  request_body <- rho_openai_responses_body(model, context, placement, options)
  if (S7::S7_inherits(request_body, ProviderErrorValue)) {
    return(request_body)
  }

  headers <- utils::modifyList(
    list(
      Authorization = paste("Bearer", auth@api_key),
      originator = provider@originator,
      `User-Agent` = sprintf(
        "rho (%s %s; %s)",
        Sys.info()[["sysname"]],
        Sys.info()[["release"]],
        R.version$arch
      ),
      `OpenAI-Beta` = "responses=experimental",
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    ),
    auth@headers
  )
  session_id <- request_body$prompt_cache_key
  if (!is.null(session_id)) {
    headers$`session-id` <- session_id
    headers$`x-client-request-id` <- session_id
  }

  rho.http::rho_http_request(
    method = "POST",
    url = rho_openai_codex_url(if (nzchar(auth@base_url)) auth@base_url else provider@base_url),
    headers = headers,
    body = request_body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after", "retry-after-ms"),
    convert = TRUE
  )
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, OpenAICodexApi, OpenAICodexResponsesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_openai_codex_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  raw_stream <- rho.http::rho_sse_connect(provider@http, request)
  decoder <- rho_openai_responses_decoder(model)
  rho.async::rho_stream_flat_map(
    raw_stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}

rho_openai_codex_websocket_event <- function(value, model) {
  if (S7::S7_inherits(value, rho.http::RhoHttpError)) {
    return(value)
  }
  if (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)) {
    return(OpenAIResponseJsonEvent(data = value, transport = WebSocketTransport()))
  }
  rho_provider_error(
    "OpenAI Codex WebSocket yielded a non-text response frame",
    kind = "protocol",
    code = "codex_websocket_frame",
    details = list(value_class = rho_class_label(value), model = model@id)
  )
}

rho_openai_codex_websocket_open_stream <- function(provider, model, request) {
  opening <- rho.http::rho_ws_connect(provider@http, request@request)
  connected <- rho.async::rho_then(opening, function(socket) {
    if (S7::S7_inherits(socket, rho.http::RhoHttpError)) {
      return(rho.async::rho_list_stream(list(socket)))
    }
    rho.async::rho_then(
      rho.async::rho_duplex_send(socket, request@message),
      function(sent) {
        if (S7::S7_inherits(sent, rho.http::RhoHttpError)) {
          rho.async::rho_stream_close(socket)
          return(rho.async::rho_list_stream(list(sent)))
        }
        socket
      }
    )
  })
  rho.async::rho_stream_from_task(connected)
}

S7::method(
  rho_open_provider_transport,
  list(WebSocketTransport, OpenAICodexApi, OpenAICodexResponsesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_openai_codex_websocket_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  raw_stream <- rho_openai_codex_websocket_open_stream(provider, model, request)
  decoder <- rho_openai_responses_decoder(model)
  events <- rho.async::rho_stream_map(
    raw_stream,
    function(value) rho_openai_codex_websocket_event(value, model)
  )
  rho.async::rho_stream_flat_map(events, function(event) {
    decoded <- rho_decode_provider_event(decoder, event)
    if (
      any(vapply(
        decoded,
        function(value) {
          S7::S7_inherits(value, AssistantTerminalEvent)
        },
        logical(1)
      ))
    ) {
      rho.async::rho_stream_close(raw_stream)
    }
    decoded
  })
}
