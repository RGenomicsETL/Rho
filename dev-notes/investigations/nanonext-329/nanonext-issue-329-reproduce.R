probe_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
probe_directory <- dirname(normalizePath(probe_file))
# Rscript nanonext-issue-329-reproduce.R [R-library-path] [output-json-path]
# Optional NANONEXT_329_CASES selects comma-separated scenario names.
args <- commandArgs(trailingOnly = TRUE)
library_path <- if (length(args)) {
  args[[1L]]
} else {
  Sys.getenv("NANONEXT_329_LIB", unset = .libPaths()[[1L]])
}
output <- if (length(args) > 1L) {
  args[[2L]]
} else {
  file.path(probe_directory, "nanonext-issue-329-reproduce.json")
}
.libPaths(c(library_path, .libPaths()))
library(nanonext)
source(file.path(probe_directory, "http-probe-tools.R"))

response <- function(headers, body = charToRaw("abc"), status = "200 OK") {
  if (is.character(body)) {
    body <- charToRaw(body)
  }
  c(
    charToRaw(paste0(
      "HTTP/1.1 ",
      status,
      "\r\n",
      headers,
      if (nzchar(headers)) "\r\n" else "",
      "\r\n"
    )),
    body
  )
}
chunked <- function(body) {
  if (is.character(body)) {
    body <- charToRaw(body)
  }
  c(charToRaw(paste0(sprintf("%x", length(body)), "\r\n")), body, charToRaw("\r\n0\r\n\r\n"))
}
gzip_file <- tempfile()
gz <- gzfile(gzip_file, "wb")
writeBin(charToRaw("abc"), gz)
close(gz)
compressed <- readBin(gzip_file, "raw", file.info(gzip_file)$size)
unlink(gzip_file)

scenarios <- list(
  length_valid = list(probe_write(response("Content-Length: 3"))),
  chunked_valid = list(probe_write(response("Transfer-Encoding: chunked", chunked("abc")))),
  interim_103 = list(probe_write(c(
    response("Link: </a>; rel=preload", "", "103 Early Hints"),
    response("Content-Length: 3")
  ))),
  interim_100_103 = list(probe_write(c(
    response("", "", "100 Continue"),
    response("Link: </a>; rel=preload", "", "103 Early Hints"),
    response("Content-Length: 3")
  ))),
  te_chunked_gzip = list(probe_write(response("Transfer-Encoding: chunked, gzip", chunked("abc")))),
  te_gzip_chunked = list(probe_write(response(
    "Transfer-Encoding: gzip, chunked",
    chunked(compressed)
  ))),
  te_gzip_only = list(probe_write(response("Transfer-Encoding: gzip", compressed))),
  te_chunked_duplicate = list(probe_write(response(
    "Transfer-Encoding: chunked, chunked",
    chunked("abc")
  ))),
  length_negative = list(probe_write(response("Content-Length: -1"))),
  length_nondecimal = list(probe_write(response("Content-Length: 3x"))),
  length_conflicting_fields = list(probe_write(response("Content-Length: 3\r\nContent-Length: 4"))),
  length_conflicting_list = list(probe_write(response("Content-Length: 3, 4"))),
  length_identical_fields = list(probe_write(response("Content-Length: 3\r\nContent-Length: 3"))),
  length_overflow = list(probe_write(response("Content-Length: 18446744073709551616"))),
  te_and_length = list(probe_write(response(
    "Transfer-Encoding: chunked\r\nContent-Length: 999",
    chunked("abc")
  ))),
  chunked_invalid_size = list(probe_write(response(
    "Transfer-Encoding: chunked",
    "z\r\nabc\r\n0\r\n\r\n"
  ))),
  chunked_extension_valid = list(probe_write(response(
    "Transfer-Encoding: chunked",
    "3;a=b\r\nabc\r\n0\r\nX-Test: done\r\n\r\n"
  ))),
  chunked_extension_invalid = list(probe_write(response(
    "Transfer-Encoding: chunked",
    "3;\x01\r\nabc\r\n0\r\n\r\n"
  ))),
  slow_chunk_line = c(
    list(probe_write(response("Transfer-Encoding: chunked", ""))),
    lapply(c("1", ";", "x", "=", "1", "\r", "\n", "a\r\n0\r\n\r\n"), function(bytes) {
      probe_write(bytes, 0.04)
    })
  )
)

run <- function(name) {
  peer <- probe_peer(scenarios[[name]])
  on.exit(peer$close())
  started <- proc.time()[["elapsed"]]
  opening <- ncurl_stream_aio(
    peer$url,
    timeout = 1000L,
    buffer = if (name == "slow_chunk_line") 1L else 65536L
  )
  head <- opening[]
  result <- list(case = name, version = as.character(packageVersion("nanonext")))
  if (is_error_value(head)) {
    result$open_error <- as.integer(head)
  } else {
    result$status <- head$status
    result$headers <- head$headers
    result$stream_class <- class(head$stream)
    bytes <- raw()
    receives <- 0L
    receive_started <- proc.time()[["elapsed"]]
    repeat {
      value <- ncurl_stream_recv(
        head$stream,
        timeout = if (name == "slow_chunk_line") 100L else 500L
      )[]
      receives <- receives + 1L
      if (is_error_value(value)) {
        result$receive_error <- as.integer(value)
        break
      }
      bytes <- c(bytes, value$data)
      if (isTRUE(value$complete)) {
        result$complete <- TRUE
        repeated <- ncurl_stream_recv(head$stream, timeout = 100L)[]
        result$repeated_eof <- !is_error_value(repeated) &&
          isTRUE(repeated$complete) &&
          !length(repeated$data)
        break
      }
      if (receives > 4096L) stop("receive safety bound exceeded")
    }
    result$receive_seconds <- proc.time()[["elapsed"]] - receive_started
    result$receives <- receives
    result$body_hex <- paste(format(bytes), collapse = "")
    result$close_first <- as.integer(close(head$stream))
    result$close_second <- as.integer(close(head$stream))
  }
  result$total_seconds <- proc.time()[["elapsed"]] - started
  result
}

wanted <- Sys.getenv("NANONEXT_329_CASES")
selected <- if (nzchar(wanted)) strsplit(wanted, ",", fixed = TRUE)[[1L]] else names(scenarios)
stopifnot(all(selected %in% names(scenarios)))
probe_save(lapply(selected, run), output)
