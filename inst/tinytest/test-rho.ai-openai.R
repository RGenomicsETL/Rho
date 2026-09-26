# Generated from inst/tinytest/rmd/rho.ai-openai.Rmd; do not edit.

library(tinytest)
library(rho)

provider <- rho_openai_provider()
model <- rho_openai_model("gpt-5.4")

expect_true(S7::S7_inherits(provider, RhoProvider))
expect_true(S7::S7_inherits(provider@implementation, OpenAIApi))
expect_true(S7::S7_inherits(provider@auth@api_key, OpenAIApiKeyAuth))
expect_true(S7::S7_inherits(model, OpenAIResponsesModel))
expect_equal(model@api, "openai-responses")
expect_true(S7::S7_inherits(
  model@compatibility@web_search,
  OpenAIWebSearchTextAndImage
))
expect_true(length(provider@models) > 1L)
spark <- rho_openai_codex_model("gpt-5.3-codex-spark")
expect_true(S7::S7_inherits(spark, OpenAICodexResponsesModel))
expect_true(S7::S7_inherits(
  spark@compatibility@web_search,
  RhoWebSearchUnavailable
))
expect_true(S7::S7_inherits(
  rho_github_copilot_model("gpt-5.3-codex"),
  GitHubCopilotResponsesModel
))

mini <- rho_openai_model("gpt-5-mini")
image <- ImageContent(
  data = "iVBORw0KGgo=",
  mime_type = "image/png"
)
image_context <- rho_context(messages = list(rho_user_message(list(
  rho_text("Read the label."),
  image
))))
image_placement <- rho_plan_tools(provider, mini, image_context)
image_compatibility <- rho_validate_model_input(mini, image_context)
image_body <- rho_openai_responses_body(
  mini,
  image_context,
  image_placement
)

expect_true(S7::S7_inherits(image_compatibility, ModelInputAccepted))
expect_identical(image_compatibility@model, mini)
expect_equal(image_compatibility@modalities, c("text", "image"))
expect_equal(image_body$input[[1L]]$content[[1L]], list(
  type = "input_text",
  text = "Read the label."
))
expect_equal(image_body$input[[1L]]$content[[2L]], list(
  type = "input_image",
  detail = "auto",
  image_url = "data:image/png;base64,iVBORw0KGgo="
))

tool_image_context <- rho_context(messages = list(
  rho_user_message("Render a plot."),
  rho_assistant_message(
    content = list(ToolCall(id = "call_1", name = "render", arguments = list())),
    provider = "openai",
    model = mini@id,
    stop_reason = "toolUse"
  ),
  rho_tool_result_message(
    tool_call_id = "call_1",
    tool_name = "render",
    content = list(rho_text("Rendered plot"), image)
  )
))
tool_image_body <- rho_openai_responses_body(
  mini,
  tool_image_context,
  rho_plan_tools(provider, mini, tool_image_context)
)
expect_equal(tool_image_body$input[[3L]]$type, "function_call_output")
expect_equal(tool_image_body$input[[3L]]$output[[2L]]$type, "input_image")
expect_equal(
  tool_image_body$input[[3L]]$output[[2L]]$image_url,
  "data:image/png;base64,iVBORw0KGgo="
)

unsupported_image <- rho_validate_model_input(spark, image_context)
unsupported_body <- rho_openai_responses_body(
  spark,
  image_context,
  rho_plan_tools(rho_openai_codex_provider(), spark, image_context)
)
expect_true(S7::S7_inherits(unsupported_image, ProviderInputUnsupported))
expect_true(S7::S7_inherits(unsupported_body, ProviderInputUnsupported))
expect_equal(unsupported_image@details$unsupported, "image")

tool <- rho_tool_spec(
  name = "lookup",
  description = "Look up a value",
  parameters = list(type = "object", properties = list()),
  execute = function(...) NULL
)
context <- rho_context(
  system_prompt = "Use the tool when needed.",
  messages = list(rho_user_message("hello")),
  tools = list(tool)
)
placement <- rho_plan_tools(provider, model, context)
sections <- rho_openai_request_sections(
  model,
  context,
  placement,
  options = list(
    max_tokens = 256L,
    temperature = 0.5,
    service_tier = "flex",
    text_verbosity = "medium",
    session_id = "session-1",
    reasoning_effort = rho_thinking_level("high")
  )
)
body <- rho_openai_responses_body(
  model,
  context,
  placement,
  options = list(
    max_tokens = 256L,
    temperature = 0.5,
    service_tier = "flex",
    text_verbosity = "medium",
    session_id = "session-1",
    reasoning_effort = rho_thinking_level("high")
  )
)

expect_true(all(vapply(
  sections,
  function(section) S7::S7_inherits(section, OpenAIRequestSection),
  logical(1)
)))
expect_true(s7contract::implements(
  S7::S7_class(sections[[1L]]),
  ProviderRequestSectionProtocol
))
expect_equal(body$instructions, "Use the tool when needed.")
expect_equal(body$tools[[1L]]$name, "lookup")
expect_equal(body$tool_choice, "auto")
expect_equal(body$max_output_tokens, 256L)
expect_equal(body$temperature, 0.5)
expect_equal(body$service_tier, "flex")
expect_equal(body$text$verbosity, "medium")
expect_equal(body$prompt_cache_key, "session-1")
expect_equal(body$reasoning$effort, "high")
expect_equal(body$include[[1L]], "reasoning.encrypted_content")

disabled <- rho_openai_responses_body(
  model,
  context,
  placement,
  options = list(reasoning_effort = rho_thinking_level("off"))
)
expect_equal(disabled$reasoning$effort, "none")
expect_true(is.null(disabled$include))

search <- rho_web_search(
  domains = rho_web_search_allowed_domains(c("r-project.org", "cran.r-project.org")),
  location = rho_approximate_location(country = "DE", city = "Berlin")
)
search_context <- rho_context(
  messages = list(rho_user_message("Find the current R release.")),
  tools = list(tool),
  operations = list(search)
)
unbound_search <- rho_openai_responses_body(
  model,
  search_context,
  rho_plan_tools(provider, model, search_context)
)
search_plan <- rho_plan_operations(provider, model, search_context)
search_support <- rho_provider_support(provider, model, search)
search_body <- rho_openai_responses_body(
  model,
  search_context,
  rho_plan_tools(provider, model, search_context),
  options = list(operation_plan = search_plan)
)

expect_true(S7::S7_inherits(unbound_search, ProviderErrorValue))
expect_equal(unbound_search@code, "operation_plan_required")
expect_true(search_support@supported)
expect_true(S7::S7_inherits(search_plan, RhoOperationPlan))
expect_true(S7::S7_inherits(search_plan@bindings[[1L]], OpenAIWebSearchBinding))
expect_equal(search_body$tools[[1L]]$type, "function")
expect_equal(search_body$tools[[2L]]$type, "web_search")
expect_equal(
  search_body$tools[[2L]]$filters$allowed_domains,
  c("r-project.org", "cran.r-project.org")
)
expect_equal(search_body$tools[[2L]]$user_location$country, "DE")
expect_equal(search_body$tools[[2L]]$user_location$city, "Berlin")

spark_search <- rho_plan_operations(
  rho_openai_codex_provider(),
  spark,
  rho_context(operations = list(rho_web_search()))
)
spark_support <- rho_provider_support(
  rho_openai_codex_provider(),
  spark,
  rho_web_search()
)
expect_true(S7::S7_inherits(spark_search, OperationUnsupported))
expect_equal(spark_search@details$model, "gpt-5.3-codex-spark")
expect_false(spark_support@supported)

blocked_context <- rho_context(
  messages = list(rho_user_message("Search.")),
  operations = list(rho_web_search(
    domains = rho_web_search_blocked_domains("example.invalid")
  ))
)
blocked <- rho_plan_operations(provider, model, blocked_context)
blocked_request <- rho_openai_request(
  provider,
  model,
  blocked_context,
  options = list(auth = rho_model_auth(api_key = "test"))
)
invalid_plan_request <- rho_openai_request(
  provider,
  model,
  context,
  options = list(
    auth = rho_model_auth(api_key = "test"),
    operation_plan = "invalid"
  )
)
incomplete_plan_request <- rho_openai_request(
  provider,
  model,
  search_context,
  options = list(
    auth = rho_model_auth(api_key = "test"),
    operation_plan = rho_operation_plan()
  )
)
expect_true(S7::S7_inherits(blocked, OperationUnsupported))
expect_true(S7::S7_inherits(blocked_request, OperationUnsupported))
expect_true(S7::S7_inherits(blocked@operation, RhoWebSearchOperation))
expect_equal(blocked@handler_class, "OpenAIApi")
expect_true(S7::S7_inherits(invalid_plan_request, ProviderErrorValue))
expect_equal(invalid_plan_request@code, "operation_plan_type")
expect_true(S7::S7_inherits(incomplete_plan_request, ProviderErrorValue))
expect_equal(incomplete_plan_request@code, "operation_plan_incomplete")

search_decoder <- rho_openai_responses_decoder(model)
openai_event <- function(value) {
  rho::RhoSseEvent(
    event = "message",
    data = yyjsonr::write_json_str(value, auto_unbox = TRUE),
    id = "",
    retry = NA_integer_
  )
}

started <- rho_decode_provider_event(search_decoder, openai_event(list(
  type = "response.output_item.added",
  output_index = 0L,
  item = list(
    type = "web_search_call",
    id = "search_1",
    status = "in_progress"
  )
)))
finished <- rho_decode_provider_event(search_decoder, openai_event(list(
  type = "response.output_item.done",
  output_index = 0L,
  item = list(
    type = "web_search_call",
    id = "search_1",
    status = "completed",
    action = list(type = "search", query = "current R release")
  )
)))

expect_equal(
  vapply(c(started, finished), rho_assistant_event_type, character(1)),
  c("start", "operation_start", "operation_end")
)
search_content <- finished[[1L]]@partial@content[[1L]]
expect_true(S7::S7_inherits(search_content, WebSearchCallContent))
expect_false(S7::S7_inherits(search_content, ToolCall))
expect_true(S7::S7_inherits(search_content@status, OperationCompleted))
expect_equal(search_content@action@queries, "current R release")

history <- rho_context(messages = list(rho_assistant_message(
  content = list(search_content),
  provider = "openai",
  model = model@id
)))
history_body <- rho_openai_responses_body(
  model,
  history,
  rho_plan_tools(provider, model, history)
)
expect_equal(history_body$input[[1L]]$type, "web_search_call")
expect_equal(history_body$input[[1L]]$status, "completed")
expect_equal(history_body$input[[1L]]$action$query, "current R release")

prompts <- list()
io <- rho_login_io(prompt = function(prompt) {
  prompts[[length(prompts) + 1L]] <<- prompt
  "entered-openai-key"
})
credential <- rho_auth_login(provider@auth@api_key, "openai", io) |>
  rho_await(timeout = 1000L)

expect_true(S7::S7_inherits(credential, RhoApiKeyCredential))
expect_true(S7::S7_inherits(prompts[[1L]], RhoSecretAuthPrompt))
expect_equal(credential@provider, "openai")

received_headers <- NULL
received_body <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/responses",
    function(connection, request) {
      received_headers <<- request$headers
      received_body <<- yyjsonr::read_json_str(
        rawToChar(request$body),
        arr_of_objs_to_df = FALSE,
        obj_of_arrs_to_df = FALSE
      )
      values <- list(
        list(
          type = "response.output_item.added",
          output_index = 0L,
          item = list(type = "message", id = "msg_1", content = list())
        ),
        list(
          type = "response.output_text.delta",
          output_index = 0L,
          delta = "hello from openai"
        ),
        list(
          type = "response.output_item.done",
          output_index = 0L,
          item = list(
            type = "message",
            id = "msg_1",
            content = list(list(type = "output_text", text = "hello from openai"))
          )
        ),
        list(
          type = "response.completed",
          response = list(
            id = "resp_1",
            status = "completed",
            usage = list(
              input_tokens = 12,
              output_tokens = 3,
              total_tokens = 15,
              input_tokens_details = list(cached_tokens = 2),
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

live_provider <- rho_openai_provider(
  base_url = server$url,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
live_models <- rho_models(
  list(live_provider),
  rho_memory_credential_store(list(
    openai = rho_api_key_credential("openai", "openai-test-key")
  ))
)
events <- rho_stream(
  live_models,
  model,
  rho_context("Answer directly.", list(rho_user_message("hello"))),
  options = list(reasoning_effort = rho_thinking_level("high"))
) |>
  rho_stream_collect(timeout = 2000L)

expect_equal(
  vapply(events, rho_assistant_event_type, character(1)),
  c("start", "text_start", "text_delta", "text_end", "done")
)
terminal <- events[[length(events)]]
expect_equal(terminal@message@content[[1L]]@text, "hello from openai")
expect_equal(terminal@message@response_id, "resp_1")
expect_true(S7::S7_inherits(terminal@message@usage, ProviderUsage))
expect_equal(terminal@message@usage@input, 10)
expect_equal(terminal@message@usage@cache_read, 2)
expect_equal(terminal@message@usage@reasoning, 1)
expect_equal(received_headers[["Authorization"]], "Bearer openai-test-key")
expect_equal(received_body$model, "gpt-5.4")
expect_equal(received_body$reasoning$effort, "high")
expect_identical(received_body$store, FALSE)
expect_equal(server$close(), 0L)

missing_usage_events <- rho_reduce_provider_event(
  OpenAIResponseCompleted(response = list(id = "resp_without_usage", status = "completed")),
  rho_openai_responses_decoder(model)
)
missing_usage <- Filter(
  function(event) S7::S7_inherits(event, AssistantDoneEvent),
  missing_usage_events
)[[1L]]@message@usage

expect_true(S7::S7_inherits(missing_usage, UsageUnavailable))
expect_equal(missing_usage@provider, "openai")
expect_match(missing_usage@reason, "did not report token usage")

input_limit_events <- rho_decode_provider_event(
  rho_openai_responses_decoder(model),
  rho::RhoHttpStatusError(
    message = "HTTP stream returned status 400",
    url = "https://example.test/responses",
    status = 400L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw(yyjsonr::write_json_str(list(error = list(
      message = "Maximum context length exceeded",
      type = "invalid_request_error",
      param = "input",
      code = "context_length_exceeded"
    )), auto_unbox = TRUE))
  )
)
input_limit <- input_limit_events[[length(input_limit_events)]]@error

expect_true(S7::S7_inherits(input_limit, ProviderContextOverflowError))
expect_true(S7::S7_inherits(input_limit, ProviderInputLimitError))
expect_equal(input_limit@code, "context_length_exceeded")
expect_equal(rawToChar(input_limit@details$body), rawToChar(charToRaw(
  yyjsonr::write_json_str(list(error = list(
    message = "Maximum context length exceeded",
    type = "invalid_request_error",
    param = "input",
    code = "context_length_exceeded"
  )), auto_unbox = TRUE)
)))

rate_limit_body <- charToRaw(yyjsonr::write_json_str(list(error = list(
  message = "Rate limit exceeded",
  type = "rate_limit_error",
  code = "rate_limit_exceeded"
)), auto_unbox = TRUE))

responses_rate_limit <- rho_decode_provider_event(
  rho_openai_responses_decoder(model),
  rho::RhoHttpStatusError(
    message = "HTTP stream returned status 429",
    url = "https://example.test/responses",
    status = 429L,
    headers = list(`content-type` = "application/json"),
    body = rate_limit_body
  )
)
chat_server_error <- rho_decode_provider_event(
  rho_openai_chat_decoder(rho_ollama_model("fixture")),
  rho::RhoHttpStatusError(
    message = "HTTP stream returned status 503",
    url = "https://example.test/chat/completions",
    status = 503L,
    headers = list(`content-type` = "application/json"),
    body = charToRaw(yyjsonr::write_json_str(list(error = list(
      message = "Service unavailable",
      type = "server_error",
      code = "server_error"
    )), auto_unbox = TRUE))
  )
)

expect_true(responses_rate_limit[[2L]]@error@retryable)
expect_equal(responses_rate_limit[[2L]]@error@code, "rate_limit_exceeded")
expect_true(chat_server_error[[2L]]@error@retryable)
expect_equal(chat_server_error[[2L]]@error@code, "server_error")
