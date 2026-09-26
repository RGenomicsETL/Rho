#' Asynchronous HTTP and server-sent event contracts
#'
#' `RhoHttpRequest` is a typed request value. `HttpClient` requires
#' [rho_http_send()] and [rho_http_open_stream()]. The latter resolves to a
#' `RhoHttpBodyStream` after the response head arrives. `RhoSseDecoder`
#' preserves protocol state across arbitrary byte chunks. [rho_sse_connect()]
#' is the default composition over any `RhoHttpClient` implementation and
#' exposes decoded `RhoSseEvent` values through the common Rho stream protocol.
#' `WebSocketClient` is deliberately separate: an HTTP client does not imply
#' that it can open a WebSocket. `rho_ws_connect()` resolves to a `RhoWebSocket`,
#' an asynchronous duplex whose inbound values use the common stream protocol.
#'
#' `rho_http_client()` constructs the built-in `RhoNanonextHttpClient`. Its TLS
#' configuration is created in memory by `nanonext::tls_config()`; this package
#' does not search the host filesystem for certificate bundles. Another client
#' subclasses `RhoHttpClient`, implements `HttpClient`, and returns its own
#' `RhoHttpBodyStream` subclass with stream-next and close methods. Providers and
#' SSE decoding do not depend on its connection handle.
#'
#' [rho_http_open_execution()] reports where response-head opening runs. The
#' built-in client returns `RhoHttpAioOpen`; a worker-owned implementation may
#' return `RhoHttpWorkerOpen`. The inherited `RhoHttpClient` method deliberately
#' returns `RhoHttpCallerOpen` until a subclass declares asynchronous opening.
#' The latter records that constructing the response stream may occupy the
#' calling R process even though later body reads are asynchronous.
#'
#' @name rho_http_contracts
#' @aliases HttpClient WebSocketClient RhoHttpClient RhoNanonextHttpClient
#' @aliases RhoHttpOpenExecution RhoHttpCancellableOpen RhoHttpAioOpen
#' @aliases RhoHttpWorkerOpen RhoHttpCallerOpen
#' @aliases RhoHttpRequest RhoHttpPayload RhoHttpResponse RhoHttpResponseHead
#' @aliases RhoWebSocketRequest RhoWebSocket RhoNanonextWebSocket
#' @aliases RhoHttpBodyStream RhoNanonextHttpBodyStream
#' @aliases RhoSseEvent RhoSseDecoder RhoSseStream
#' @aliases RhoHttpError RhoHttpTransportError RhoWebSocketTransportError
#' @aliases RhoHttpStatusError
#' @aliases rho_http_client rho_http_request rho_http_payload rho_http_send
#' @aliases rho_http_open_execution rho_http_open_stream rho_http_client_close
#' @aliases rho_ws_request rho_ws_connect
#' @aliases rho_sse_connect
#' @aliases rho_sse_decoder rho_sse_decode rho_sse_parse
#' @export RhoHttpClient
#' @export RhoNanonextHttpClient
#' @export RhoHttpOpenExecution
#' @export RhoHttpCancellableOpen
#' @export RhoHttpAioOpen
#' @export RhoHttpWorkerOpen
#' @export RhoHttpCallerOpen
#' @export RhoHttpRequest
#' @export RhoWebSocketRequest
#' @export RhoHttpPayload
#' @export RhoHttpResponse
#' @export RhoHttpResponseHead
#' @export RhoHttpBodyStream
#' @export RhoNanonextHttpBodyStream
#' @export RhoWebSocket
#' @export RhoNanonextWebSocket
#' @export HttpClient
#' @export WebSocketClient
#' @export RhoSseEvent
#' @export RhoSseDecoder
#' @export RhoSseStream
#' @export RhoHttpError
#' @export RhoHttpTransportError
#' @export RhoWebSocketTransportError
#' @export RhoHttpStatusError
#' @export rho_http_client
#' @export rho_http_request
#' @export rho_http_payload
#' @export rho_http_send
#' @export rho_http_open_execution
#' @export rho_http_open_stream
#' @export rho_http_client_close
#' @export rho_ws_request
#' @export rho_ws_connect
#' @export rho_sse_connect
#' @export rho_sse_decoder
#' @export rho_sse_decode
#' @export rho_sse_parse
#' @importFrom s7contract interface_requirement new_interface
NULL
