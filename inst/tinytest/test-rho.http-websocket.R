# Generated from inst/tinytest/rmd/rho.http-websocket.Rmd; do not edit.

library(tinytest)
library(rho)

websocket_timeout_ms <- 20000L

server <- nanonext::http_server(
  url = "http://127.0.0.1:0",
  handlers = list(nanonext::handler_ws(
    "/events",
    on_message = function(connection, data) {
      connection$send(paste0("reply:", data))
    },
    textframes = TRUE
  ))
)
expect_equal(server$start(), 0L)

client <- rho_http_client(timeout_ms = websocket_timeout_ms)
request <- rho_ws_request(
  url = sub("^http", "ws", paste0(server$url, "/events")),
  headers = list(`X-Rho-Test` = "websocket"),
  timeout_ms = websocket_timeout_ms
)
opening <- rho_ws_connect(client, request)

expect_true(S7::S7_inherits(opening, RhoTask))
socket <- rho_await(opening, timeout = websocket_timeout_ms)
expect_true(S7::S7_inherits(socket, RhoNanonextWebSocket))
expect_true(s7contract::implements(RhoNanonextHttpClient, WebSocketClient))
expect_true(s7contract::implements(RhoNanonextWebSocket, RhoDuplexChannel))

sent <- rho_duplex_send(socket, "request", timeout = websocket_timeout_ms)
expect_null(rho_await(sent, timeout = websocket_timeout_ms))

received <- rho_stream_next(socket, timeout = websocket_timeout_ms) |>
  rho_await(timeout = websocket_timeout_ms)
expect_true(S7::S7_inherits(received, RhoStreamValue))
expect_equal(received@value, "reply:request")

expect_true(rho_stream_close(socket))
expect_true(S7::S7_inherits(
  rho_stream_next(socket) |> rho_await(timeout = websocket_timeout_ms),
  RhoStreamEnd
))
expect_equal(server$close(), 0L)
later::run_now(timeoutSecs = 0)
