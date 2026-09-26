# Generated from inst/tinytest/rmd/rho.ai-kimi.Rmd; do not edit.

library(tinytest)
library(rho)

identity <- rho_kimi_code_identity(user_agent = "RhoTest/1.0")
provider <- rho_kimi_code_provider(identity = identity)
k3 <- rho_kimi_code_model("k3")

expect_true(S7::S7_inherits(provider, RhoProvider))
expect_true(S7::S7_inherits(provider@implementation, KimiCodeApi))
expect_true(S7::S7_inherits(provider@auth@api_key, KimiCodeApiKeyAuth))
expect_true(S7::S7_inherits(provider@auth@oauth, KimiCodeOAuthAuth))
expect_true(S7::S7_inherits(k3, AnthropicMessagesModel))
expect_true(S7::S7_inherits(
  k3@compatibility@thinking,
  AnthropicAdaptiveThinkingCapability
))
expect_true(k3@compatibility@allow_empty_signature)
expect_equal(k3@limits@context_window, 1048576L)
expect_equal(k3@limits@max_tokens, 131072L)
expect_equal(
  sort(vapply(provider@models, function(model) model@id, character(1))),
  c("k2p7", "k3", "kimi-for-coding-highspeed")
)

prompts <- list()
io <- rho_login_io(prompt = function(prompt) {
  prompts[[length(prompts) + 1L]] <<- prompt
  "kimi-subscription-key"
})
credential <- rho_auth_login(provider@auth@api_key, provider@id, io) |>
  rho_await(timeout = 1000L)
model_auth <- rho_auth_to_request(provider@auth@api_key, credential) |>
  rho_await(timeout = 1000L)
request <- rho_anthropic_messages_request(
  provider@implementation,
  k3,
  rho_context(messages = list(rho_user_message("hello"))),
  options = list(auth = model_auth, reasoning_effort = "max")
)

expect_true(S7::S7_inherits(prompts[[1L]], RhoSecretAuthPrompt))
expect_true(S7::S7_inherits(credential, RhoApiKeyCredential))
expect_true(S7::S7_inherits(model_auth, KimiCodeModelAuth))
expect_equal(request@headers$Authorization, "Bearer kimi-subscription-key")
expect_equal(request@headers$`User-Agent`, "RhoTest/1.0")
expect_true(is.null(request@headers$`x-api-key`))
expect_equal(request@body$thinking$type, "adaptive")
expect_equal(request@body$output_config$effort, "max")

poll_count <- 0L
refresh_count <- 0L
token_request_bodies <- character()
notified <- list()
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(
    nanonext::handler(
      "/api/oauth/device_authorization",
      function(request) {
        list(
          status = 200L,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(list(
            device_code = "kimi-device-code",
            user_code = "WDJB-MJHT",
            verification_uri = "https://auth.kimi.test/device",
            verification_uri_complete = "https://auth.kimi.test/device?user_code=WDJB-MJHT",
            expires_in = 30,
            interval = 0.001
          ), auto_unbox = TRUE)
        )
      },
      method = "POST"
    ),
    nanonext::handler(
      "/api/oauth/token",
      function(request) {
        body <- rawToChar(request$body)
        token_request_bodies <<- c(token_request_bodies, body)
        if (grepl("grant_type=refresh_token", body, fixed = TRUE)) {
          refresh_count <<- refresh_count + 1L
          document <- list(
            access_token = "kimi-refreshed-access",
            refresh_token = "kimi-refreshed-refresh",
            expires_in = 3600,
            token_type = "Bearer"
          )
          status <- 200L
        } else {
          poll_count <<- poll_count + 1L
          if (poll_count == 1L) {
            document <- list(error = "authorization_pending")
            status <- 400L
          } else {
            document <- list(
              access_token = "kimi-device-access",
              refresh_token = "kimi-device-refresh",
              expires_in = 3600,
              scope = "inference",
              token_type = "Bearer"
            )
            status <- 200L
          }
        }
        list(
          status = status,
          headers = c("Content-Type" = "application/json"),
          body = yyjsonr::write_json_str(document, auto_unbox = TRUE)
        )
      },
      method = "POST"
    )
  )
)
expect_equal(server$start(), 0L)

oauth <- rho_kimi_code_oauth_auth(
  identity = identity,
  oauth_host = server$url,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
oauth_io <- rho_login_io(
  prompt = function(prompt) stop("Kimi device login must not prompt for a secret"),
  notify = function(event) {
    notified[[length(notified) + 1L]] <<- event
    NULL
  }
)
subscription <- rho_auth_login(oauth, "kimi-coding", oauth_io) |>
  rho_await(timeout = 5000L)

expect_true(S7::S7_inherits(subscription, KimiCodeOAuthCredential))
expect_equal(subscription@state$access, "kimi-device-access")
expect_equal(subscription@state$refresh, "kimi-device-refresh")
expect_equal(poll_count, 2L)
expect_equal(length(notified), 1L)
expect_true(S7::S7_inherits(notified[[1L]], RhoDeviceCodeEvent))
expect_equal(notified[[1L]]@user_code, "WDJB-MJHT")
expect_equal(
  notified[[1L]]@verification_uri_complete,
  "https://auth.kimi.test/device?user_code=WDJB-MJHT"
)

refreshed <- rho_auth_refresh(oauth, subscription) |>
  rho_await(timeout = 2000L)
refreshed_auth <- rho_auth_to_request(oauth, refreshed) |>
  rho_await(timeout = 1000L)

expect_true(S7::S7_inherits(refreshed, KimiCodeOAuthCredential))
expect_equal(refreshed@state$access, "kimi-refreshed-access")
expect_equal(refresh_count, 1L)
expect_true(grepl("client_id=17e5f671-d194-4dfb-9706-5516cb48c098", token_request_bodies[[1L]], fixed = TRUE))
expect_true(S7::S7_inherits(refreshed_auth, KimiCodeModelAuth))
expect_equal(refreshed_auth@api_key, "kimi-refreshed-access")
expect_equal(server$close(), 0L)

platform <- rho_kimi_platform_provider()
platform_model <- rho_kimi_platform_model("kimi-k3")
platform_credential <- rho_api_key_credential(
  "moonshotai",
  "moonshot-test-key",
  source = "fixture"
)
platform_auth <- rho_auth_to_request(
  platform@auth@api_key,
  platform_credential
) |>
  rho_await(timeout = 1000L)
platform_context <- rho_context(messages = list(rho_user_message(list(
  rho_text("Describe the image."),
  ImageContent(data = "iVBORw0KGgo=", mime_type = "image/png")
))))
platform_request <- rho_kimi_platform_request(
  platform@implementation,
  platform_model,
  platform_context,
  options = list(
    auth = platform_auth,
    reasoning_effort = "max",
    max_tokens = 4096L
  )
)

expect_true(S7::S7_inherits(platform@implementation, KimiPlatformApi))
expect_true(S7::S7_inherits(platform_model, KimiPlatformChatCompletionsModel))
expect_equal(platform_request@url, "https://api.moonshot.ai/v1/chat/completions")
expect_equal(platform_request@headers$Authorization, "Bearer moonshot-test-key")
expect_equal(platform_request@body$max_completion_tokens, 4096L)
expect_true(is.null(platform_request@body$max_tokens))
expect_equal(
  platform_request@body$thinking,
  list(type = "enabled", effort = "max")
)
expect_equal(
  platform_request@body$messages[[1L]]$content[[2L]],
  list(
    type = "image_url",
    image_url = list(url = "data:image/png;base64,iVBORw0KGgo=")
  )
)

disabled_request <- rho_kimi_platform_request(
  platform@implementation,
  platform_model,
  rho_context(messages = list(rho_user_message("hello"))),
  options = list(auth = platform_auth, reasoning_effort = "off")
)
expect_equal(disabled_request@body$thinking, list(type = "disabled"))

china <- rho_kimi_platform_provider(rho_kimi_platform_china_endpoint())
expect_equal(china@id, "moonshotai-cn")
expect_true(length(china@models) > 0L)

decoder <- rho_openai_chat_decoder(platform_model)
platform_sse <- function(data) {
  rho::RhoSseEvent(
    event = "message",
    data = data,
    id = "",
    retry = NA_integer_
  )
}
rho_decode_provider_event(
  decoder,
  platform_sse(yyjsonr::write_json_str(list(
    choices = list(list(
      delta = list(content = "done"),
      finish_reason = "stop",
      usage = list(prompt_tokens = 5L, completion_tokens = 2L)
    ))
  ), auto_unbox = TRUE))
)
terminal <- rho_decode_provider_event(decoder, platform_sse("[DONE]"))
done <- Filter(
  function(event) S7::S7_inherits(event, AssistantDoneEvent),
  terminal
)[[1L]]

expect_equal(done@message@usage@input, 5)
expect_equal(done@message@usage@output, 2)
expect_true(S7::S7_inherits(done@message@usage, ProviderUsage))
