# Generated from inst/tinytest/rmd/rho.agent-anthropic-provider-loop.Rmd; do not edit.

library(tinytest)
library(rho)

request_bodies <- list()
request_index <- 0L
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/v1/messages",
    function(connection, request) {
      request_index <<- request_index + 1L
      request_bodies[[request_index]] <<- yyjsonr::read_json_str(
        rawToChar(request$body),
        arr_of_objs_to_df = FALSE,
        obj_of_arrs_to_df = FALSE
      )
      values <- if (request_index == 1L) {
        list(
          list(
            type = "message_start",
            message = list(id = "msg_tool", usage = list(input_tokens = 4))
          ),
          list(
            type = "content_block_start",
            index = 0L,
            content_block = list(
              type = "tool_use",
              id = "call_1",
              name = "lookup",
              input = list()
            )
          ),
          list(
            type = "content_block_delta",
            index = 0L,
            delta = list(
              type = "input_json_delta",
              partial_json = "{\"value\":\"alpha\"}"
            )
          ),
          list(type = "content_block_stop", index = 0L),
          list(
            type = "message_delta",
            delta = list(stop_reason = "tool_use"),
            usage = list(output_tokens = 3)
          ),
          list(type = "message_stop")
        )
      } else {
        list(
          list(
            type = "message_start",
            message = list(id = "msg_text", usage = list(input_tokens = 8))
          ),
          list(
            type = "content_block_start",
            index = 0L,
            content_block = list(type = "text", text = "")
          ),
          list(
            type = "content_block_delta",
            index = 0L,
            delta = list(type = "text_delta", text = "finished")
          ),
          list(type = "content_block_stop", index = 0L),
          list(
            type = "message_delta",
            delta = list(stop_reason = "end_turn"),
            usage = list(output_tokens = 2)
          ),
          list(type = "message_stop")
        )
      }
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

provider <- rho_anthropic_provider(
  base_url = server$url,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
models <- rho_models(
  list(provider),
  rho_memory_credential_store(list(
    anthropic = rho_api_key_credential("anthropic", "agent-test-key")
  ))
)
lookup <- rho_tool_spec(
  name = "lookup",
  description = "Return the supplied value",
  parameters = list(
    type = "object",
    properties = list(value = list(type = "string")),
    required = "value"
  ),
  execute = function(id, args, signal, on_update, ctx) {
    rho_tool_result(list(rho_text(args$value)))
  }
)
agent <- rho_agent(
  provider = models,
  model = rho_anthropic_model("claude-fable-5"),
  tools = list(lookup)
)
result <- rho_prompt(agent, "look up alpha") |>
  rho_await(timeout = 5000L)

expect_equal(result@status, "completed")
expect_equal(length(result@tool_results), 1L)
expect_equal(result@tool_results[[1L]]@content[[1L]]@text, "alpha")
expect_equal(result@messages[[4L]]@content[[1L]]@text, "finished")
expect_equal(length(request_bodies), 2L)
expect_equal(request_bodies[[2L]]$messages[[2L]]$content[[1L]]$type, "tool_use")
expect_equal(request_bodies[[2L]]$messages[[3L]]$content[[1L]]$type, "tool_result")
expect_equal(server$close(), 0L)
