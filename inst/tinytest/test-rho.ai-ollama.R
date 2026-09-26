# Generated from inst/tinytest/rmd/rho.ai-ollama.Rmd; do not edit.

library(tinytest)
library(rho)

unsupported <- rho_ollama_chat_request(
  rho_ollama_provider(),
  rho_ollama_model("fixture"),
  rho_context(
    messages = list(rho_user_message("search")),
    operations = list(rho_web_search())
  )
)
expect_true(S7::S7_inherits(unsupported, OperationUnsupported))

received_body <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/v1/chat/completions",
    function(connection, request) {
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
            delta = list(content = "hello from ollama"),
            finish_reason = NULL
          ))
        ),
        list(
          id = "chat_1",
          choices = list(list(
            index = 0L,
            delta = list(),
            finish_reason = "stop"
          )),
          usage = list(
            prompt_tokens = 2L,
            completion_tokens = 3L,
            total_tokens = 5L
          )
        )
      )
      connection$set_status(200L)
      connection$set_header("Content-Type", "text/event-stream")
      for (chunk in chunks) {
        connection$send(nanonext::format_sse(
          data = yyjsonr::write_json_str(
            chunk,
            auto_unbox = TRUE,
            null = "null"
          )
        ))
      }
      connection$send(nanonext::format_sse(data = "[DONE]"))
      connection$close()
    }
  ))
)
expect_equal(server$start(), 0L)

provider <- rho_ollama_provider(
  base_url = server$url,
  http = rho::rho_http_client(timeout_ms = 2000L)
)
model <- rho_ollama_model("fixture")
events <- rho_stream(
  provider,
  model,
  rho_context(messages = list(rho_user_message("hello")))
) |> rho_stream_collect(timeout = 2000L)

expect_equal(
  vapply(events, rho_assistant_event_type, character(1)),
  c("start", "text_start", "text_delta", "text_end", "done")
)
message <- events[[5L]]@message
expect_equal(message@provider, "ollama")
expect_equal(message@content[[1L]]@text, "hello from ollama")
expect_true(S7::S7_inherits(message@usage, ProviderUsage))
expect_equal(message@usage@input, 2)
expect_equal(message@usage@output, 3)
expect_equal(message@usage@total, 5)
expect_equal(received_body$model, "fixture")
expect_identical(received_body$stream, TRUE)
expect_equal(server$close(), 0L)
