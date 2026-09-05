probe_peer <- function(sequence) {
  config <- tempfile(fileext = ".rds")
  ready <- tempfile()
  saveRDS(sequence, config)
  process <- processx::process$new(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", file.path(probe_directory, "http-probe-peer.R"), config, ready),
    stdout = "|",
    stderr = "|",
    cleanup_tree = TRUE
  )
  deadline <- Sys.time() + 5
  repeat {
    if (file.exists(ready) && file.info(ready)$size > 0L) {
      break
    }
    if (!process$is_alive() || Sys.time() >= deadline) {
      process$kill_tree()
      stop("HTTP peer did not start: ", process$read_all_error())
    }
    Sys.sleep(0.005)
  }
  port <- readLines(ready, warn = FALSE)[[1L]]
  list(
    url = paste0("http://127.0.0.1:", port, "/"),
    close = function() {
      process$wait(1000)
      if (process$is_alive()) {
        process$kill_tree()
      }
      unlink(c(config, ready))
    }
  )
}

probe_write <- function(payload, delay = 0) list(delay = delay, payload = payload)

probe_save <- function(results, path) {
  json <- jsonlite::toJSON(results, auto_unbox = TRUE, null = "null", pretty = TRUE)
  writeLines(json, path)
  cat(json, "\n")
}
