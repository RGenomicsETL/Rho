# Generated from inst/tinytest/rmd/rho.ai-openai-codex-websocket.Rmd; do not edit.

library(tinytest)
library(rho)

server_state <- new.env(parent = emptyenv())
server_state$headers <- character()
server_state$request <- NULL
server_state$send_results <- integer()

response_event <- function(value) {
  yyjsonr::write_json_str(value, auto_unbox = TRUE, null = "null")
}

server <- nanonext::http_server(
  url = "http://127.0.0.1:0",
  handlers = list(nanonext::handler_ws(
    "/codex/responses",
    on_open = function(connection, request) {
      server_state$headers <- request$headers
    },
    on_message = function(connection, data) {
      server_state$request <- yyjsonr::read_json_str(
        data,
        arr_of_objs_to_df = FALSE,
        obj_of_arrs_to_df = FALSE
      )
      events <- list(
        list(
          type = "response.output_item.added",
          output_index = 0L,
          item = list(type = "message", id = "msg_local", content = list())
        ),
        list(type = "response.output_text.delta", output_index = 0L, delta = "websocket"),
        list(
          type = "response.output_item.done",
          output_index = 0L,
          item = list(
            type = "message",
            id = "msg_local",
            content = list(list(type = "output_text", text = "websocket"))
          )
        ),
        list(
          type = "response.completed",
          response = list(
            id = "resp_local",
            status = "completed",
            usage = list(input_tokens = 3, output_tokens = 1, total_tokens = 4)
          )
        )
      )
      for (event in events) {
        server_state$send_results <- c(
          server_state$send_results,
          connection$send(response_event(event))
        )
      }
    },
    textframes = TRUE
  ))
)
expect_equal(server$start(), 0L)

header <- function(name) {
  position <- match(tolower(name), tolower(names(server_state$headers)))
  if (is.na(position)) "" else unname(server_state$headers[[position]])
}

model <- rho_openai_codex_model("gpt-5.3-codex-spark")
provider <- OpenAICodexApi(
  base_url = server$url,
  originator = "rho-test",
  http = rho::rho_http_client(timeout_ms = 2000L)
)
auth <- rho_model_auth(
  api_key = "test-access-token",
  headers = list(`chatgpt-account-id` = "test-account")
)
context <- rho_context(messages = list(rho_user_message("Reply over WebSocket.")))
request <- rho_openai_codex_websocket_request(
  provider,
  model,
  context,
  options = list(auth = auth, session_id = "session-local")
)

expect_true(S7::S7_inherits(request, OpenAICodexWebSocketRequest))
expect_equal(request@request@url, paste0(sub("^http", "ws", server$url), "/codex/responses"))
expect_equal(request@request@headers$`OpenAI-Beta`, "responses_websockets=2026-02-06")
expect_false("Accept" %in% names(request@request@headers))
expect_false("Content-Type" %in% names(request@request@headers))

events <- rho_stream(
  provider,
  model,
  context,
  options = list(
    auth = auth,
    transport = WebSocketTransport(),
    timeout_ms = 2000L,
    session_id = "session-local"
  )
) |>
  rho_stream_collect(timeout = 4000L)

expect_equal(server_state$request$type, "response.create")
expect_equal(server_state$request$model, model@id)
expect_identical(server_state$request$stream, TRUE)
expect_equal(server_state$send_results, rep(0L, 4L))
expect_equal(header("authorization"), "Bearer test-access-token")
expect_equal(header("chatgpt-account-id"), "test-account")
expect_equal(header("originator"), "rho-test")
expect_equal(header("openai-beta"), "responses_websockets=2026-02-06")
expect_equal(header("session-id"), "session-local")
expect_equal(header("x-client-request-id"), "session-local")
expect_equal(
  vapply(events, rho_assistant_event_type, character(1)),
  c("start", "text_start", "text_delta", "text_end", "done")
)
expect_equal(events[[5L]]@message@content[[1L]]@text, "websocket")
expect_equal(events[[5L]]@message@response_id, "resp_local")
expect_equal(server$close(), 0L)
later::run_now(timeoutSecs = 0)
