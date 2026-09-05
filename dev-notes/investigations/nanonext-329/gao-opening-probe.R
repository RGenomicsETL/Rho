probe_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
probe_directory <- dirname(normalizePath(probe_file))
# Simulate a synchronous head constructor with call_aio() on the existing fork.
# This measures R callback scheduling, not an implementation of Gao's new API.
if (nzchar(Sys.getenv("NANONEXT_329_LIB"))) {
  .libPaths(c(Sys.getenv("NANONEXT_329_LIB"), .libPaths()))
}
library(nanonext)
library(later)
source(file.path(probe_directory, "http-probe-tools.R"))

run <- function(mode) {
  peer <- probe_peer(list(
    probe_write(
      paste0(
        "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n",
        "Transfer-Encoding: chunked\r\n\r\nb\r\ndata: one\n\n\r\n"
      ),
      0.35
    ),
    probe_write("0\r\n\r\n", 0.35)
  ))
  on.exit(peer$close())
  now <- function() as.numeric(proc.time()[["elapsed"]])
  started <- now()
  elapsed <- function() round((now() - started) * 1000)
  heartbeat <- cancel_at <- cancel_body_at <- NULL
  mark_heartbeat <- later(function() heartbeat <<- elapsed(), 0.05)
  aio <- ncurl_stream_aio(peer$url, timeout = 2000L)
  mark_cancel <- later(
    function() {
      cancel_at <<- elapsed()
      if (mode == "async_cancel") stop_aio(aio)
    },
    0.1
  )
  returned <- elapsed()
  if (mode == "sync") {
    call_aio(aio)
    returned <- elapsed()
  } else {
    deadline <- now() + 3
    while (unresolved(aio)) {
      stopifnot(now() < deadline)
      run_now(0.01)
    }
  }
  head <- aio$data
  result <- list(
    mode = mode,
    open_call_return_ms = returned,
    head_observed_ms = elapsed(),
    heartbeat_before_head_ms = heartbeat,
    cancel_callback_before_head_ms = cancel_at
  )
  mark_heartbeat()
  mark_cancel()
  if (is_error_value(head)) {
    result$opening_error <- as.integer(head)
  } else {
    on.exit(close(head$stream), add = TRUE)
    result$status <- head$status
    first <- ncurl_stream_recv(head$stream, timeout = 2000L)
    call_aio(first)
    result$first_body_ms <- elapsed()
    result$first_body <- rawToChar(first$data$data)
    result$body_still_open <- !first$data$complete
    pending <- ncurl_stream_recv(head$stream, timeout = 2000L)
    cancel <- later(
      function() {
        cancel_body_at <<- elapsed()
        stop_aio(pending)
      },
      0.05
    )
    deadline <- now() + 3
    while (unresolved(pending)) {
      stopifnot(now() < deadline)
      run_now(0.01)
    }
    cancel()
    result$body_cancel_ms <- cancel_body_at
    result$body_cancel_error <- as.integer(pending$data)
  }
  result
}

results <- lapply(c("async", "sync", "async_cancel"), run)
stopifnot(
  !is.null(results[[1L]]$heartbeat_before_head_ms),
  is.null(results[[2L]]$heartbeat_before_head_ms),
  is.null(results[[2L]]$cancel_callback_before_head_ms),
  results[[1L]]$body_cancel_error == 20L,
  results[[2L]]$body_cancel_error == 20L,
  results[[3L]]$opening_error == 20L
)
probe_save(results, file.path(probe_directory, "gao-opening-probe.json"))
