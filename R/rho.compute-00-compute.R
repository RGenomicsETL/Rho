rho_compute_arguments <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    if (!length(value)) {
      return()
    }
    argument_names <- names(value)
    if (is.null(argument_names) || anyNA(argument_names) || any(!nzchar(argument_names))) {
      return("must be a list whose elements all have non-empty names")
    }
    if (anyDuplicated(argument_names)) "must not contain duplicate names"
  }
)

rho_compute_timeout <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (is.null(value)) {
      return()
    }
    if (!is.numeric(value) || length(value) != 1L || is.na(value) || value < 0) {
      "must be NULL or one non-negative number of milliseconds"
    }
  }
)

RhoComputeSpec <- S7::new_class(
  "RhoComputeSpec",
  abstract = TRUE,
  properties = list(timeout_ms = rho_compute_timeout)
)

RhoComputeExpressionSpec <- S7::new_class(
  "RhoComputeExpressionSpec",
  parent = RhoComputeSpec,
  properties = list(
    expression = S7::class_any,
    arguments = rho_compute_arguments
  )
)

RhoComputeCallSpec <- S7::new_class(
  "RhoComputeCallSpec",
  parent = RhoComputeSpec,
  properties = list(
    worker = S7::class_function,
    arguments = rho_compute_arguments
  )
)

RhoComputeBackend <- S7::new_class("RhoComputeBackend", abstract = TRUE)
RhoMiraiBackend <- S7::new_class(
  "RhoMiraiBackend",
  parent = RhoComputeBackend,
  properties = list(compute = S7::class_any)
)
RhoMiraiTask <- S7::new_class("RhoMiraiTask", parent = RhoTask)
RhoComputeErrorValue <- S7::new_class(
  "RhoComputeErrorValue",
  properties = list(message = S7::class_character, source = S7::class_any)
)

rho_mirai_backend <- function(compute = NULL) {
  if (!requireNamespace("mirai", quietly = TRUE)) {
    stop("Package 'mirai' is required for the mirai compute backend", call. = FALSE)
  }
  RhoMiraiBackend(compute = compute)
}

rho_submit_compute <- S7::new_generic(
  "rho_submit_compute",
  c("backend", "spec"),
  function(backend, spec, ...) S7::S7_dispatch()
)

S7::method(
  rho_submit_compute,
  list(RhoMiraiBackend, RhoComputeExpressionSpec)
) <- function(backend, spec, ...) {
  if (!requireNamespace("mirai", quietly = TRUE)) {
    stop("Package 'mirai' is required for the mirai compute backend", call. = FALSE)
  }
  expression <- bquote(list(value = .(spec@expression)))
  m <- do.call(
    mirai::mirai,
    list(
      .expr = expression,
      .args = spec@arguments,
      .timeout = spec@timeout_ms,
      .compute = backend@compute
    )
  )
  RhoMiraiTask(
    state = rho_new_state(
      status = "pending",
      handle = m,
      promise_task = NULL,
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

S7::method(
  rho_submit_compute,
  list(RhoMiraiBackend, RhoComputeCallSpec)
) <- function(backend, spec, ...) {
  if (!requireNamespace("mirai", quietly = TRUE)) {
    stop("Package 'mirai' is required for the mirai compute backend", call. = FALSE)
  }
  m <- do.call(
    mirai::mirai,
    list(
      .expr = quote(list(value = do.call(worker, inputs, quote = TRUE))),
      .args = list(worker = spec@worker, inputs = spec@arguments),
      .timeout = spec@timeout_ms,
      .compute = backend@compute
    )
  )
  RhoMiraiTask(
    state = rho_new_state(
      status = "pending",
      handle = m,
      promise_task = NULL,
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

rho_mirai_eval <- function(expr, args = list(), timeout_ms = NULL, compute = NULL) {
  expression <- substitute(expr)
  rho_submit_compute(
    rho_mirai_backend(compute),
    RhoComputeExpressionSpec(
      expression = expression,
      arguments = args,
      timeout_ms = timeout_ms
    )
  )
}

rho_mirai_call <- function(worker, args = list(), timeout_ms = NULL, compute = NULL) {
  rho_submit_compute(
    rho_mirai_backend(compute),
    RhoComputeCallSpec(worker = worker, arguments = args, timeout_ms = timeout_ms)
  )
}

rho_compute_error_value <- function(error) {
  RhoComputeErrorValue(message = as.character(error), source = error)
}

rho_mirai_promise_task <- function(task) {
  if (!is.null(task@state$promise_task)) {
    return(task@state$promise_task)
  }
  promise <- promises::then(
    promises::as.promise(task@state$handle),
    function(envelope) {
      if (!is.list(envelope) || !identical(names(envelope), "value")) {
        return(RhoComputeErrorValue(
          message = "The mirai backend returned an invalid success envelope",
          source = envelope
        ))
      }
      envelope$value
    }
  )
  promise <- promises::catch(
    promise,
    function(error) rho_compute_error_value(error)
  )
  task@state$promise_task <- rho_task_from_promise(
    promise,
    cancel = function(reason) mirai::stop_mirai(task@state$handle),
    label = "mirai"
  )
  task@state$promise_task
}

S7::method(rho_pending, RhoMiraiTask) <- function(x, ...) {
  if (!is.null(x@state$promise_task)) {
    return(rho_pending(x@state$promise_task))
  }
  !isTRUE(x@state$cancelled) && mirai::unresolved(x@state$handle)
}
S7::method(rho_await, RhoMiraiTask) <- function(x, timeout = NULL, ...) {
  rho_await(rho_mirai_promise_task(x), timeout = timeout)
}
S7::method(rho_as_promise, RhoMiraiTask) <- function(x, ...) {
  rho_as_promise(rho_mirai_promise_task(x))
}
S7::method(rho_cancel, RhoMiraiTask) <- function(x, reason = NULL, ...) {
  cancelled <- rho_cancel(rho_mirai_promise_task(x), reason)
  if (isTRUE(cancelled)) {
    x@state$cancelled <- TRUE
    x@state$cancel_reason <- reason
    x@state$status <- "cancelled"
  }
  invisible(cancelled)
}
