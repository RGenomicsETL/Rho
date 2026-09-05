GitHubCopilotClientIdentity <- S7::new_class(
  "GitHubCopilotClientIdentity",
  properties = list(
    user_agent = rho_non_empty_string,
    editor_version = rho_non_empty_string,
    editor_plugin_version = rho_non_empty_string,
    integration_id = rho_non_empty_string
  )
)

GitHubCopilotEndpoints <- S7::new_class(
  "GitHubCopilotEndpoints",
  properties = list(
    device_code = rho_non_empty_string,
    access_token = rho_non_empty_string,
    copilot_token = rho_non_empty_string,
    models = rho_optional_string
  )
)

GitHubCopilotDeviceAuthorization <- S7::new_class(
  "GitHubCopilotDeviceAuthorization",
  properties = list(
    device_code = rho_non_empty_string,
    user_code = rho_non_empty_string,
    verification_uri = rho_non_empty_string,
    interval_seconds = rho_nonnegative_double,
    expires_in_seconds = rho_nonnegative_double
  ),
  validator = function(self) {
    if (self@expires_in_seconds <= 0) "@expires_in_seconds must be positive"
  }
)

GitHubCopilotCredential <- S7::new_class(
  "GitHubCopilotCredential",
  parent = RhoOAuthCredential,
  properties = list(
    github_domain = rho_non_empty_string,
    session_base_url = rho_non_empty_string,
    available_model_ids = rho_unique_non_empty_strings,
    model_catalog_complete = rho_scalar_logical
  )
)

GitHubCopilotModelAuth <- S7::new_class("GitHubCopilotModelAuth", parent = RhoModelAuth)

GitHubCopilotLoginModelPolicy <- S7::new_class(
  "GitHubCopilotLoginModelPolicy",
  abstract = TRUE
)
GitHubCopilotDiscoverModels <- S7::new_class(
  "GitHubCopilotDiscoverModels",
  parent = GitHubCopilotLoginModelPolicy
)
GitHubCopilotEnableKnownModels <- S7::new_class(
  "GitHubCopilotEnableKnownModels",
  parent = GitHubCopilotLoginModelPolicy,
  properties = list(model_ids = rho_unique_non_empty_strings)
)
GitHubCopilotModelPolicyResult <- S7::new_class(
  "GitHubCopilotModelPolicyResult",
  properties = list(
    model_id = rho_non_empty_string,
    enabled = rho_scalar_logical
  )
)

GitHubCopilotOAuthAuth <- S7::new_class(
  "GitHubCopilotOAuthAuth",
  parent = RhoOAuthAuth,
  properties = list(
    github_domain = rho_non_empty_string,
    client_id = rho_non_empty_string,
    identity = GitHubCopilotClientIdentity,
    endpoints = GitHubCopilotEndpoints,
    model_policy = GitHubCopilotLoginModelPolicy,
    http = rho.http::RhoHttpClient
  )
)

GitHubCopilotApi <- S7::new_class(
  "GitHubCopilotApi",
  properties = list(
    identity = GitHubCopilotClientIdentity,
    http = rho.http::RhoHttpClient
  )
)

GitHubCopilotAnthropicApi <- S7::new_class(
  "GitHubCopilotAnthropicApi",
  properties = list(
    provider = GitHubCopilotApi,
    version = rho_non_empty_string
  )
)

rho_github_copilot_client_identity <- function(
  user_agent = "GitHubCopilotChat/0.35.0",
  editor_version = "vscode/1.107.0",
  editor_plugin_version = "copilot-chat/0.35.0",
  integration_id = "vscode-chat"
) {
  GitHubCopilotClientIdentity(
    user_agent = user_agent,
    editor_version = editor_version,
    editor_plugin_version = editor_plugin_version,
    integration_id = integration_id
  )
}

rho_github_copilot_known_model_ids <- function(catalog = rho_default_model_catalog()) {
  models <- rho_catalog_models(catalog, provider = "github-copilot")
  unique(vapply(models, function(model) model@id, character(1)))
}

rho_github_copilot_discover_models_policy <- function() {
  GitHubCopilotDiscoverModels()
}

rho_github_copilot_enable_known_models_policy <- function(
  model_ids = rho_github_copilot_known_model_ids()
) {
  GitHubCopilotEnableKnownModels(model_ids = model_ids)
}

rho_prepare_github_copilot_models <- S7::new_generic(
  "rho_prepare_github_copilot_models",
  "policy",
  function(policy, auth, credential, io, ...) S7::S7_dispatch()
)

rho_github_copilot_domain <- function(value) {
  domain <- trimws(value)
  domain <- sub("^https?://", "", domain, ignore.case = TRUE)
  domain <- sub("/.*$", "", domain)
  valid <- nzchar(domain) &&
    grepl("^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$", domain, perl = TRUE) &&
    !grepl("..", domain, fixed = TRUE)
  if (!valid) {
    rho.async::rho_signal_contract_violation(
      "`github_domain` must be a valid hostname"
    )
  }
  tolower(domain)
}

rho_github_copilot_static_headers <- function(identity) {
  list(
    `User-Agent` = identity@user_agent,
    `Editor-Version` = identity@editor_version,
    `Editor-Plugin-Version` = identity@editor_plugin_version,
    `Copilot-Integration-Id` = identity@integration_id
  )
}

rho_github_copilot_urls <- function(domain) {
  GitHubCopilotEndpoints(
    device_code = sprintf("https://%s/login/device/code", domain),
    access_token = sprintf("https://%s/login/oauth/access_token", domain),
    copilot_token = sprintf("https://api.%s/copilot_internal/v2/token", domain),
    models = ""
  )
}

rho_github_copilot_response_document <- function(response, operation) {
  if (is.na(response@status) || response@status < 200L || response@status >= 300L) {
    return(rho_auth_error(
      sprintf("GitHub Copilot %s failed with HTTP status %s", operation, response@status),
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
      sprintf("GitHub Copilot %s returned invalid JSON", operation),
      code = "response_format"
    ))
  }
  document
}

rho_github_copilot_http_task <- function(auth, request, operation) {
  rho.async::rho_then(
    rho.http::rho_http_send(auth@http, request),
    function(response) rho_github_copilot_response_document(response, operation),
    function(error) {
      rho_auth_error(
        sprintf("GitHub Copilot %s transport failed: %s", operation, conditionMessage(error)),
        code = "transport",
        retryable = TRUE
      )
    }
  )
}

rho_github_copilot_start_device_login <- function(auth) {
  request <- rho.http::rho_http_request(
    method = "POST",
    url = auth@endpoints@device_code,
    headers = list(
      Accept = "application/json",
      `Content-Type` = "application/x-www-form-urlencoded",
      `User-Agent` = auth@identity@user_agent
    ),
    body = rho_form_urlencode(list(client_id = auth@client_id, scope = "read:user")),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho_github_copilot_http_task(auth, request, "device authorization"),
    function(document) {
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      interval <- suppressWarnings(as.double(document$interval %||% 5))
      expires <- suppressWarnings(as.double(document$expires_in))
      trusted_uri <- rho_non_empty_scalar_string(document$verification_uri) &&
        grepl("^https://[^[:space:][:cntrl:]]+$", document$verification_uri)
      valid <- rho_non_empty_scalar_string(document$device_code) &&
        rho_non_empty_scalar_string(document$user_code) &&
        trusted_uri &&
        rho_scalar_number(interval) &&
        interval >= 0 &&
        rho_scalar_number(expires) &&
        expires > 0
      if (!valid) {
        return(rho_auth_error(
          "GitHub Copilot device authorization response is missing or contains unsafe fields",
          code = "response_fields"
        ))
      }
      GitHubCopilotDeviceAuthorization(
        device_code = document$device_code,
        user_code = document$user_code,
        verification_uri = document$verification_uri,
        interval_seconds = interval,
        expires_in_seconds = expires
      )
    }
  )
}

rho_github_copilot_poll_device_login <- function(auth, device) {
  state <- new.env(parent = emptyenv())
  state$interval_ms <- max(1000L, as.integer(device@interval_seconds * 1000))
  rho.async::rho_poll(
    function(attempt) {
      request <- rho.http::rho_http_request(
        method = "POST",
        url = auth@endpoints@access_token,
        headers = list(
          Accept = "application/json",
          `Content-Type` = "application/x-www-form-urlencoded",
          `User-Agent` = auth@identity@user_agent
        ),
        body = rho_form_urlencode(list(
          client_id = auth@client_id,
          device_code = device@device_code,
          grant_type = "urn:ietf:params:oauth:grant-type:device_code"
        )),
        timeout_ms = 30000L,
        response_headers = "content-type",
        convert = TRUE
      )
      rho.async::rho_then(
        rho_github_copilot_http_task(auth, request, "device authorization poll"),
        function(document) {
          if (S7::S7_inherits(document, ProviderErrorValue)) {
            return(rho.async::rho_poll_failed(document))
          }
          access_token <- document$access_token
          if (rho_non_empty_scalar_string(access_token)) {
            return(rho.async::rho_poll_complete(access_token))
          }
          code <- as.character(document$error %||% "invalid_response")
          if (identical(code, "authorization_pending")) {
            return(rho.async::rho_poll_pending(state$interval_ms))
          }
          if (identical(code, "slow_down")) {
            state$interval_ms <- state$interval_ms + 5000L
            return(rho.async::rho_poll_pending(state$interval_ms))
          }
          rho.async::rho_poll_failed(rho_auth_error(
            sprintf("GitHub device authorization failed: %s", code),
            code = code,
            details = list(attempt = attempt)
          ))
        }
      )
    },
    timeout_ms = as.integer(device@expires_in_seconds * 1000)
  )
}

rho_github_copilot_token_field <- function(token, name) {
  fields <- strsplit(token, ";", fixed = TRUE)[[1L]]
  prefix <- paste0(name, "=")
  selected <- fields[startsWith(fields, prefix)]
  if (!length(selected)) {
    return("")
  }
  substring(selected[[1L]], nchar(prefix) + 1L)
}

rho_github_copilot_base_url <- function(token, github_domain = "github.com") {
  proxy_host <- rho_github_copilot_token_field(token, "proxy-ep")
  if (nzchar(proxy_host)) {
    valid <- grepl(
      "^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$",
      proxy_host,
      perl = TRUE
    ) &&
      !grepl("..", proxy_host, fixed = TRUE)
    if (!valid) {
      return(rho_auth_error("GitHub Copilot token contains an invalid proxy endpoint", "token"))
    }
    return(sprintf("https://%s", sub("^proxy\\.", "api.", proxy_host)))
  }
  if (!identical(github_domain, "github.com")) {
    return(sprintf("https://copilot-api.%s", github_domain))
  }
  "https://api.individual.githubcopilot.com"
}

rho_github_copilot_credential <- function(
  session_token,
  github_token,
  expires,
  github_domain = "github.com",
  session_base_url = NULL,
  available_model_ids = character(),
  model_catalog_complete = FALSE,
  source = ""
) {
  if (!rho_non_empty_scalar_string(session_token)) {
    rho.async::rho_signal_contract_violation(
      "`session_token` must be one non-empty string"
    )
  }
  if (!rho_non_empty_scalar_string(github_token)) {
    rho.async::rho_signal_contract_violation(
      "`github_token` must be one non-empty string"
    )
  }
  github_domain <- rho_github_copilot_domain(github_domain)
  session_base_url <- session_base_url %||%
    rho_github_copilot_base_url(session_token, github_domain)
  if (S7::S7_inherits(session_base_url, ProviderErrorValue)) {
    return(session_base_url)
  }
  state <- new.env(parent = emptyenv())
  state$access <- session_token
  state$refresh <- github_token
  GitHubCopilotCredential(
    provider = "github-copilot",
    account_id = "",
    expires = as.double(expires),
    source = source,
    metadata = list(),
    state = state,
    github_domain = github_domain,
    session_base_url = session_base_url,
    available_model_ids = available_model_ids,
    model_catalog_complete = model_catalog_complete
  )
}

S7::method(rho_credential_encode, GitHubCopilotCredential) <- function(credential, ...) {
  list(
    kind = "oauth",
    provider = credential@provider,
    access = credential@state$access,
    refresh = credential@state$refresh,
    expires = credential@expires,
    github_domain = credential@github_domain,
    session_base_url = credential@session_base_url,
    available_model_ids = credential@available_model_ids,
    model_catalog_complete = credential@model_catalog_complete
  )
}

S7::method(rho_credential_decode, GitHubCopilotOAuthAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  tryCatch(
    rho_github_copilot_credential(
      session_token = document$access,
      github_token = document$refresh,
      expires = as.double(document$expires %||% NA_real_),
      github_domain = document$github_domain %||% auth@github_domain,
      session_base_url = document$session_base_url,
      available_model_ids = unlist(
        document$available_model_ids %||% character(),
        use.names = FALSE
      ),
      model_catalog_complete = isTRUE(document$model_catalog_complete),
      source = source
    ),
    error = function(error) {
      rho_auth_error(conditionMessage(error), code = "credential_store_format")
    }
  )
}

rho_github_copilot_model_selectable <- function(value) {
  if (
    !is.list(value) ||
      !rho_non_empty_scalar_string(value$id)
  ) {
    return(FALSE)
  }
  picker_enabled <- identical(value$model_picker_enabled, TRUE)
  policy_enabled <- !identical(value$policy$state, "disabled")
  tool_calls <- !identical(value$capabilities$supports$tool_calls, FALSE)
  picker_enabled && policy_enabled && tool_calls
}

rho_github_copilot_model_ids <- function(document) {
  if (!is.list(document$data)) {
    return(rho_auth_error(
      "GitHub Copilot model catalog response has no data array",
      code = "response_fields"
    ))
  }
  models <- Filter(rho_github_copilot_model_selectable, document$data)
  unique(vapply(models, function(model) model$id, character(1)))
}

rho_github_copilot_discover_models <- function(auth, credential) {
  url <- if (nzchar(auth@endpoints@models)) {
    auth@endpoints@models
  } else {
    paste0(sub("/+$", "", credential@session_base_url), "/models")
  }
  request <- rho.http::rho_http_request(
    method = "GET",
    url = url,
    headers = utils::modifyList(
      list(
        Accept = "application/json",
        Authorization = paste("Bearer", credential@state$access),
        `X-GitHub-Api-Version` = "2026-06-01"
      ),
      rho_github_copilot_static_headers(auth@identity)
    ),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho_github_copilot_http_task(auth, request, "model catalog"),
    function(document) {
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      model_ids <- rho_github_copilot_model_ids(document)
      if (S7::S7_inherits(model_ids, ProviderErrorValue)) {
        return(model_ids)
      }
      rho_github_copilot_credential(
        session_token = credential@state$access,
        github_token = credential@state$refresh,
        expires = credential@expires,
        github_domain = credential@github_domain,
        session_base_url = credential@session_base_url,
        available_model_ids = model_ids,
        model_catalog_complete = TRUE,
        source = credential@source
      )
    }
  )
}

S7::method(
  rho_prepare_github_copilot_models,
  GitHubCopilotDiscoverModels
) <- function(policy, auth, credential, io, ...) {
  rho_github_copilot_discover_models(auth, credential)
}

rho_github_copilot_model_policy_task <- function(auth, credential, model_id) {
  encoded_id <- utils::URLencode(model_id, reserved = TRUE)
  request <- rho.http::rho_http_request(
    method = "POST",
    url = paste0(
      sub("/+$", "", credential@session_base_url),
      "/models/",
      encoded_id,
      "/policy"
    ),
    headers = utils::modifyList(
      list(
        Accept = "application/json",
        Authorization = paste("Bearer", credential@state$access),
        `Content-Type` = "application/json"
      ),
      rho_github_copilot_static_headers(auth@identity)
    ),
    body = list(state = "enabled"),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho.http::rho_http_send(auth@http, request),
    function(response) {
      GitHubCopilotModelPolicyResult(
        model_id = model_id,
        enabled = !is.na(response@status) && response@status >= 200L && response@status < 300L
      )
    },
    function(error) {
      GitHubCopilotModelPolicyResult(model_id = model_id, enabled = FALSE)
    }
  )
}

S7::method(
  rho_prepare_github_copilot_models,
  GitHubCopilotEnableKnownModels
) <- function(policy, auth, credential, io, ...) {
  tasks <- lapply(
    policy@model_ids,
    function(model_id) rho_github_copilot_model_policy_task(auth, credential, model_id)
  )
  rho.async::rho_then(rho.async::rho_all(tasks), function(results) {
    notifications <- lapply(results, function(result) {
      rho_auth_notify(
        io,
        RhoAuthProgressEvent(
          message = sprintf(
            "GitHub Copilot model %s: %s",
            result@model_id,
            if (result@enabled) "enabled" else "not enabled"
          )
        )
      )
    })
    rho.async::rho_then(
      rho.async::rho_all(notifications),
      function(ignored) rho_github_copilot_discover_models(auth, credential)
    )
  })
}

rho_github_copilot_exchange <- function(auth, github_token, source = "") {
  request <- rho.http::rho_http_request(
    method = "GET",
    url = auth@endpoints@copilot_token,
    headers = utils::modifyList(
      list(Accept = "application/json", Authorization = paste("Bearer", github_token)),
      rho_github_copilot_static_headers(auth@identity)
    ),
    timeout_ms = 30000L,
    response_headers = "content-type",
    convert = TRUE
  )
  rho.async::rho_then(
    rho_github_copilot_http_task(auth, request, "session-token refresh"),
    function(document) {
      if (S7::S7_inherits(document, ProviderErrorValue)) {
        return(document)
      }
      token <- document$token
      expires_at <- suppressWarnings(as.double(document$expires_at))
      valid <- is.character(token) &&
        length(token) == 1L &&
        nzchar(token) &&
        length(expires_at) == 1L &&
        !is.na(expires_at) &&
        expires_at > 0
      if (!valid) {
        return(rho_auth_error(
          "GitHub Copilot session-token response is missing token or expires_at",
          code = "response_fields"
        ))
      }
      rho_github_copilot_credential(
        session_token = token,
        github_token = github_token,
        expires = expires_at * 1000 - 5 * 60 * 1000,
        github_domain = auth@github_domain,
        source = source
      )
    }
  )
}

rho_github_copilot_refresh <- function(auth, github_token, source = "") {
  rho.async::rho_then(
    rho_github_copilot_exchange(auth, github_token, source),
    function(credential) {
      if (S7::S7_inherits(credential, ProviderErrorValue)) {
        return(credential)
      }
      rho_github_copilot_discover_models(auth, credential)
    }
  )
}

rho_github_copilot_auth <- function(
  github_domain = "github.com",
  client_id = "Iv1.b507a08c87ecfe98",
  identity = rho_github_copilot_client_identity(),
  endpoints = NULL,
  model_policy = rho_github_copilot_enable_known_models_policy(),
  http = rho.http::rho_http_client(timeout_ms = 30000L)
) {
  github_domain <- rho_github_copilot_domain(github_domain)
  endpoints <- endpoints %||% rho_github_copilot_urls(github_domain)
  GitHubCopilotOAuthAuth(
    name = "GitHub Copilot",
    github_domain = github_domain,
    client_id = client_id,
    identity = identity,
    endpoints = endpoints,
    model_policy = model_policy,
    http = http
  )
}

S7::method(rho_auth_login, GitHubCopilotOAuthAuth) <- function(auth, provider_id, io, ...) {
  rho.async::rho_then(rho_github_copilot_start_device_login(auth), function(device) {
    if (S7::S7_inherits(device, ProviderErrorValue)) {
      return(device)
    }
    rho.async::rho_then(
      rho_auth_notify(
        io,
        RhoDeviceCodeEvent(
          user_code = device@user_code,
          verification_uri = device@verification_uri,
          interval_seconds = device@interval_seconds,
          expires_in_seconds = device@expires_in_seconds
        )
      ),
      function(ignored) {
        rho.async::rho_then(
          rho_github_copilot_poll_device_login(auth, device),
          function(github_token) {
            if (
              S7::S7_inherits(github_token, ProviderErrorValue) ||
                S7::S7_inherits(github_token, rho.async::RhoAsyncError)
            ) {
              return(github_token)
            }
            rho.async::rho_then(
              rho_github_copilot_exchange(auth, github_token, source = "login"),
              function(credential) {
                if (S7::S7_inherits(credential, ProviderErrorValue)) {
                  return(credential)
                }
                rho_prepare_github_copilot_models(
                  auth@model_policy,
                  auth,
                  credential,
                  io
                )
              }
            )
          }
        )
      }
    )
  })
}

S7::method(rho_auth_refresh, GitHubCopilotOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, GitHubCopilotCredential) &&
    nzchar(credential@state$refresh)
  if (!valid) {
    return(rho.async::rho_task(rho_auth_error(
      "GitHub Copilot refresh requires a GitHubCopilotCredential",
      code = "credential_type"
    )))
  }
  rho_github_copilot_refresh(auth, credential@state$refresh, credential@source)
}

S7::method(rho_auth_to_request, GitHubCopilotOAuthAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, GitHubCopilotCredential) &&
    nzchar(credential@state$access)
  if (!valid) {
    return(rho.async::rho_task(rho_auth_error(
      "GitHub Copilot request auth requires a GitHubCopilotCredential",
      code = "credential_type"
    )))
  }
  rho.async::rho_task(GitHubCopilotModelAuth(
    api_key = credential@state$access,
    headers = list(),
    base_url = credential@session_base_url,
    metadata = list(
      provider = credential@provider,
      source = credential@source,
      github_domain = credential@github_domain
    )
  ))
}

rho_github_copilot_credential_from_github_token <- function(auth, github_token, source) {
  rho_github_copilot_refresh(auth, github_token, source)
}

rho_github_copilot_credential_from_document <- function(document, source) {
  value <- document[["github-copilot"]]
  if (!is.list(value)) {
    return(rho_auth_error(
      "The supplied file contains no GitHub Copilot credential",
      code = "credential_format"
    ))
  }
  domain <- value$enterpriseUrl %||% value$github_domain %||% "github.com"
  domain <- tryCatch(rho_github_copilot_domain(domain), error = function(error) error)
  if (inherits(domain, "error")) {
    return(rho_auth_error(conditionMessage(domain), code = "credential_format"))
  }
  tryCatch(
    rho_github_copilot_credential(
      session_token = value$access,
      github_token = value$refresh,
      expires = value$expires %||% NA_real_,
      github_domain = domain,
      available_model_ids = unlist(value$availableModelIds %||% character(), use.names = FALSE),
      model_catalog_complete = !is.null(value$availableModelIds),
      source = source
    ),
    error = function(error) {
      rho_auth_error(conditionMessage(error), code = "credential_format")
    }
  )
}

rho_load_github_copilot_credential <- function(path) {
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
      rho_github_copilot_credential_from_document(document, source)
    },
    label = "github-copilot-credential-import"
  )
}

rho_message_initiator <- S7::new_generic(
  "rho_message_initiator",
  "message",
  function(message, ...) S7::S7_dispatch()
)

S7::method(rho_message_initiator, UserMessage) <- function(message, ...) "user"
S7::method(rho_message_initiator, S7::class_any) <- function(message, ...) "agent"

rho_has_image_input <- S7::new_generic(
  "rho_has_image_input",
  "value",
  function(value, ...) S7::S7_dispatch()
)

S7::method(rho_has_image_input, ImageContent) <- function(value, ...) TRUE
S7::method(rho_has_image_input, UserMessage) <- function(value, ...) {
  rho_has_image_input(value@content)
}
S7::method(rho_has_image_input, ToolResultMessage) <- function(value, ...) {
  rho_has_image_input(value@content)
}
S7::method(rho_has_image_input, S7::class_list) <- function(value, ...) {
  any(vapply(value, rho_has_image_input, logical(1)))
}
S7::method(rho_has_image_input, S7::class_any) <- function(value, ...) FALSE

S7::method(
  rho_provider_headers,
  list(GitHubCopilotApi, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  last_message <- if (length(context@messages)) {
    context@messages[[length(context@messages)]]
  } else {
    NULL
  }
  initiator <- if (is.null(last_message)) "user" else rho_message_initiator(last_message)
  headers <- utils::modifyList(
    rho_github_copilot_static_headers(provider@identity),
    model@headers
  )
  headers <- utils::modifyList(
    headers,
    list(
      `X-Initiator` = initiator,
      `Openai-Intent` = "conversation-edits"
    )
  )
  if (rho_has_image_input(context@messages)) {
    headers$`Copilot-Vision-Request` <- "true"
  }
  utils::modifyList(headers, options$headers %||% list())
}

rho_github_copilot_model <- function(id, catalog = rho_default_model_catalog()) {
  rho_catalog_model(
    catalog,
    "github-copilot",
    id
  )
}

S7::method(
  rho_provider_models,
  list(RhoProvider, GitHubCopilotCredential)
) <- function(provider, credential, ...) {
  if (!identical(provider@id, "github-copilot") || !credential@model_catalog_complete) {
    return(provider@models)
  }
  Filter(
    function(model) model@id %in% credential@available_model_ids,
    provider@models
  )
}

S7::method(
  rho_provider_dialect,
  list(GitHubCopilotApi, AnthropicMessagesModel)
) <- function(provider, model, ...) {
  GitHubCopilotAnthropicApi(provider = provider, version = "2023-06-01")
}

S7::method(
  rho_provider_headers,
  list(GitHubCopilotAnthropicApi, AnthropicMessagesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_provider_headers(provider@provider, model, context, options = options)
}

S7::method(
  rho_anthropic_endpoint_url,
  GitHubCopilotAnthropicApi
) <- function(provider, model, auth, ...) {
  base_url <- if (nzchar(auth@base_url)) auth@base_url else model@base_url
  rho_anthropic_messages_url(base_url)
}

S7::method(
  rho_anthropic_endpoint_headers,
  GitHubCopilotAnthropicApi
) <- function(
  provider,
  model,
  context,
  auth,
  beta_features,
  options = list(),
  ...
) {
  headers <- list(
    Authorization = paste("Bearer", auth@api_key),
    `anthropic-version` = provider@version,
    Accept = "text/event-stream",
    `Content-Type` = "application/json"
  )
  if (length(beta_features)) {
    headers$`anthropic-beta` <- paste(
      vapply(beta_features, rho_anthropic_beta_name, character(1)),
      collapse = ","
    )
  }
  headers <- utils::modifyList(
    headers,
    rho_provider_headers(provider, model, context, options = options)
  )
  utils::modifyList(headers, auth@headers)
}

S7::method(
  rho_anthropic_endpoint_http,
  GitHubCopilotAnthropicApi
) <- function(provider, ...) {
  provider@provider@http
}

S7::method(
  rho_build_provider_request,
  list(GitHubCopilotAnthropicApi, AnthropicMessagesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_anthropic_build_request(provider, model, context, options)
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, GitHubCopilotAnthropicApi, AnthropicMessagesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  rho_anthropic_sse_stream(provider, model, context, options)
}

rho_github_copilot_provider <- function(
  github_domain = "github.com",
  identity = rho_github_copilot_client_identity(),
  http = rho.http::rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  api <- GitHubCopilotApi(identity = identity, http = http)
  rho_provider(
    id = "github-copilot",
    name = "GitHub Copilot",
    implementation = api,
    auth = rho_provider_auth(
      oauth = rho_github_copilot_auth(
        github_domain = github_domain,
        identity = identity,
        http = http
      )
    ),
    models = Filter(
      function(model) {
        S7::S7_inherits(model, GitHubCopilotResponsesModel) ||
          S7::S7_inherits(model, AnthropicMessagesModel)
      },
      rho_catalog_models(catalog, provider = "github-copilot")
    )
  )
}

rho_github_copilot_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

S7::method(
  rho_provider_support,
  list(GitHubCopilotApi, GitHubCopilotResponsesModel, RhoToolSearchOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_tool_search
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(provider = model@provider, model = model@id)
  )
}

S7::method(
  rho_provider_support,
  list(GitHubCopilotApi, GitHubCopilotResponsesModel, RhoNativeCompactionOperation)
) <- function(provider, model, operation, ...) {
  compatibility <- model@compatibility
  supported <- S7::S7_inherits(compatibility, OpenAIResponsesCompatibility) &&
    compatibility@supports_native_compaction
  rho_provider_support_value(
    supported,
    source = "openai-responses-compatibility",
    details = list(provider = model@provider, model = model@id)
  )
}

S7::method(
  rho_build_provider_request,
  list(GitHubCopilotApi, GitHubCopilotResponsesModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "GitHub Copilot requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }
  placement <- options$tool_placement %||% rho_plan_tools(provider, model, context)
  if (!S7::S7_inherits(placement, RhoToolPlacement)) {
    return(rho_provider_error(
      "GitHub Copilot `tool_placement` must inherit from RhoToolPlacement",
      kind = "configuration",
      code = "github_copilot_tool_placement"
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
  base_url <- if (nzchar(auth@base_url)) auth@base_url else model@base_url
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
  rho.http::rho_http_request(
    method = "POST",
    url = paste0(sub("/+$", "", base_url), "/responses"),
    headers = headers,
    body = body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after", "retry-after-ms"),
    convert = TRUE
  )
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, GitHubCopilotApi, GitHubCopilotResponsesModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_github_copilot_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  stream <- rho.http::rho_sse_connect(provider@http, request)
  decoder <- rho_openai_responses_decoder(model)
  rho.async::rho_stream_flat_map(
    stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}
