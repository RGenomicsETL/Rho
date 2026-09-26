#' Worker-owned httr2 and curl implementation of the Rho HTTP contract
#'
#' `rho_httr2_http_client()` constructs an `HttpClient` owned by a compute
#' worker. Complete requests use httr2. For a streaming request, the worker
#' uses curl's native multi event loop, captures the final response head before
#' relaying its first body chunk, and sends typed head, raw chunk, completion,
#' or error values over a private localhost NNG socket. The calling process
#' receives those values through `RhoTask` and `RhoStream` without blocking its
#' R event loop.
#'
#' Complete requests also execute through the selected compute backend. Closing
#' a body stream or client closes its NNG socket and cancels the owning compute
#' task. The default compute backend is mirai; callers may supply another
#' `RhoComputeBackend` that preserves the same call specification semantics.
#' [rho_http_open_execution()] returns `RhoHttpWorkerOpen` for this
#' client because connection setup and receipt of the response head occur in
#' that selected worker.
#'
#' @name rho_http_httr2
#' @aliases RhoHttr2HttpClient RhoHttr2HttpBodyStream
#' @aliases rho_httr2_http_client
#' @export RhoHttr2HttpClient
#' @export RhoHttr2HttpBodyStream
#' @export rho_httr2_http_client
NULL
