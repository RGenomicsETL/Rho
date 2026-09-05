args <- commandArgs(trailingOnly = TRUE)
.libPaths(c(args[[1L]], .libPaths()))
library(nanonext)

run_fixture <- function() {
  server <- http_server(
    "http://127.0.0.1:0",
    handlers = list(handler_stream("/", on_request = function(connection, request) {
      connection$send("abc")
    }))
  )
  stopifnot(server$start() == 0L)
  opening <- ncurl_stream_aio(paste0(server$url, "/"), timeout = 1000L)
  deadline <- Sys.time() + 2
  while (unresolved(opening)) {
    if (Sys.time() > deadline) {
      stop("opening exceeded fixture bound")
    }
    later::run_now(0.01)
  }
  head <- opening[]
  stopifnot(!is_error_value(head))
  close(head$stream)
  server$close()
  invisible(NULL)
}

for (iteration in seq_len(20L)) {
  run_fixture()
  gc()
  gc()
  junk <- lapply(seq_len(20000L), function(i) list(i))
  later::run_now(0.01)
  cat("iteration", iteration, "OK\n")
}
