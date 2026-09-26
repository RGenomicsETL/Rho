rho_http_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) "must be one non-empty string"
  }
)

rho_http_positive_integer <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) "must be one positive integer"
  }
)

rho_http_headers <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    if (!length(value)) {
      return()
    }
    header_names <- names(value)
    if (is.null(header_names) || anyNA(header_names) || any(!nzchar(header_names))) {
      return("must have non-empty names")
    }
    valid <- vapply(
      value,
      function(header) {
        is.character(header) && length(header) == 1L && !is.na(header)
      },
      logical(1)
    )
    if (!all(valid)) {
      "must contain one non-missing string for each header"
    }
  }
)

rho_http_response_headers <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    if (!length(value)) {
      return()
    }
    header_names <- names(value)
    if (is.null(header_names) || anyNA(header_names) || any(!nzchar(header_names))) {
      return("must have non-empty names")
    }
    valid <- vapply(
      value,
      function(header) {
        is.character(header) && length(header) >= 1L && !anyNA(header)
      },
      logical(1)
    )
    if (!all(valid)) {
      "must contain one or more non-missing strings for each header"
    }
  }
)

rho_http_body <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    valid_text <- is.character(value) && length(value) == 1L && !is.na(value)
    if (!is.null(value) && !is.raw(value) && !is.list(value) && !valid_text) {
      "must be NULL, raw bytes, one non-missing string, or a list"
    }
  }
)

rho_http_encoded_body <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    valid_text <- is.character(value) && length(value) == 1L && !is.na(value)
    if (!is.null(value) && !is.raw(value) && !valid_text) {
      "must be NULL, raw bytes, or one non-missing string"
    }
  }
)

rho_http_scalar_logical <- S7::new_property(
  S7::class_logical,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing logical value"
    }
  }
)

rho_raw_bytes <- S7::new_property(
  S7::class_raw,
  default = raw()
)

RhoHttpClient <- S7::new_class(
  "RhoHttpClient",
  abstract = TRUE,
  properties = list(
    headers = rho_http_headers,
    timeout_ms = rho_http_positive_integer,
    stream_buffer_size = rho_http_positive_integer,
    max_error_body_bytes = rho_http_positive_integer
  )
)

RhoHttpOpenExecution <- S7::new_class(
  "RhoHttpOpenExecution",
  abstract = TRUE,
  properties = list(reason = rho_http_non_empty_string)
)

RhoHttpCancellableOpen <- S7::new_class(
  "RhoHttpCancellableOpen",
  parent = RhoHttpOpenExecution,
  abstract = TRUE
)

RhoHttpAioOpen <- S7::new_class(
  "RhoHttpAioOpen",
  parent = RhoHttpCancellableOpen
)

RhoHttpWorkerOpen <- S7::new_class(
  "RhoHttpWorkerOpen",
  parent = RhoHttpCancellableOpen
)

RhoHttpCallerOpen <- S7::new_class(
  "RhoHttpCallerOpen",
  parent = RhoHttpOpenExecution
)

RhoNanonextHttpClient <- S7::new_class(
  "RhoNanonextHttpClient",
  parent = RhoHttpClient,
  properties = list(tls = S7::class_any)
)

RhoHttpResponseHead <- S7::new_class(
  "RhoHttpResponseHead",
  properties = list(
    status = S7::class_integer,
    headers = rho_http_response_headers,
    url = rho_http_non_empty_string
  )
)

RhoHttpRequest <- S7::new_class(
  "RhoHttpRequest",
  properties = list(
    method = rho_http_non_empty_string,
    url = rho_http_non_empty_string,
    headers = rho_http_headers,
    body = rho_http_body,
    timeout_ms = rho_http_positive_integer,
    response_headers = S7::class_character,
    convert = rho_http_scalar_logical
  ),
  validator = function(self) {
    if (!toupper(self@method) %in% c("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD")) {
      "@method must be GET, POST, PUT, PATCH, DELETE, or HEAD"
    }
  }
)

RhoHttpPayload <- S7::new_class(
  "RhoHttpPayload",
  properties = list(
    method = rho_http_non_empty_string,
    url = rho_http_non_empty_string,
    headers = rho_http_headers,
    data = rho_http_encoded_body,
    timeout_ms = rho_http_positive_integer,
    response_headers = S7::class_character,
    convert = rho_http_scalar_logical
  )
)

RhoWebSocketRequest <- S7::new_class(
  "RhoWebSocketRequest",
  properties = list(
    url = rho_http_non_empty_string,
    headers = rho_http_headers,
    timeout_ms = rho_http_positive_integer,
    textframes = rho_http_scalar_logical
  )
)

RhoHttpResponse <- S7::new_class(
  "RhoHttpResponse",
  properties = list(
    status = S7::class_integer,
    headers = rho_http_response_headers,
    data = S7::class_any,
    url = S7::class_character
  )
)

RhoSseEvent <- S7::new_class(
  "RhoSseEvent",
  properties = list(
    event = S7::class_character,
    data = S7::class_character,
    id = S7::class_character,
    retry = S7::class_integer
  )
)

RhoSseDecoder <- S7::new_class(
  "RhoSseDecoder",
  properties = list(state = S7::class_environment),
  validator = function(self) {
    required <- c(
      "buffer",
      "started",
      "data",
      "event",
      "last_event_id",
      "retry",
      "closed"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      sprintf("@state missing field(s): %s", paste(missing, collapse = ", "))
    }
  }
)

RhoHttpBodyStream <- S7::new_class(
  "RhoHttpBodyStream",
  parent = RhoStream,
  properties = list(head = RhoHttpResponseHead)
)

RhoNanonextHttpBodyStream <- S7::new_class(
  "RhoNanonextHttpBodyStream",
  parent = RhoHttpBodyStream
)

RhoWebSocket <- S7::new_class(
  "RhoWebSocket",
  parent = RhoDuplex,
  properties = list(url = rho_http_non_empty_string)
)

RhoNanonextWebSocket <- S7::new_class(
  "RhoNanonextWebSocket",
  parent = RhoWebSocket
)

RhoSseStream <- S7::new_class(
  "RhoSseStream",
  parent = RhoStream
)

RhoHttpError <- S7::new_class(
  "RhoHttpError",
  abstract = TRUE,
  properties = list(
    message = rho_http_non_empty_string,
    url = rho_http_non_empty_string
  )
)

RhoHttpTransportError <- S7::new_class(
  "RhoHttpTransportError",
  parent = RhoHttpError,
  properties = list(parent = S7::class_any)
)

RhoWebSocketTransportError <- S7::new_class(
  "RhoWebSocketTransportError",
  parent = RhoHttpError,
  properties = list(parent = S7::class_any)
)

RhoHttpStatusError <- S7::new_class(
  "RhoHttpStatusError",
  parent = RhoHttpError,
  properties = list(
    status = S7::class_integer,
    headers = rho_http_response_headers,
    body = rho_raw_bytes,
    body_truncated = S7::new_property(S7::class_logical, default = FALSE)
  )
)

RhoHttpErrorBody <- S7::new_class(
  "RhoHttpErrorBody",
  properties = list(
    bytes = rho_raw_bytes,
    truncated = rho_http_scalar_logical
  )
)
