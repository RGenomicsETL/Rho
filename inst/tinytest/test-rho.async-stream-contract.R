# Generated from inst/tinytest/rmd/rho.async-stream-contract.Rmd; do not edit.

library(tinytest)
library(rho)

RhoProbeStream <- S7::new_class("RhoProbeStream", parent = RhoStream)

rho_probe_stream <- function(values) {
  RhoProbeStream(state = rho_new_state(
    values = values,
    index = 0L,
    timeouts = list(),
    closed = FALSE,
    created_at = Sys.time()
  ))
}

S7::method(rho_stream_next, RhoProbeStream) <- function(
  stream,
  timeout = NULL,
  ...
) {
  stream@state$timeouts[[length(stream@state$timeouts) + 1L]] <- timeout
  if (isTRUE(stream@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  stream@state$index <- stream@state$index + 1L
  if (stream@state$index > length(stream@state$values)) {
    stream@state$closed <- TRUE
    return(rho_task(rho_stream_end()))
  }
  rho_task(rho_stream_value(stream@state$values[[stream@state$index]]))
}

S7::method(rho_stream_close, RhoProbeStream) <- function(stream, ...) {
  stream@state$closed <- TRUE
  invisible(TRUE)
}

RhoProbeDuplex <- S7::new_class("RhoProbeDuplex", parent = RhoDuplex)

rho_probe_duplex <- function() {
  RhoProbeDuplex(state = rho_new_state(
    sent = list(),
    closed = FALSE,
    created_at = Sys.time()
  ))
}

S7::method(rho_stream_next, RhoProbeDuplex) <- function(stream, timeout = NULL, ...) {
  rho_task(rho_stream_end())
}

S7::method(rho_duplex_send, RhoProbeDuplex) <- function(
  duplex,
  value,
  timeout = NULL,
  ...
) {
  duplex@state$sent[[length(duplex@state$sent) + 1L]] <- list(
    value = value,
    timeout = timeout
  )
  rho_task(NULL)
}

duplex <- rho_probe_duplex()
sent <- rho_duplex_send(duplex, "outbound", timeout = 29L)

expect_true(S7::S7_inherits(duplex, RhoDuplex))
expect_true(S7::S7_inherits(sent, RhoTask))
expect_null(rho_await(sent, timeout = 1000L))
expect_equal(duplex@state$sent, list(list(value = "outbound", timeout = 29L)))

source <- rho_probe_stream(list(2L))
mapped <- rho_stream_map(source, function(value) value * 3L)
item <- rho_stream_next(mapped, timeout = 37L) |>
  rho_await(timeout = 1000L)

expect_equal(item@value, 6L)
expect_equal(source@state$timeouts[[1L]], 37L)
expect_true(rho_stream_close(mapped))
expect_true(source@state$closed)
expect_true(S7::S7_inherits(
  rho_stream_next(mapped, timeout = 37L) |> rho_await(timeout = 1000L),
  RhoStreamEnd
))

source <- rho_probe_stream(list(1L, 2L))
flat <- rho_stream_flat_map(source, function(value) {
  if (value == 1L) list() else list(value, value + 1L)
})
item <- rho_stream_next(flat, timeout = 41L) |>
  rho_await(timeout = 1000L)

expect_equal(item@value, 2L)
expect_equal(source@state$timeouts, list(41L, 41L))
expect_true(rho_stream_close(flat))
expect_true(source@state$closed)

source <- rho_probe_stream(list("value"))
stream <- rho_stream_from_task(rho_task(source))
item <- rho_stream_next(stream, timeout = 53L) |>
  rho_await(timeout = 1000L)

expect_equal(item@value, "value")
expect_equal(source@state$timeouts[[1L]], 53L)

source <- rho_probe_stream(list("unused"))
stream <- rho_stream_from_task(rho_task(source))

expect_true(rho_stream_close(stream))
later::run_now(0.05)
expect_true(source@state$closed)
expect_true(S7::S7_inherits(
  rho_stream_next(stream) |> rho_await(timeout = 1000L),
  RhoStreamEnd
))

pending <- rho_task_from_promise(
  promises::promise(function(resolve, reject) NULL),
  label = "pending-stream"
)
stream <- rho_stream_from_task(pending)
result <- rho_stream_collect(stream, timeout = 10L)

expect_true(S7::S7_inherits(result, RhoTimeoutError))
expect_false(rho_pending(pending))
