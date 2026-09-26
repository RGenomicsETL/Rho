# Generated from inst/tinytest/rmd/rho.http.httr2-worker-transport.Rmd; do not edit.

library(tinytest)
library(rho)
source(
  system.file("contract", "http-client.R", package = "rho"),
  local = TRUE
)

worker_timeout_ms <- 20000L
worker_profile <- paste0("rho-http-httr2-", Sys.getpid())
mirai::daemons(1L, .compute = worker_profile)
on.exit(mirai::daemons(0L, .compute = worker_profile), add = TRUE)
worker_compute <- rho::rho_mirai_backend(compute = worker_profile)

rho_http_client_contract(
  client_factory = function(
    timeout_ms,
    stream_buffer_size,
    max_error_body_bytes
  ) {
    rho_httr2_http_client(
      timeout_ms = timeout_ms,
      stream_buffer_size = stream_buffer_size,
      max_error_body_bytes = max_error_body_bytes,
      compute = worker_compute
    )
  },
  expected_open_execution = RhoHttpWorkerOpen,
  timeout_ms = worker_timeout_ms
)

rho_http_contract_connection_delimited_body(
  client_factory = function(
    timeout_ms,
    stream_buffer_size,
    max_error_body_bytes
  ) {
    rho_httr2_http_client(
      timeout_ms = timeout_ms,
      stream_buffer_size = stream_buffer_size,
      max_error_body_bytes = max_error_body_bytes,
      compute = worker_compute
    )
  },
  timeout_ms = worker_timeout_ms
)

server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler(
    "/complete",
    function(request) {
      list(
        status = 201L,
        headers = c("Content-Type" = "text/plain"),
        body = "created"
      )
    },
    method = "POST"
  ))
)
expect_equal(server$start(), 0L)

client <- rho_httr2_http_client(
  timeout_ms = worker_timeout_ms,
  compute = worker_compute
)
expect_true(s7contract::implements(client, HttpClient))
request <- rho_http_request(
  "POST",
  paste0(server$url, "/complete"),
  body = list(value = 1L),
  timeout_ms = worker_timeout_ms
)
task <- rho_http_send(client, request)
expect_true(S7::S7_inherits(task, RhoTask))
response <- rho_await(task, timeout = worker_timeout_ms)
expect_true(S7::S7_inherits(response, RhoHttpResponse))
expect_equal(response@status, 201L)
expect_equal(response@data, "created")

expect_true(rho_http_client_close(client))
expect_equal(server$close(), 0L)

server_connection <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/delayed",
    on_request = function(connection, request) {
      server_connection <<- connection
      later::later(function() {
        connection$set_status(200L)
        connection$set_header("Content-Type", "application/octet-stream")
        connection$send(charToRaw("ready"))
      }, delay = 0.05)
    }
  ))
)
expect_equal(server$start(), 0L)

client <- rho_httr2_http_client(
  timeout_ms = worker_timeout_ms,
  compute = worker_compute
)
opening <- rho_http_open_stream(
  client,
  rho_http_request(
    "GET",
    paste0(server$url, "/delayed"),
    timeout_ms = worker_timeout_ms
  )
)
expect_true(S7::S7_inherits(opening, RhoTask))
expect_true(rho_pending(opening))

body <- rho_await(opening, timeout = worker_timeout_ms)
expect_true(S7::S7_inherits(body, RhoHttr2HttpBodyStream))
item <- rho_stream_next(body) |> rho_await(timeout = worker_timeout_ms)
item_value <- rho_http_contract_stream_value(item)
if (is.raw(item_value)) {
  expect_equal(rawToChar(item_value), "ready")
}

expect_true(rho_stream_close(body))
expect_equal(server_connection$close(), 0L)
expect_true(rho_http_client_close(client))
expect_equal(server$close(), 0L)

server_connection <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/events",
    on_request = function(connection, request) {
      server_connection <<- connection
      connection$set_status(200L)
      connection$set_header("Content-Type", "text/event-stream")
      connection$send(nanonext::format_sse(data = "first"))
    }
  ))
)
expect_equal(server$start(), 0L)

client <- rho_httr2_http_client(
  timeout_ms = worker_timeout_ms,
  stream_buffer_size = 65536L,
  compute = worker_compute
)
events <- rho_sse_connect(
  client,
  rho_http_request(
    "GET",
    paste0(server$url, "/events"),
    timeout_ms = worker_timeout_ms
  )
)
first <- rho_stream_next(events) |> rho_await(timeout = worker_timeout_ms)
rho_http_contract_expect_sse_data(first, "first")

expect_equal(
  server_connection$send(nanonext::format_sse(data = "second")),
  0L
)
second <- rho_stream_next(events) |> rho_await(timeout = worker_timeout_ms)
rho_http_contract_expect_sse_data(second, "second")

expect_equal(server_connection$close(), 0L)
ending <- rho_stream_next(events) |> rho_await(timeout = worker_timeout_ms)
expect_true(S7::S7_inherits(ending, RhoStreamEnd))

expect_true(rho_http_client_close(client))
expect_equal(server$close(), 0L)

server_connection <- NULL
server <- nanonext::http_server(
  "http://127.0.0.1:0",
  handlers = list(nanonext::handler_stream(
    "/pending",
    on_request = function(connection, request) {
      server_connection <<- connection
      connection$set_status(200L)
      connection$set_header("Content-Type", "text/event-stream")
      connection$send(nanonext::format_sse(data = "ready"))
    }
  ))
)
expect_equal(server$start(), 0L)

client <- rho_httr2_http_client(
  timeout_ms = worker_timeout_ms,
  compute = worker_compute
)
events <- rho_sse_connect(
  client,
  rho_http_request(
    "GET",
    paste0(server$url, "/pending"),
    timeout_ms = worker_timeout_ms
  )
)
ready <- rho_stream_next(events) |> rho_await(timeout = worker_timeout_ms)
rho_http_contract_expect_sse_data(ready, "ready")

pending <- rho_stream_next(events)
expect_true(rho_cancel(pending, "test cancellation"))
cancelled <- rho_await(pending, timeout = worker_timeout_ms)
expect_true(S7::S7_inherits(cancelled, RhoCancellation))

ending <- rho_stream_next(events) |> rho_await(timeout = worker_timeout_ms)
expect_true(S7::S7_inherits(ending, RhoStreamEnd))
expect_equal(server_connection$close(), 0L)
expect_true(rho_http_client_close(client))
expect_equal(server$close(), 0L)
