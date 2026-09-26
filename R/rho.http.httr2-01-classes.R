rho_httr2_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

rho_httr2_positive_integer <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) {
      "must be one positive integer"
    }
  }
)

RhoHttr2HttpClient <- S7::new_class(
  "RhoHttr2HttpClient",
  parent = RhoHttpClient,
  properties = list(
    compute = RhoComputeBackend,
    state = S7::class_environment
  ),
  validator = function(self) {
    required <- c("closed", "next_operation_id", "operations")
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      return(sprintf("@state missing field(s): %s", paste(missing, collapse = ", ")))
    }
    if (
      !is.logical(self@state$closed) ||
        length(self@state$closed) != 1L ||
        is.na(self@state$closed)
    ) {
      return("@state$closed must be one logical value")
    }
    if (
      !is.integer(self@state$next_operation_id) ||
        length(self@state$next_operation_id) != 1L ||
        is.na(self@state$next_operation_id) ||
        self@state$next_operation_id <= 0L
    ) {
      return("@state$next_operation_id must be one positive integer")
    }
    if (!is.list(self@state$operations)) {
      "@state$operations must be a list"
    }
  }
)

RhoHttr2HttpOperation <- S7::new_class(
  "RhoHttr2HttpOperation",
  properties = list(
    id = rho_httr2_positive_integer,
    url = rho_httr2_non_empty_string,
    client = RhoHttr2HttpClient,
    token = rho_httr2_non_empty_string,
    state = S7::class_environment
  ),
  validator = function(self) {
    required <- c(
      "worker",
      "worker_monitor",
      "worker_error",
      "socket",
      "active_receive",
      "closed",
      "opened",
      "created_at"
    )
    missing <- setdiff(required, ls(self@state, all.names = TRUE))
    if (length(missing)) {
      return(sprintf("@state missing field(s): %s", paste(missing, collapse = ", ")))
    }
    flags <- c(self@state$closed, self@state$opened)
    if (!is.logical(flags) || length(flags) != 2L || anyNA(flags)) {
      "@state$closed and @state$opened must be logical values"
    }
  }
)

RhoHttr2HttpBodyStream <- S7::new_class(
  "RhoHttr2HttpBodyStream",
  parent = RhoHttpBodyStream,
  properties = list(operation = RhoHttr2HttpOperation)
)

RhoHttr2StreamMessage <- S7::new_class(
  "RhoHttr2StreamMessage",
  abstract = TRUE,
  properties = list(token = rho_httr2_non_empty_string)
)

RhoHttr2HeadMessage <- S7::new_class(
  "RhoHttr2HeadMessage",
  parent = RhoHttr2StreamMessage,
  properties = list(head = RhoHttpResponseHead)
)

RhoHttr2ChunkMessage <- S7::new_class(
  "RhoHttr2ChunkMessage",
  parent = RhoHttr2StreamMessage,
  properties = list(data = S7::class_raw)
)

RhoHttr2EndMessage <- S7::new_class(
  "RhoHttr2EndMessage",
  parent = RhoHttr2StreamMessage
)

RhoHttr2ErrorMessage <- S7::new_class(
  "RhoHttr2ErrorMessage",
  parent = RhoHttr2StreamMessage,
  properties = list(message = rho_httr2_non_empty_string)
)

RhoHttr2WorkerResult <- S7::new_class(
  "RhoHttr2WorkerResult",
  abstract = TRUE
)

RhoHttr2WorkerComplete <- S7::new_class(
  "RhoHttr2WorkerComplete",
  parent = RhoHttr2WorkerResult
)

RhoHttr2WorkerFailure <- S7::new_class(
  "RhoHttr2WorkerFailure",
  parent = RhoHttr2WorkerResult,
  properties = list(message = rho_httr2_non_empty_string)
)
