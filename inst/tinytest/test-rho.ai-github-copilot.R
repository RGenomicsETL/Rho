# Generated from inst/tinytest/rmd/rho.ai-github-copilot.Rmd; do not edit.

library(tinytest)
library(rho)

provider <- rho_github_copilot_provider()
model <- rho_github_copilot_model("gpt-5.3-codex")
credential <- rho_github_copilot_credential(
  session_token = paste0(
    "tid=test;exp=9999999999;",
    "proxy-ep=proxy.individual.githubcopilot.com;"
  ),
  github_token = "github-test-token",
  expires = Inf,
  source = "fixture"
)
auth <- rho_auth_to_request(provider@auth@oauth, credential) |> rho_await()
context <- rho_context(messages = list(rho_user_message("hello")))
request <- rho_github_copilot_request(
  provider@implementation,
  model,
  context,
  options = list(auth = auth)
)

expect_true(S7::S7_inherits(model, OpenAIResponsesModel))
expect_true(S7::S7_inherits(credential, GitHubCopilotCredential))
expect_true(S7::S7_inherits(auth, GitHubCopilotModelAuth))
expect_equal(request@url, "https://api.individual.githubcopilot.com/responses")
expect_equal(request@headers$Authorization, paste("Bearer", credential@state$access))
expect_equal(request@headers$`X-Initiator`, "user")
expect_equal(request@headers$`Openai-Intent`, "conversation-edits")
expect_equal(request@headers$`Copilot-Integration-Id`, "vscode-chat")
expect_equal(request@body$model, "gpt-5.3-codex")
expect_true(s7contract::implements(GitHubCopilotOAuthAuth, OAuthAuth))
expect_true(s7contract::implements(GitHubCopilotApi, ProviderRequestTranslator))

unsupported_operation <- rho_github_copilot_request(
  provider@implementation,
  model,
  rho_context(
    messages = list(rho_user_message("search")),
    operations = list(rho_web_search())
  ),
  options = list(auth = auth)
)
expect_true(S7::S7_inherits(unsupported_operation, OperationUnsupported))

anthropic_model <- rho_github_copilot_model("claude-fable-5")
anthropic_provider <- rho_provider_dialect(
  provider@implementation,
  anthropic_model
)
selection <- rho_select_provider_transport(
  anthropic_provider,
  anthropic_model,
  AutomaticTransport()
)

expect_true(S7::S7_inherits(anthropic_provider, GitHubCopilotAnthropicApi))
expect_true(S7::S7_inherits(selection, ProviderTransportSelection))
expect_true(S7::S7_inherits(selection@transport, SseTransport))

missing_auth <- rho_stream(
  anthropic_provider,
  anthropic_model,
  context
) |>
  rho_stream_collect(timeout = 1000L)
expect_equal(length(missing_auth), 1L)
expect_true(S7::S7_inherits(missing_auth[[1L]], AssistantErrorEvent))
expect_equal(missing_auth[[1L]]@error@code, "missing_request_auth")

mini <- rho_github_copilot_model("gpt-5-mini")
image_context <- rho_context(messages = list(rho_user_message(list(
  rho_text("What is shown?"),
  ImageContent(data = "iVBORw0KGgo=", mime_type = "image/png")
))))
image_request <- rho_github_copilot_request(
  provider@implementation,
  mini,
  image_context,
  options = list(auth = auth)
)

expect_true(rho_model_supports_input(mini, "image"))
expect_equal(image_request@headers$`Copilot-Vision-Request`, "true")
expect_equal(image_request@body$input[[1L]]$content, list(
  list(type = "input_text", text = "What is shown?"),
  list(
    type = "input_image",
    detail = "auto",
    image_url = "data:image/png;base64,iVBORw0KGgo="
  )
))

image <- ImageContent(data = "base64", mime_type = "image/png")
image_context <- rho_context(messages = list(
  rho_user_message(list(image)),
  rho_assistant_message(content = list(rho_text("working")))
))
headers <- rho_provider_headers(
  provider@implementation,
  model,
  image_context
)

expect_equal(headers$`X-Initiator`, "agent")
expect_equal(headers$`Copilot-Vision-Request`, "true")
expect_true(rho_has_image_input(image_context@messages))
expect_equal(rho_message_initiator(image_context@messages[[1L]]), "user")
expect_equal(rho_message_initiator(image_context@messages[[2L]]), "agent")

received_headers <- NULL
received_model_headers <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(
    nanonext::handler(
      "/copilot-token",
      function(request) {
        received_headers <<- request$headers
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(
            token = paste0(
              "tid=test;exp=9999999999;",
              "proxy-ep=proxy.individual.githubcopilot.com;"
            ),
            expires_at = 9999999999
          ), auto_unbox = TRUE)
        )
      }
    ),
    nanonext::handler(
      "/models",
      function(request) {
        received_model_headers <<- request$headers
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(data = list(
            list(
              id = "gpt-5.3-codex",
              model_picker_enabled = TRUE,
              capabilities = list(supports = list(tool_calls = TRUE))
            ),
            list(
              id = "disabled-model",
              model_picker_enabled = TRUE,
              policy = list(state = "disabled")
            ),
            list(id = "hidden-model", model_picker_enabled = FALSE)
          )), auto_unbox = TRUE)
        )
      }
    )
  )
)
expect_equal(server$start(), 0L)

endpoints <- GitHubCopilotEndpoints(
  device_code = paste0(server$url, "/unused-device"),
  access_token = paste0(server$url, "/unused-access"),
  copilot_token = paste0(server$url, "/copilot-token"),
  models = paste0(server$url, "/models")
)
strategy <- rho_github_copilot_auth(
  endpoints = endpoints,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
refreshed <- rho_github_copilot_credential_from_github_token(
  strategy,
  "github-test-token",
  source = "explicit-test"
) |> rho_await(timeout = 2000L)

expect_true(S7::S7_inherits(refreshed, GitHubCopilotCredential))
expect_equal(refreshed@source, "explicit-test")
expect_equal(refreshed@session_base_url, "https://api.individual.githubcopilot.com")
expect_true(refreshed@model_catalog_complete)
expect_equal(refreshed@available_model_ids, "gpt-5.3-codex")
expect_equal(received_headers[["Authorization"]], "Bearer github-test-token")
expect_equal(
  received_model_headers[["Authorization"]],
  paste("Bearer", refreshed@state$access)
)
expect_equal(received_model_headers[["X-GitHub-Api-Version"]], "2026-06-01")
expect_true(grepl("GitHubCopilotChat", received_headers[["User-Agent"]]))

account_models <- rho_models(
  list(provider),
  rho_memory_credential_store(list(`github-copilot` = refreshed))
)
available <- rho_available_models(account_models, "github-copilot") |>
  rho_await(timeout = 2000L)
expect_equal(
  vapply(available, function(model) model@id, character(1)),
  "gpt-5.3-codex"
)
expect_equal(server$close(), 0L)

poll_count <- 0L
notified <- list()
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(
    nanonext::handler(
      "/device",
      function(request) {
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(
            device_code = "device-code",
            user_code = "ABCD-EFGH",
            verification_uri = "https://github.com/login/device",
            interval = 0,
            expires_in = 30
          ), auto_unbox = TRUE)
        )
      },
      method = "POST"
    ),
    nanonext::handler(
      "/access",
      function(request) {
        poll_count <<- poll_count + 1L
        body <- if (poll_count == 1L) {
          list(error = "authorization_pending")
        } else {
          list(access_token = "github-device-token")
        }
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(body, auto_unbox = TRUE)
        )
      },
      method = "POST"
    ),
    nanonext::handler(
      "/token",
      function(request) {
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(
            token = paste0(
              "tid=test;exp=9999999999;",
              "proxy-ep=proxy.individual.githubcopilot.com;"
            ),
            expires_at = 9999999999
          ), auto_unbox = TRUE)
        )
      }
    ),
    nanonext::handler(
      "/models",
      function(request) {
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(data = list(
            list(
              id = "gpt-5.3-codex",
              model_picker_enabled = TRUE,
              capabilities = list(supports = list(tool_calls = TRUE))
            )
          )), auto_unbox = TRUE)
        )
      }
    )
  )
)
expect_equal(server$start(), 0L)

strategy <- rho_github_copilot_auth(
  endpoints = GitHubCopilotEndpoints(
    device_code = paste0(server$url, "/device"),
    access_token = paste0(server$url, "/access"),
    copilot_token = paste0(server$url, "/token"),
    models = paste0(server$url, "/models")
  ),
  model_policy = rho_github_copilot_discover_models_policy(),
  http = rho::rho_http_client(timeout_ms = 2000L)
)
io <- rho_login_io(
  prompt = function(prompt) stop("GitHub device login must not prompt for a secret"),
  notify = function(event) {
    notified[[length(notified) + 1L]] <<- event
    NULL
  }
)
credential_path <- tempfile("rho-copilot-credentials-", fileext = ".json")
login_provider <- rho_provider(
  id = "github-copilot",
  implementation = GitHubCopilotApi(
    identity = strategy@identity,
    http = strategy@http
  ),
  auth = rho_provider_auth(oauth = strategy),
  models = list()
)
models <- rho_models(
  list(login_provider),
  rho_file_credential_store(credential_path, list(login_provider))
)
logged_in <- rho_login_provider(models, "github-copilot", io) |>
  rho_await(timeout = 5000L)

expect_true(S7::S7_inherits(logged_in, GitHubCopilotCredential))
expect_true(logged_in@model_catalog_complete)
expect_equal(logged_in@available_model_ids, "gpt-5.3-codex")
expect_equal(poll_count, 2L)
expect_equal(length(notified), 1L)
expect_true(S7::S7_inherits(notified[[1L]], RhoDeviceCodeEvent))
expect_equal(notified[[1L]]@user_code, "ABCD-EFGH")

reopened <- rho_file_credential_store(credential_path, list(login_provider))
persisted <- rho_credential_read(reopened, "github-copilot") |>
  rho_await(timeout = 1000L)
expect_true(S7::S7_inherits(persisted, GitHubCopilotCredential))
expect_equal(persisted@state$refresh, "github-device-token")
expect_equal(persisted@state$access, logged_in@state$access)
expect_equal(persisted@available_model_ids, "gpt-5.3-codex")

unlink(credential_path)
expect_equal(server$close(), 0L)

policy_requests <- character()
policy_notifications <- character()
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(
    nanonext::handler(
      "/models/model-a/policy",
      function(request) {
        policy_requests <<- c(policy_requests, "model-a")
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = "{}"
        )
      },
      method = "POST"
    ),
    nanonext::handler(
      "/models/model-b/policy",
      function(request) {
        policy_requests <<- c(policy_requests, "model-b")
        list(
          status = 403L,
          headers = c("Content-Type" = "application/json"),
          body = "{}"
        )
      },
      method = "POST"
    ),
    nanonext::handler(
      "/models",
      function(request) {
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(data = list(
            list(
              id = "model-a",
              model_picker_enabled = TRUE,
              capabilities = list(supports = list(tool_calls = TRUE))
            )
          )), auto_unbox = TRUE)
        )
      }
    )
  )
)
expect_equal(server$start(), 0L)

policy <- rho_github_copilot_enable_known_models_policy(c("model-a", "model-b"))
strategy <- rho_github_copilot_auth(
  endpoints = GitHubCopilotEndpoints(
    device_code = paste0(server$url, "/unused-device"),
    access_token = paste0(server$url, "/unused-access"),
    copilot_token = paste0(server$url, "/unused-token"),
    models = paste0(server$url, "/models")
  ),
  model_policy = policy,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
credential <- rho_github_copilot_credential(
  session_token = "session-token",
  github_token = "github-token",
  expires = Inf,
  session_base_url = server$url
)
io <- rho_login_io(
  prompt = function(prompt) "",
  notify = function(event) {
    policy_notifications <<- c(policy_notifications, event@message)
    NULL
  }
)
prepared <- rho_prepare_github_copilot_models(
  policy,
  strategy,
  credential,
  io
) |> rho_await(timeout = 5000L)

expect_equal(sort(policy_requests), c("model-a", "model-b"))
expect_equal(length(policy_notifications), 2L)
expect_true(any(grepl("model-a: enabled", policy_notifications, fixed = TRUE)))
expect_true(any(grepl("model-b: not enabled", policy_notifications, fixed = TRUE)))
expect_true(prepared@model_catalog_complete)
expect_equal(prepared@available_model_ids, "model-a")
expect_equal(server$close(), 0L)

request_headers <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/responses",
    function(connection, request) {
      request_headers <<- request$headers
      values <- list(
        list(
          type = "response.output_item.added",
          output_index = 0L,
          item = list(type = "message", id = "msg_1", content = list())
        ),
        list(type = "response.output_text.delta", output_index = 0L, delta = "hello"),
        list(
          type = "response.output_item.done",
          output_index = 0L,
          item = list(
            type = "message",
            id = "msg_1",
            content = list(list(type = "output_text", text = "hello"))
          )
        ),
        list(
          type = "response.completed",
          response = list(
            id = "resp_1",
            status = "completed",
            usage = list(
              input_tokens = 4,
              output_tokens = 2,
              total_tokens = 6,
              input_tokens_details = list(cached_tokens = 1),
              output_tokens_details = list(reasoning_tokens = 1)
            )
          )
        )
      )
      connection$set_status(200L)
      connection$set_header("Content-Type", "text/event-stream")
      for (value in values) {
        connection$send(nanonext::format_sse(
          data = yyjsonr::write_json_str(value, auto_unbox = TRUE)
        ))
      }
      connection$close()
    }
  ))
)
expect_equal(server$start(), 0L)

credential <- rho_github_copilot_credential(
  session_token = paste0(
    "tid=test;exp=9999999999;",
    "proxy-ep=proxy.individual.githubcopilot.com;"
  ),
  github_token = "github-test-token",
  expires = Inf,
  session_base_url = server$url,
  source = "stream-fixture"
)
provider <- rho_github_copilot_provider(
  http = rho::rho_http_client(timeout_ms = 2000L)
)
models <- rho_models(
  list(provider),
  rho_memory_credential_store(list(`github-copilot` = credential))
)
events <- rho_stream(
  models,
  rho_github_copilot_model("gpt-5.3-codex"),
  rho_context(messages = list(rho_user_message("hello")))
) |> rho_stream_collect(timeout = 2000L)

expect_equal(
  vapply(events, rho_assistant_event_type, character(1)),
  c("start", "text_start", "text_delta", "text_end", "done")
)
expect_equal(events[[5L]]@message@provider, "github-copilot")
expect_equal(events[[5L]]@message@content[[1L]]@text, "hello")
expect_true(S7::S7_inherits(events[[5L]]@message@usage, ProviderUsage))
expect_equal(events[[5L]]@message@usage@input, 3)
expect_equal(events[[5L]]@message@usage@cache_read, 1)
expect_equal(events[[5L]]@message@usage@reasoning, 1)
expect_equal(events[[5L]]@message@usage@total, 6)
expect_equal(request_headers[["X-Initiator"]], "user")
expect_equal(server$close(), 0L)
