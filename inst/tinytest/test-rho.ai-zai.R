# Generated from inst/tinytest/rmd/rho.ai-zai.Rmd; do not edit.

library(tinytest)
library(rho)

provider <- rho_zai_provider()
model <- rho_zai_model("glm-5.2")
credential <- rho_api_key_credential("zai", "zai-test-key", source = "fixture")
auth <- rho_auth_to_request(provider@auth@api_key, credential) |> rho_await()
tool <- rho_tool_spec(
  name = "read_file",
  description = "Read a file",
  parameters = list(
    type = "object",
    properties = list(path = list(type = "string")),
    required = "path"
  ),
  execute = function(...) NULL
)
context <- rho_context(
  system_prompt = "Work carefully.",
  messages = list(rho_user_message("Inspect the project")),
  tools = list(tool)
)
request <- rho_zai_request(
  provider@implementation,
  model,
  context,
  options = list(auth = auth, reasoning_effort = "max")
)

expect_true(S7::S7_inherits(model, ZaiChatCompletionsModel))
expect_true(S7::S7_inherits(model@thinking_control, ZaiThinkingControl))
expect_true(S7::S7_inherits(model@tool_call_streaming, ZaiToolCallStreaming))
expect_equal(model@limits@context_window, 1000000L)
expect_equal(model@limits@max_tokens, 131072L)
expect_equal(request@url, "https://api.z.ai/api/coding/paas/v4/chat/completions")
expect_equal(request@headers$Authorization, "Bearer zai-test-key")
expect_equal(request@body$thinking$type, "enabled")
expect_identical(request@body$thinking$clear_thinking, FALSE)
expect_equal(request@body$reasoning_effort, "max")
expect_identical(request@body$tool_stream, TRUE)
expect_equal(request@body$tools[[1L]][["function"]]$name, "read_file")
expect_true(s7contract::implements(ZaiApi, ProviderRequestTranslator))

unsupported_operation <- rho_zai_request(
  provider@implementation,
  model,
  rho_context(
    messages = list(rho_user_message("search")),
    operations = list(rho_web_search())
  ),
  options = list(auth = auth)
)
expect_true(S7::S7_inherits(unsupported_operation, OperationUnsupported))

disabled <- rho_zai_request(
  provider@implementation,
  model,
  context,
  options = list(auth = auth, reasoning_effort = "off")
)
expect_equal(disabled@body$thinking$type, "disabled")
expect_true(is.null(disabled@body$reasoning_effort))

general <- rho_zai_provider(rho_zai_general_endpoint())
general_model <- rho_zai_model("glm-5.2", rho_zai_general_endpoint())
general_auth <- rho_auth_to_request(
  general@auth@api_key,
  rho_api_key_credential("zai-api", "general-test-key")
) |> rho_await()
general_request <- rho_zai_request(
  general@implementation,
  general_model,
  context,
  options = list(auth = general_auth)
)
expect_identical(general_request@body$thinking$clear_thinking, TRUE)

previous <- rho_assistant_message(
  provider = "zai",
  model = "glm-5.2",
  content = list(
    rho_thinking("unaltered reasoning"),
    rho_text("visible answer")
  )
)
continued <- rho_zai_request(
  provider@implementation,
  model,
  rho_context(messages = list(previous, rho_user_message("continue"))),
  options = list(auth = auth)
)
expect_equal(continued@body$messages[[1L]]$reasoning_content, "unaltered reasoning")
expect_equal(continued@body$messages[[1L]]$content, "visible answer")

prompts <- list()
io <- rho_login_io(prompt = function(prompt) {
  prompts[[length(prompts) + 1L]] <<- prompt
  "entered-key"
})
models <- rho_models(list(provider))
logged_in <- rho_login_provider(
  models,
  "zai",
  io,
  method = RhoApiKeyLogin()
) |>
  rho_await(timeout = 2000L)
expect_true(S7::S7_inherits(logged_in, RhoApiKeyCredential))
expect_true(S7::S7_inherits(prompts[[1L]], RhoSecretAuthPrompt))
expect_equal(logged_in@provider, "zai")
expect_true(S7::S7_inherits(
  rho_credential_read(models@credentials, "zai") |> rho_await(timeout = 2000L),
  RhoApiKeyCredential
))

device_prompts <- 0L
device_events <- 0L
models <- rho_models(list(provider))
oauth_login <- rho_login_provider(
  models,
  "zai",
  rho_login_io(
    prompt = function(prompt) {
      device_prompts <<- device_prompts + 1L
      ""
    },
    notify = function(event) {
      device_events <<- device_events + 1L
      NULL
    }
  ),
  method = RhoOAuthLogin()
) |>
  rho_await(timeout = 2000L)

expect_true(S7::S7_inherits(oauth_login, AuthErrorValue))
expect_equal(oauth_login@code, "login_method")
expect_equal(device_prompts, 0L)
expect_equal(device_events, 0L)

received_body <- NULL
received_headers <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/chat/completions",
    function(connection, request) {
      received_headers <<- request$headers
      received_body <<- yyjsonr::read_json_str(
        rawToChar(request$body),
        arr_of_objs_to_df = FALSE,
        obj_of_arrs_to_df = FALSE
      )
      chunks <- list(
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(reasoning_content = "considering"),
            finish_reason = NULL
          ))
        ),
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(content = "answer"),
            finish_reason = NULL
          ))
        ),
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(tool_calls = list(list(
              index = 0L,
              id = "call_1",
              type = "function",
              `function` = list(name = "read_file", arguments = "{\"path\":")
            ))),
            finish_reason = NULL
          ))
        ),
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(tool_calls = list(list(
              index = 0L,
              `function` = list(arguments = "\"DESCRIPTION\"}")
            ))),
            finish_reason = NULL
          ))
        ),
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(),
            finish_reason = "tool_calls"
          ))
        ),
        list(
          id = "chat_1",
          choices = list(),
          usage = list(
            prompt_tokens = 10,
            completion_tokens = 4,
            total_tokens = 14,
            prompt_tokens_details = list(cached_tokens = 3),
            completion_tokens_details = list(reasoning_tokens = 2)
          )
        )
      )
      connection$set_status(200L)
      connection$set_header("Content-Type", "text/event-stream")
      for (chunk in chunks) {
        connection$send(nanonext::format_sse(
          data = yyjsonr::write_json_str(chunk, auto_unbox = TRUE, null = "null")
        ))
      }
      connection$send(nanonext::format_sse(data = "[DONE]"))
      connection$close()
    }
  ))
)
expect_equal(server$start(), 0L)

endpoint <- ZaiCodingEndpoint(
  provider_id = "zai",
  name = "Z.ai fixture",
  base_url = server$url
)
provider <- rho_zai_provider(
  endpoint,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
models <- rho_models(
  list(provider),
  rho_memory_credential_store(list(
    zai = rho_api_key_credential("zai", "zai-test-key")
  ))
)
events <- rho_stream(
  models,
  rho_zai_model("glm-5.2", endpoint),
  context
) |> rho_stream_collect(timeout = 2000L)
types <- vapply(events, rho_assistant_event_type, character(1))

expect_equal(
  types,
  c(
    "start",
    "thinking_start",
    "thinking_delta",
    "text_start",
    "text_delta",
    "toolcall_start",
    "toolcall_delta",
    "toolcall_delta",
    "thinking_end",
    "text_end",
    "toolcall_end",
    "done"
  )
)
terminal <- events[[length(events)]]
expect_equal(terminal@reason, "toolUse")
expect_equal(terminal@message@provider, "zai")
expect_true(S7::S7_inherits(terminal@message@usage, ProviderUsage))
expect_equal(terminal@message@usage@total, 14)
expect_equal(terminal@message@usage@input, 7)
expect_equal(terminal@message@usage@cache_read, 3)
expect_equal(terminal@message@usage@reasoning, 2)
call <- Filter(
  function(content) S7::S7_inherits(content, ToolCall),
  terminal@message@content
)[[1L]]
expect_equal(call@name, "read_file")
expect_equal(call@arguments$path, "DESCRIPTION")
expect_equal(received_headers[["Authorization"]], "Bearer zai-test-key")
expect_identical(received_body$tool_stream, TRUE)
expect_equal(received_body$thinking$type, "enabled")
expect_true(s7contract::implements(OpenAIChatCompletionsDecoder, ProviderEventDecoder))
expect_true(s7contract::implements(OpenAIChatTextDelta, ProviderWireEvent))
expect_equal(server$close(), 0L)
