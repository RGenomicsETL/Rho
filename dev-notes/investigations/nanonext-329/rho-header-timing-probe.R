probe_file <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[[1L]])
probe_directory <- dirname(normalizePath(probe_file))
if (nzchar(Sys.getenv("NANONEXT_329_LIB"))) {
  .libPaths(c(Sys.getenv("NANONEXT_329_LIB"), .libPaths()))
}
library(rho.async)
library(rho.http)
source(file.path(probe_directory, "http-probe-tools.R"))

run <- function(backend) {
  peer <- probe_peer(list(
    probe_write(function() {
      paste0(
        "HTTP/1.1 200 OK\r\nContent-Length: 3\r\nConnection: close\r\n",
        "X-Head-Sent: ",
        sprintf("%.6f", as.numeric(Sys.time())),
        "\r\n\r\n"
      )
    }),
    probe_write("abc", 0.4)
  ))
  on.exit(peer$close())
  if (backend == "httr2") {
    profile <- paste0("rho-header-probe-", Sys.getpid())
    mirai::daemons(1L, .compute = profile)
    on.exit(mirai::daemons(0L, .compute = profile), add = TRUE)
    client <- rho.http.httr2::rho_httr2_http_client(
      compute = rho.compute::rho_mirai_backend(compute = profile)
    )
  } else {
    client <- rho_http_client()
  }
  on.exit(rho_http_client_close(client), add = TRUE)
  request <- rho_http_request("GET", peer$url)
  body <- rho_await(rho_http_open_stream(client, request), timeout = 5000L)
  head_observed <- as.numeric(Sys.time())
  stopifnot(S7::S7_inherits(body, RhoHttpBodyStream))
  on.exit(rho_stream_close(body), add = TRUE)
  headers <- body@head@headers
  sent <- as.numeric(headers[[which(tolower(names(headers)) == "x-head-sent")]])
  item <- rho_await(rho_stream_next(body), timeout = 5000L)
  first_body <- as.numeric(Sys.time())
  stopifnot(S7::S7_inherits(item, RhoStreamValue))
  ending <- rho_await(rho_stream_next(body), timeout = 5000L)
  stopifnot(S7::S7_inherits(ending, RhoStreamEnd))
  list(
    backend = backend,
    status = body@head@status,
    head_after_peer_headers_ms = round((head_observed - sent) * 1000),
    first_body_after_peer_headers_ms = round((first_body - sent) * 1000),
    first_body = rawToChar(item@value)
  )
}

probe_save(
  lapply(c("nanonext", "httr2"), run),
  file.path(probe_directory, "rho-header-timing-probe.json")
)
