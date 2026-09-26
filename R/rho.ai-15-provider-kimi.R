rho_kimi_code_header_values <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    if (!length(value)) {
      return()
    }
    header_names <- names(value)
    if (is.null(header_names) || anyNA(header_names) || any(!nzchar(header_names))) {
      return("must have non-empty names")
    }
    valid <- vapply(
      value,
      function(header) {
        is.character(header) && length(header) == 1L && !is.na(header)
      },
      logical(1)
    )
    if (!all(valid)) {
      "must contain one non-missing string for each header"
    }
  }
)

KimiCodeIdentity <- S7::new_class(
  "KimiCodeIdentity",
  properties = list(
    user_agent = rho_non_empty_string,
    device_headers = rho_kimi_code_header_values
  )
)

KimiCodeApi <- S7::new_class(
  "KimiCodeApi",
  parent = AnthropicApi,
  properties = list(identity = KimiCodeIdentity)
)

KimiCodeApiKeyAuth <- S7::new_class(
  "KimiCodeApiKeyAuth",
  properties = list(
    name = rho_non_empty_string,
    provider_id = rho_non_empty_string
  )
)

KimiCodeOAuthAuth <- S7::new_class(
  "KimiCodeOAuthAuth",
  parent = RhoOAuthAuth,
  properties = list(
    oauth_host = rho_non_empty_string,
    client_id = rho_non_empty_string,
    identity = KimiCodeIdentity,
    http = RhoHttpClient
  )
)

KimiCodeOAuthCredential <- S7::new_class(
  "KimiCodeOAuthCredential",
  parent = RhoOAuthCredential
)

KimiCodeModelAuth <- S7::new_class(
  "KimiCodeModelAuth",
  parent = RhoModelAuth
)

KimiCodeDeviceAuthorization <- S7::new_class(
  "KimiCodeDeviceAuthorization",
  properties = list(
    user_code = rho_non_empty_string,
    device_code = rho_non_empty_string,
    verification_uri = rho_optional_string,
    verification_uri_complete = rho_non_empty_string,
    expires_in_seconds = rho_nonnegative_double,
    interval_seconds = rho_nonnegative_double
  ),
  validator = function(self) {
    if (self@expires_in_seconds <= 0) {
      return("@expires_in_seconds must be positive")
    }
    if (self@interval_seconds <= 0) {
      "@interval_seconds must be positive"
    }
  }
)

KimiCodeToken <- S7::new_class(
  "KimiCodeToken",
  properties = list(
    access_token = rho_non_empty_string,
    refresh_token = rho_non_empty_string,
    expires_in_seconds = rho_nonnegative_double,
    scope = rho_optional_string,
    token_type = rho_non_empty_string
  ),
  validator = function(self) {
    if (self@expires_in_seconds <= 0) {
      "@expires_in_seconds must be positive"
    }
  }
)

rho_kimi_code_identity_headers <- S7::new_generic(
  "rho_kimi_code_identity_headers",
  "identity",
  function(identity, ...) S7::S7_dispatch()
)

S7::method(rho_kimi_code_identity_headers, KimiCodeIdentity) <- function(identity, ...) {
  utils::modifyList(
    list(`User-Agent` = identity@user_agent),
    identity@device_headers
  )
}

rho_kimi_code_identity <- function(
  user_agent = paste0("Rho/", utils::packageVersion("rho")),
  device_headers = list()
) {
  KimiCodeIdentity(
    user_agent = user_agent,
    device_headers = device_headers
  )
}

rho_kimi_code_oauth_auth <- function(
  identity = rho_kimi_code_identity(),
  oauth_host = "https://auth.kimi.com",
  client_id = "17e5f671-d194-4dfb-9706-5516cb48c098",
  http = rho_http_client(timeout_ms = 30000L)
) {
  KimiCodeOAuthAuth(
    name = "Kimi Code subscription",
    oauth_host = sub("/+$", "", oauth_host),
    client_id = client_id,
    identity = identity,
    http = http
  )
}

rho_kimi_code_model <- function(id, catalog = rho_default_model_catalog()) {
  rho_catalog_model(catalog, "kimi-coding", id)
}

rho_kimi_code_provider <- function(
  identity = rho_kimi_code_identity(),
  base_url = "https://api.kimi.com/coding",
  oauth_host = "https://auth.kimi.com",
  http = rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  api <- KimiCodeApi(
    base_url = sub("/+$", "", base_url),
    version = "2023-06-01",
    http = http,
    identity = identity
  )
  rho_provider(
    id = "kimi-coding",
    name = "Kimi Code",
    implementation = api,
    auth = rho_provider_auth(
      api_key = KimiCodeApiKeyAuth(
        name = "Kimi Code subscription",
        provider_id = "kimi-coding"
      ),
      oauth = rho_kimi_code_oauth_auth(
        identity = identity,
        oauth_host = oauth_host,
        http = http
      )
    ),
    models = rho_catalog_models(
      catalog,
      provider = "kimi-coding",
      protocol = AnthropicMessagesProtocol()
    )
  )
}

rho_kimi_code_request_headers <- function(identity) {
  rho_kimi_code_identity_headers(identity)
}

S7::method(
  rho_provider_headers,
  list(KimiCodeApi, AnthropicMessagesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  headers <- utils::modifyList(
    model@headers,
    rho_kimi_code_request_headers(provider@identity)
  )
  utils::modifyList(headers, options$headers %||% list())
}

S7::method(rho_anthropic_auth_headers, KimiCodeModelAuth) <- function(
  auth,
  beta_features,
  ...
) {
  headers <- list(Authorization = paste("Bearer", auth@api_key))
  if (length(beta_features)) {
    headers$`anthropic-beta` <- paste(
      vapply(beta_features, rho_anthropic_beta_name, character(1)),
      collapse = ","
    )
  }
  headers
}

S7::method(rho_auth_login, KimiCodeApiKeyAuth) <- function(auth, provider_id, io, ...) {
  rho_then(
    rho_auth_prompt(
      io,
      RhoSecretAuthPrompt(
        message = "Enter the Kimi Code subscription API key:",
        placeholder = ""
      )
    ),
    function(key) {
      if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
        return(rho_auth_error("Kimi Code API key was not supplied", code = "missing"))
      }
      rho_api_key_credential(auth@provider_id, key, source = "login")
    }
  )
}

S7::method(rho_auth_to_request, KimiCodeApiKeyAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, RhoApiKeyCredential) &&
    identical(credential@provider, auth@provider_id) &&
    nzchar(credential@state$key)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "Kimi Code request auth requires a matching API-key credential",
      code = "credential_type"
    )))
  }
  rho_task(KimiCodeModelAuth(
    api_key = credential@state$key,
    headers = list(),
    base_url = "",
    metadata = list(
      provider = credential@provider,
      source = credential@source,
      subscription = TRUE,
      credential_kind = "api_key"
    )
  ))
}

S7::method(rho_credential_decode, KimiCodeApiKeyAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  rho_decode_api_key_credential(document, provider_id, source)
}

rho_kimi_code_response_document <- function(response, operation) {
  if (is.list(response@data)) {
    return(response@data)
  }
  text <- if (is.raw(response@data)) {
    rawToChar(response@data)
  } else {
    as.character(response@data)
  }
  if (!length(text) || !nzchar(text)) {
    return(list())
  }
  document <- tryCatch(
    yyjsonr::read_json_str(
      text,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) error
  )
  if (inherits(document, "error") || !is.list(document)) {
    return(rho_auth_error(
      sprintf("Kimi Code OAuth %s returned invalid JSON", operation),
      code = "response_format"
    ))
  }
  document
}

rho_kimi_code_oauth_call <- function(auth, path, fields, operation) {
  request <- rho_http_request(
    method = "POST",
    url = paste0(auth@oauth_host, path),
    headers = utils::modifyList(
      rho_kimi_code_identity_headers(auth@identity),
      list(
        Accept = "application/json",
        `Content-Type` = "application/x-www-form-urlencoded"
      )
    ),
    body = rho_form_urlencode(fields),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho_then(
    rho_http_send(auth@http, request),
    function(response) {
      document <- rho_kimi_code_response_document(response, operation)
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      list(status = response@status, document = document)
    },
    function(error) {
      rho_auth_error(
        sprintf("Kimi Code OAuth %s transport failed: %s", operation, conditionMessage(error)),
        code = "transport",
        retryable = TRUE
      )
    }
  )
}

rho_kimi_code_error_detail <- function(document) {
  error_value <- document$error
  nested_message <- if (is.list(error_value)) error_value$message else NULL
  candidates <- list(
    document$error_description,
    document$message,
    nested_message,
    error_value
  )
  for (candidate in candidates) {
    if (
      is.character(candidate) &&
        length(candidate) == 1L &&
        !is.na(candidate) &&
        nzchar(candidate)
    ) {
      return(candidate)
    }
  }
  "unknown error"
}

rho_kimi_code_device_authorization <- function(auth) {
  rho_then(
    rho_kimi_code_oauth_call(
      auth,
      "/api/oauth/device_authorization",
      list(client_id = auth@client_id),
      "device authorization"
    ),
    function(result) {
      if (S7::S7_inherits(result, ProviderErrorValue)) {
        return(result)
      }
      if (!identical(result$status, 200L)) {
        return(rho_auth_error(
          sprintf(
            "Kimi Code device authorization failed with HTTP status %s: %s",
            result$status,
            rho_kimi_code_error_detail(result$document)
          ),
          code = "device_authorization",
          retryable = result$status == 429L || result$status >= 500L,
          details = list(status = result$status)
        ))
      }
      tryCatch(
        KimiCodeDeviceAuthorization(
          user_code = result$document$user_code,
          device_code = result$document$device_code,
          verification_uri = result$document$verification_uri %||% "",
          verification_uri_complete = result$document$verification_uri_complete,
          expires_in_seconds = suppressWarnings(as.double(
            result$document$expires_in %||% 600
          )),
          interval_seconds = suppressWarnings(as.double(
            result$document$interval %||% 5
          ))
        ),
        error = function(error) {
          rho_auth_error(
            sprintf("Invalid Kimi Code device authorization response: %s", conditionMessage(error)),
            code = "response_format"
          )
        }
      )
    }
  )
}

rho_kimi_code_token <- function(document) {
  tryCatch(
    KimiCodeToken(
      access_token = document$access_token,
      refresh_token = document$refresh_token,
      expires_in_seconds = suppressWarnings(as.double(document$expires_in)),
      scope = document$scope %||% "",
      token_type = document$token_type %||% "Bearer"
    ),
    error = function(error) {
      rho_auth_error(
        sprintf("Invalid Kimi Code OAuth token response: %s", conditionMessage(error)),
        code = "response_format"
      )
    }
  )
}

rho_kimi_code_oauth_credential <- function(token, source) {
  state <- new.env(parent = emptyenv())
  state$access <- token@access_token
  state$refresh <- token@refresh_token
  refresh_lead_seconds <- min(60, token@expires_in_seconds / 10)
  KimiCodeOAuthCredential(
    provider = "kimi-coding",
    source = source,
    account_id = "",
    expires = (as.double(Sys.time()) + token@expires_in_seconds - refresh_lead_seconds) * 1000,
    metadata = list(
      subscription = TRUE,
      scope = token@scope,
      token_type = token@token_type
    ),
    state = state
  )
}

rho_kimi_code_poll_device <- function(auth, device) {
  state <- new.env(parent = emptyenv())
  state$interval_ms <- as.integer(device@interval_seconds * 1000)
  polling <- rho_poll(
    function(attempt) {
      rho_then(
        rho_kimi_code_oauth_call(
          auth,
          "/api/oauth/token",
          list(
            client_id = auth@client_id,
            device_code = device@device_code,
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
          ),
          "device token polling"
        ),
        function(result) {
          if (S7::S7_inherits(result, ProviderErrorValue)) {
            return(rho_poll_failed(result))
          }
          if (identical(result$status, 200L)) {
            token <- rho_kimi_code_token(result$document)
            if (S7::S7_inherits(token, ProviderErrorValue)) {
              return(rho_poll_failed(token))
            }
            return(rho_poll_complete(
              rho_kimi_code_oauth_credential(token, "device_login")
            ))
          }
          error_code <- result$document$error %||% "unknown_error"
          if (identical(error_code, "authorization_pending")) {
            return(rho_poll_pending(state$interval_ms))
          }
          if (identical(error_code, "slow_down")) {
            state$interval_ms <- state$interval_ms + 5000L
            return(rho_poll_pending(state$interval_ms))
          }
          if (identical(error_code, "expired_token")) {
            return(rho_poll_failed(rho_auth_error(
              "Kimi Code device authorization expired",
              code = "expired"
            )))
          }
          if (identical(error_code, "access_denied")) {
            return(rho_poll_failed(rho_auth_error(
              sprintf(
                "Kimi Code device authorization was denied: %s",
                rho_kimi_code_error_detail(result$document)
              ),
              code = "denied"
            )))
          }
          rho_poll_failed(rho_auth_error(
            sprintf(
              "Kimi Code device token polling failed with HTTP status %s: %s",
              result$status,
              rho_kimi_code_error_detail(result$document)
            ),
            code = "device_authorization",
            retryable = result$status == 429L || result$status >= 500L,
            details = list(status = result$status, error = error_code)
          ))
        }
      )
    },
    timeout_ms = as.integer(device@expires_in_seconds * 1000)
  )
  rho_then(polling, function(result) {
    if (S7::S7_inherits(result, RhoTimeoutError)) {
      return(rho_auth_error(
        "Kimi Code device authorization expired while waiting for approval",
        code = "expired"
      ))
    }
    result
  })
}

S7::method(rho_auth_login, KimiCodeOAuthAuth) <- function(auth, provider_id, io, ...) {
  rho_then(rho_kimi_code_device_authorization(auth), function(device) {
    if (S7::S7_inherits(device, ProviderErrorValue)) {
      return(device)
    }
    verification_uri <- if (nzchar(device@verification_uri)) {
      device@verification_uri
    } else {
      device@verification_uri_complete
    }
    rho_then(
      rho_auth_notify(
        io,
        RhoDeviceCodeEvent(
          user_code = device@user_code,
          verification_uri = verification_uri,
          verification_uri_complete = device@verification_uri_complete,
          interval_seconds = device@interval_seconds,
          expires_in_seconds = device@expires_in_seconds
        )
      ),
      function(notified) rho_kimi_code_poll_device(auth, device)
    )
  })
}

S7::method(rho_auth_refresh, KimiCodeOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, KimiCodeOAuthCredential) &&
    identical(credential@provider, "kimi-coding") &&
    nzchar(credential@state$refresh)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "Kimi Code refresh requires a matching OAuth credential",
      code = "credential_type"
    )))
  }
  rho_then(
    rho_kimi_code_oauth_call(
      auth,
      "/api/oauth/token",
      list(
        client_id = auth@client_id,
        grant_type = "refresh_token",
        refresh_token = credential@state$refresh
      ),
      "token refresh"
    ),
    function(result) {
      if (S7::S7_inherits(result, ProviderErrorValue)) {
        return(result)
      }
      if (!identical(result$status, 200L)) {
        error_code <- result$document$error %||% ""
        unauthorized <- result$status %in% c(401L, 403L) || identical(error_code, "invalid_grant")
        return(rho_auth_error(
          sprintf(
            "Kimi Code token refresh failed with HTTP status %s: %s",
            result$status,
            rho_kimi_code_error_detail(result$document)
          ),
          code = if (unauthorized) "unauthorized" else "refresh",
          retryable = !unauthorized && (result$status == 429L || result$status >= 500L),
          details = list(status = result$status, error = error_code)
        ))
      }
      token <- rho_kimi_code_token(result$document)
      if (S7::S7_inherits(token, ProviderErrorValue)) {
        return(token)
      }
      rho_kimi_code_oauth_credential(token, credential@source)
    }
  )
}

S7::method(rho_auth_to_request, KimiCodeOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, KimiCodeOAuthCredential) &&
    identical(credential@provider, "kimi-coding") &&
    nzchar(credential@state$access)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "Kimi Code request auth requires a matching OAuth credential",
      code = "credential_type"
    )))
  }
  rho_task(KimiCodeModelAuth(
    api_key = credential@state$access,
    headers = list(),
    base_url = "",
    metadata = list(
      provider = credential@provider,
      source = credential@source,
      subscription = TRUE,
      credential_kind = "oauth"
    )
  ))
}

S7::method(rho_credential_decode, KimiCodeOAuthAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  tryCatch(
    {
      state <- new.env(parent = emptyenv())
      state$access <- document$access
      state$refresh <- document$refresh
      KimiCodeOAuthCredential(
        provider = provider_id,
        source = source,
        account_id = document$account_id %||% "",
        expires = as.double(document$expires),
        metadata = document$metadata %||% list(subscription = TRUE),
        state = state
      )
    },
    error = function(error) {
      rho_auth_error(conditionMessage(error), code = "credential_store_format")
    }
  )
}
