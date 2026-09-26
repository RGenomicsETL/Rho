rho_http_client <- function(
  headers = list(),
  timeout_ms = 30000L,
  tls = nanonext::tls_config(),
  stream_buffer_size = 65536L,
  max_error_body_bytes = 1048576L
) {
  RhoNanonextHttpClient(
    headers = headers,
    timeout_ms = as.integer(timeout_ms),
    tls = tls,
    stream_buffer_size = as.integer(stream_buffer_size),
    max_error_body_bytes = as.integer(max_error_body_bytes)
  )
}

rho_http_request <- function(
  method,
  url,
  headers = list(),
  body = NULL,
  timeout_ms = 30000L,
  response_headers = character(),
  convert = TRUE
) {
  RhoHttpRequest(
    method = toupper(method),
    url = url,
    headers = headers,
    body = body,
    timeout_ms = as.integer(timeout_ms),
    response_headers = response_headers,
    convert = isTRUE(convert)
  )
}

rho_ws_request <- function(
  url,
  headers = list(),
  timeout_ms = 30000L,
  textframes = TRUE
) {
  RhoWebSocketRequest(
    url = url,
    headers = headers,
    timeout_ms = as.integer(timeout_ms),
    textframes = isTRUE(textframes)
  )
}

rho_http_payload <- S7::new_generic(
  "rho_http_payload",
  c("client", "request"),
  function(client, request, ...) S7::S7_dispatch()
)

S7::method(rho_http_payload, list(RhoHttpClient, RhoHttpRequest)) <- function(
  client,
  request,
  ...
) {
  headers <- c(
    rho_normalize_http_headers(client@headers),
    rho_normalize_http_headers(request@headers)
  )
  encoded <- rho_encode_http_body(request@body, headers)
  RhoHttpPayload(
    method = request@method,
    url = request@url,
    headers = as.list(encoded$headers %||% character()),
    data = encoded$data,
    timeout_ms = request@timeout_ms %||% client@timeout_ms,
    response_headers = request@response_headers,
    convert = request@convert
  )
}

rho_http_send <- S7::new_generic(
  "rho_http_send",
  c("client", "request"),
  function(client, request, ...) S7::S7_dispatch()
)

rho_http_open_execution <- S7::new_generic(
  "rho_http_open_execution",
  "client",
  function(client, ...) S7::S7_dispatch()
)

S7::method(rho_http_open_execution, RhoHttpClient) <- function(client, ...) {
  RhoHttpCallerOpen(
    reason = paste(
      "No method declares asynchronous response-head opening for",
      class(client)[[1L]]
    )
  )
}

S7::method(rho_http_open_execution, RhoNanonextHttpClient) <- function(client, ...) {
  RhoHttpAioOpen(
    reason = paste(
      "nanonext::ncurl_stream_aio() opens the connection and response head",
      "through a cancellable Aio"
    )
  )
}

S7::method(rho_http_send, list(RhoNanonextHttpClient, RhoHttpRequest)) <- function(
  client,
  request,
  ...
) {
  payload <- rho_http_payload(client, request)
  aio <- nanonext::ncurl_aio(
    url = payload@url,
    convert = payload@convert,
    method = payload@method,
    headers = payload@headers,
    data = payload@data,
    response = payload@response_headers,
    timeout = payload@timeout_ms,
    tls = client@tls
  )
  task <- rho_wrap_aio(aio, collect = function(handle) {
    nanonext::call_aio_(handle)
    list(status = handle$status, headers = handle$headers, data = handle$data)
  })
  rho_then(task, function(res) {
    RhoHttpResponse(
      status = as.integer(res$status %||% NA_integer_),
      headers = res$headers %||% list(),
      data = res$data,
      url = payload@url
    )
  })
}

rho_http_open_stream <- S7::new_generic(
  "rho_http_open_stream",
  c("client", "request"),
  function(client, request, ...) S7::S7_dispatch()
)

S7::method(rho_http_open_stream, list(RhoNanonextHttpClient, RhoHttpRequest)) <- function(
  client,
  request,
  ...
) {
  payload <- rho_http_payload(client, request)
  aio <- nanonext::ncurl_stream_aio(
    url = payload@url,
    method = payload@method,
    headers = payload@headers,
    data = payload@data,
    timeout = payload@timeout_ms,
    tls = client@tls,
    buffer = client@stream_buffer_size
  )
  opening <- rho_wrap_aio(aio)
  stream <- rho_then(opening, function(result) {
    head <- RhoHttpResponseHead(
      status = as.integer(result$status),
      headers = result$headers %||% list(),
      url = payload@url
    )
    state <- new.env(parent = emptyenv())
    state$connection <- result$stream
    state$timeout_ms <- payload@timeout_ms
    state$complete <- FALSE
    state$closed <- FALSE
    state$created_at <- Sys.time()
    RhoNanonextHttpBodyStream(head = head, state = state)
  })
  rho_catch(stream, function(error) {
    RhoHttpTransportError(
      message = sprintf("HTTP stream could not be opened: %s", conditionMessage(error)),
      url = payload@url,
      parent = error
    )
  })
}

rho_http_client_close <- S7::new_generic(
  "rho_http_client_close",
  "client",
  function(client, ...) S7::S7_dispatch()
)

S7::method(rho_http_client_close, RhoHttpClient) <- function(client, ...) {
  invisible(TRUE)
}

rho_ws_connect <- S7::new_generic(
  "rho_ws_connect",
  c("client", "request"),
  function(client, request, ...) S7::S7_dispatch()
)

S7::method(rho_ws_connect, list(RhoNanonextHttpClient, RhoWebSocketRequest)) <- function(
  client,
  request,
  ...
) {
  aio <- nanonext::stream_aio(
    dial = request@url,
    textframes = request@textframes,
    headers = rho_normalize_http_headers(request@headers),
    tls = client@tls,
    buffer = client@stream_buffer_size,
    timeout = request@timeout_ms
  )
  opening <- rho_wrap_aio(aio)
  socket <- rho_then(opening, function(connection) {
    RhoNanonextWebSocket(
      url = request@url,
      state = rho_new_state(
        connection = connection,
        timeout_ms = request@timeout_ms,
        textframes = request@textframes,
        closed = FALSE,
        created_at = Sys.time()
      )
    )
  })
  rho_catch(socket, function(error) {
    RhoWebSocketTransportError(
      message = sprintf("WebSocket could not be opened: %s", conditionMessage(error)),
      url = request@url,
      parent = error
    )
  })
}
