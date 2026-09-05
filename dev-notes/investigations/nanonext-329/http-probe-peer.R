# Independent base-R HTTP peer. Input is a serialized list of delayed writes.
args <- commandArgs(trailingOnly = TRUE)
sequence <- readRDS(args[[1L]])
listener <- NULL
for (port in sample(30000:60000, 100L)) {
  listener <- tryCatch(serverSocket(port), error = function(error) NULL)
  if (!is.null(listener)) break
}
stopifnot(!is.null(listener))
writeLines(as.character(port), args[[2L]])
peer <- socketAccept(listener, blocking = FALSE, open = "a+b", timeout = 5)
request <- raw()
deadline <- Sys.time() + 5
repeat {
  request <- c(request, readBin(peer, "raw", 8192L))
  if (grepl("\r\n\r\n", rawToChar(request), fixed = TRUE)) {
    break
  }
  stopifnot(Sys.time() < deadline, length(request) < 65536L)
  Sys.sleep(0.001)
}
for (part in sequence) {
  Sys.sleep(part$delay)
  payload <- if (is.function(part$payload)) part$payload() else part$payload
  if (is.character(payload)) {
    payload <- charToRaw(payload)
  }
  # A rejected or cancelled response can close the connection during a write.
  sent <- tryCatch(
    {
      suppressWarnings(writeBin(payload, peer))
      flush(peer)
      TRUE
    },
    error = function(error) FALSE
  )
  if (!sent) break
}
close(peer)
close(listener)
