rho_task <- function(value) {
  RhoImmediateTask(
    state = rho_new_state(
      status = "resolved",
      value = value,
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

rho_rejected <- function(error) {
  RhoRejectedTask(
    state = rho_new_state(
      status = "rejected",
      error = error,
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

rho_cancellation_value <- function(reason = NULL) {
  RhoCancellation(
    message = reason %||% "Task was cancelled",
    parent = NULL
  )
}

rho_validate_timeout <- function(timeout, argument = "timeout", nullable = TRUE) {
  if (is.null(timeout) && nullable) {
    return(NULL)
  }
  if (
    !is.numeric(timeout) ||
      length(timeout) != 1L ||
      is.na(timeout) ||
      !is.finite(timeout) ||
      timeout < 0
  ) {
    rho_signal_contract_violation(
      "`%s` must be one finite non-negative number of milliseconds",
      argument
    )
  }
  as.double(timeout)
}

rho_observe_task_promise <- function(promise, state) {
  promises::then(
    promise,
    onFulfilled = function(value) {
      if (identical(state$status, "pending")) {
        state$status <- "resolved"
        state$value <- value
      }
      value
    },
    onRejected = function(error) {
      if (identical(state$status, "pending")) {
        state$status <- "rejected"
        state$error <- error
      }
      promises::promise_reject(error)
    }
  )
}

rho_cancellable_task_promise <- function(promise, state) {
  cancellation <- promises::promise(function(resolve, reject) {
    state$cancellation_resolve <- resolve
  })
  rho_observe_task_promise(
    promises::promise_race(.list = list(promise, cancellation)),
    state
  )
}

rho_mark_cancelled <- function(task, reason) {
  if (!rho_pending(task)) {
    return(FALSE)
  }
  task@state$cancelled <- TRUE
  task@state$cancel_reason <- reason
  task@state$status <- "cancelled"
  TRUE
}

rho_resolve_cancellation <- function(task, reason) {
  resolve <- task@state$cancellation_resolve
  if (is.function(resolve)) {
    resolve(rho_cancellation_value(reason))
  }
  invisible(TRUE)
}

rho_cancel_tasks <- function(tasks, reason, except = integer()) {
  failure <- NULL
  for (index in seq_along(tasks)) {
    if (!index %in% except) {
      result <- tryCatch(
        rho_cancel(tasks[[index]], reason = reason),
        error = identity
      )
      if (is.null(failure) && inherits(result, "error")) {
        failure <- result
      }
    }
  }
  if (!is.null(failure)) {
    rho_signal_task_failure(failure)
  }
  invisible(TRUE)
}

rho_task_from_function <- function(fun, label = NULL) {
  if (!is.function(fun)) {
    rho_signal_contract_violation("`fun` must be a function")
  }
  RhoFunctionTask(
    state = rho_new_state(
      status = "pending",
      fun = fun,
      promise = NULL,
      schedule_cancel = NULL,
      cancellation_resolve = NULL,
      active_task = NULL,
      label = label %||% "function-task",
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

rho_task_from_promise <- function(promise, cancel = NULL, label = NULL) {
  if (!promises::is.promise(promise)) {
    rho_signal_contract_violation("`promise` must be a promises promise")
  }
  if (!is.null(cancel) && !is.function(cancel)) {
    rho_signal_contract_violation("`cancel` must be NULL or a function")
  }
  state <- rho_new_state(
    status = "pending",
    promise = promise,
    cancellation_resolve = NULL,
    cancel = cancel,
    value = NULL,
    error = NULL,
    label = label %||% "promise-task",
    created_at = Sys.time(),
    cancelled = FALSE
  )
  state$promise <- rho_cancellable_task_promise(promise, state)
  RhoPromiseTask(state = state)
}

rho_coro_task <- function(fun, ..., label = NULL) {
  fun_expression <- substitute(fun)
  if (!is.function(eval(fun_expression, envir = parent.frame()))) {
    rho_signal_contract_violation("`fun` must be an anonymous function")
  }
  factory_call <- substitute(coro::async(FUN), list(FUN = fun_expression))
  coroutine <- eval(factory_call, envir = parent.frame())
  rho_task_from_promise(
    do.call(coroutine, list(...)),
    label = label %||% "coroutine-task"
  )
}

rho_wrap_aio <- function(aio, collect = nanonext::collect_aio_) {
  if (!nanonext::is_aio(aio)) {
    rho_signal_contract_violation("`aio` must be a nanonext Aio object")
  }
  if (!is.function(collect)) {
    rho_signal_contract_violation("`collect` must be a function")
  }
  RhoNanonextAioTask(
    state = rho_new_state(
      status = "pending",
      handle = aio,
      collect = collect,
      promise = NULL,
      cancellation_resolve = NULL,
      created_at = Sys.time(),
      cancelled = FALSE
    )
  )
}

rho_function_task_promise <- function(task) {
  if (!is.null(task@state$promise)) {
    return(task@state$promise)
  }
  if (isTRUE(task@state$cancelled)) {
    task@state$promise <- promises::promise_resolve(
      rho_cancellation_value(task@state$cancel_reason)
    )
    return(task@state$promise)
  }
  source <- promises::promise(function(resolve, reject) {
    task@state$schedule_cancel <- later::later(function() {
      if (isTRUE(task@state$cancelled)) {
        resolve(rho_cancellation_value(task@state$cancel_reason))
        return()
      }
      tryCatch(
        {
          result <- task@state$fun()
          if (rho_is_task(result)) {
            task@state$active_task <- result
          }
          resolve(rho_promise_result(result))
        },
        error = reject
      )
    })
  })
  task@state$promise <- rho_cancellable_task_promise(source, task@state)
  task@state$promise
}

rho_promise_result <- function(value) {
  if (rho_is_task(value)) {
    return(rho_as_promise(value))
  }
  value
}

rho_await_promise <- function(promise, timeout = NULL) {
  timeout <- rho_validate_timeout(timeout)
  settled <- new.env(parent = emptyenv())
  settled$done <- FALSE
  settled$value <- NULL
  settled$error <- NULL

  promises::then(
    promise,
    onFulfilled = function(value) {
      settled$value <- value
      settled$done <- TRUE
      NULL
    },
    onRejected = function(error) {
      settled$error <- error
      settled$done <- TRUE
      NULL
    }
  )

  started <- proc.time()[["elapsed"]]
  while (!settled$done) {
    wait_seconds <- Inf
    if (!is.null(timeout)) {
      elapsed_ms <- (proc.time()[["elapsed"]] - started) * 1000
      remaining_ms <- as.double(timeout) - elapsed_ms
      if (remaining_ms <= 0) {
        return(RhoTimeoutError(message = "Task deadline elapsed", parent = NULL))
      }
      wait_seconds <- remaining_ms / 1000
    }
    later::run_now(timeoutSecs = wait_seconds)
  }
  if (!is.null(settled$error)) {
    rho_signal_task_failure(settled$error)
  }
  settled$value
}

S7::method(rho_pending, RhoImmediateTask) <- function(x, ...) FALSE
S7::method(rho_pending, RhoRejectedTask) <- function(x, ...) FALSE
S7::method(rho_pending, RhoFunctionTask) <- function(x, ...) identical(x@state$status, "pending")
S7::method(rho_pending, RhoNanonextAioTask) <- function(x, ...) {
  !isTRUE(x@state$cancelled) && nanonext::unresolved(x@state$handle)
}
S7::method(rho_pending, RhoPromiseTask) <- function(x, ...) identical(x@state$status, "pending")

S7::method(rho_await, RhoImmediateTask) <- function(x, timeout = NULL, ...) x@state$value

S7::method(rho_await, RhoRejectedTask) <- function(x, timeout = NULL, ...) {
  rho_signal_task_failure(x@state$error)
}

S7::method(rho_await, RhoFunctionTask) <- function(x, timeout = NULL, ...) {
  rho_await_promise(rho_as_promise(x), timeout)
}

S7::method(rho_await, RhoNanonextAioTask) <- function(x, timeout = NULL, ...) {
  if (isTRUE(x@state$cancelled)) {
    return(rho_cancellation_value(x@state$cancel_reason))
  }
  timeout <- rho_validate_timeout(timeout)
  if (!is.null(timeout) && nanonext::unresolved(x@state$handle)) {
    completed <- promises::then(
      rho_as_promise(x),
      onFulfilled = function(value) TRUE,
      onRejected = function(error) TRUE
    )
    waited <- rho_await_promise(completed, timeout)
    if (S7::S7_inherits(waited, RhoTimeoutError)) {
      return(waited)
    }
    if (isTRUE(x@state$cancelled)) {
      return(rho_cancellation_value(x@state$cancel_reason))
    }
  }
  value <- x@state$collect(x@state$handle)
  x@state$status <- "resolved"
  x@state$value <- value
  value
}

S7::method(rho_await, RhoPromiseTask) <- function(x, timeout = NULL, ...) {
  if (isTRUE(x@state$cancelled)) {
    return(rho_cancellation_value(x@state$cancel_reason))
  }
  rho_await_promise(x@state$promise, timeout)
}

S7::method(rho_as_promise, RhoImmediateTask) <- function(x, ...) {
  promises::promise_resolve(x@state$value)
}
S7::method(rho_as_promise, RhoRejectedTask) <- function(x, ...) {
  error <- x@state$error
  if (!inherits(error, "condition")) {
    error <- simpleError(as.character(error))
  }
  promises::promise_reject(error)
}
S7::method(rho_as_promise, RhoFunctionTask) <- function(x, ...) {
  rho_function_task_promise(x)
}
S7::method(rho_as_promise, RhoNanonextAioTask) <- function(x, ...) {
  if (is.null(x@state$promise)) {
    x@state$promise <- rho_cancellable_task_promise(
      promises::as.promise(x@state$handle),
      x@state
    )
  }
  x@state$promise
}
S7::method(rho_as_promise, RhoPromiseTask) <- function(x, ...) x@state$promise

S7::method(rho_cancel, RhoTask) <- function(x, reason = NULL, ...) {
  if (!rho_mark_cancelled(x, reason)) {
    return(invisible(FALSE))
  }
  rho_resolve_cancellation(x, reason)
  invisible(TRUE)
}

S7::method(rho_cancel, RhoFunctionTask) <- function(x, reason = NULL, ...) {
  if (!rho_mark_cancelled(x, reason)) {
    return(invisible(FALSE))
  }
  on.exit(rho_resolve_cancellation(x, reason), add = TRUE)
  if (is.function(x@state$schedule_cancel)) {
    x@state$schedule_cancel()
  }
  if (rho_is_task(x@state$active_task)) {
    rho_cancel(x@state$active_task, reason)
  }
  invisible(TRUE)
}

S7::method(rho_cancel, RhoNanonextAioTask) <- function(x, reason = NULL, ...) {
  if (!rho_mark_cancelled(x, reason)) {
    return(invisible(FALSE))
  }
  on.exit(rho_resolve_cancellation(x, reason), add = TRUE)
  nanonext::stop_aio(x@state$handle)
  invisible(TRUE)
}

S7::method(rho_cancel, RhoPromiseTask) <- function(x, reason = NULL, ...) {
  if (!rho_mark_cancelled(x, reason)) {
    return(invisible(FALSE))
  }
  on.exit(rho_resolve_cancellation(x, reason), add = TRUE)
  if (!is.null(x@state$cancel)) {
    x@state$cancel(reason)
  }
  invisible(TRUE)
}

S7::method(rho_then, RhoTask) <- function(x, on_fulfilled, on_rejected = NULL, ...) {
  if (!is.function(on_fulfilled)) {
    rho_signal_contract_violation("`on_fulfilled` must be a function")
  }
  if (!is.null(on_rejected) && !is.function(on_rejected)) {
    rho_signal_contract_violation("`on_rejected` must be NULL or a function")
  }
  continuation <- new.env(parent = emptyenv())
  continuation$active <- x
  continuation$cancelled <- FALSE
  continuation$cancel_reason <- NULL
  continue_with <- function(callback, value) {
    if (isTRUE(continuation$cancelled)) {
      return(rho_cancellation_value(continuation$cancel_reason))
    }
    result <- callback(value)
    if (rho_is_task(result)) {
      continuation$active <- result
    }
    rho_promise_result(result)
  }
  promise <- promises::then(
    rho_as_promise(x),
    onFulfilled = function(value) continue_with(on_fulfilled, value),
    onRejected = if (is.null(on_rejected)) {
      NULL
    } else {
      function(error) continue_with(on_rejected, error)
    }
  )
  rho_task_from_promise(
    promise,
    cancel = function(reason) {
      continuation$cancelled <- TRUE
      continuation$cancel_reason <- reason
      rho_cancel(continuation$active, reason)
    },
    label = "then"
  )
}

S7::method(rho_catch, RhoTask) <- function(x, on_rejected, ...) {
  rho_then(x, identity, on_rejected)
}

S7::method(rho_as_task, RhoTask) <- function(x, ...) x
S7::method(rho_as_task, S7::class_any) <- function(x, ...) rho_task(x)

rho_all <- function(tasks) {
  if (!is.list(tasks)) {
    rho_signal_contract_violation("`tasks` must be a list")
  }
  tasks <- lapply(tasks, rho_as_task)
  promises <- lapply(tasks, rho_as_promise)
  joined <- promises::promise_all(.list = promises)
  joined <- promises::then(
    joined,
    onRejected = function(error) {
      rho_cancel_tasks(tasks, "A task in rho_all() failed")
      promises::promise_reject(error)
    }
  )
  rho_task_from_promise(
    joined,
    cancel = function(reason) {
      rho_cancel_tasks(tasks, reason %||% "rho_all() was cancelled")
    },
    label = "all"
  )
}

rho_race_tasks <- function(tasks, label, losing_reason) {
  race_state <- new.env(parent = emptyenv())
  race_state$winner <- NA_integer_
  settle <- function(index) {
    if (!is.na(race_state$winner)) {
      return(invisible(FALSE))
    }
    race_state$winner <- index
    reason <- if (is.function(losing_reason)) {
      losing_reason(index)
    } else {
      losing_reason
    }
    rho_cancel_tasks(tasks, reason, except = index)
    invisible(TRUE)
  }
  promises <- Map(
    function(task, index) {
      force(task)
      force(index)
      promises::then(
        rho_as_promise(task),
        onFulfilled = function(value) {
          settle(index)
          value
        },
        onRejected = function(error) {
          settle(index)
          promises::promise_reject(error)
        }
      )
    },
    tasks,
    seq_along(tasks)
  )
  rho_task_from_promise(
    promises::promise_race(.list = promises),
    cancel = function(reason) {
      rho_cancel_tasks(tasks, reason %||% sprintf("%s was cancelled", label))
    },
    label = label
  )
}

rho_race <- function(tasks) {
  if (!is.list(tasks) || !length(tasks)) {
    rho_signal_contract_violation("`tasks` must be a non-empty list")
  }
  tasks <- lapply(tasks, rho_as_task)
  rho_race_tasks(
    tasks,
    label = "race",
    losing_reason = "Another task settled first"
  )
}

rho_deadline_task <- function(ms) {
  timer <- new.env(parent = emptyenv())
  timer$cancel <- NULL
  deadline <- promises::promise(function(resolve, reject) {
    timer$cancel <- later::later(
      function() {
        resolve(RhoTimeoutError(
          message = "Task deadline elapsed",
          parent = NULL
        ))
      },
      delay = ms / 1000
    )
  })
  rho_task_from_promise(
    deadline,
    cancel = function(reason) {
      if (is.function(timer$cancel)) {
        timer$cancel()
      }
    },
    label = "deadline"
  )
}

rho_timeout <- function(task, ms) {
  ms <- rho_validate_timeout(ms, argument = "ms", nullable = FALSE)
  task <- rho_as_task(task)
  deadline <- rho_deadline_task(ms)
  rho_race_tasks(
    list(task, deadline),
    label = "timeout",
    losing_reason = function(winner) {
      if (winner == 2L) {
        "Task deadline elapsed"
      } else {
        "Task completed before its deadline"
      }
    }
  )
}

rho_poll_pending <- function(delay_ms) RhoPollPending(delay_ms = as.integer(delay_ms))
rho_poll_complete <- function(value) RhoPollComplete(value = value)
rho_poll_failed <- function(error) RhoPollFailed(error = error)

rho_poll <- function(action, timeout_ms) {
  if (!is.function(action)) {
    rho_signal_contract_violation("`action` must be a function")
  }
  timeout_ms <- rho_validate_timeout(
    timeout_ms,
    argument = "timeout_ms",
    nullable = FALSE
  )
  if (timeout_ms == 0) {
    return(rho_task(RhoTimeoutError(
      message = "Polling deadline elapsed",
      parent = NULL
    )))
  }

  state <- new.env(parent = emptyenv())
  state$attempt <- 1L
  state$started <- proc.time()[["elapsed"]]
  state$settled <- FALSE
  state$current <- NULL
  state$timer_cancel <- NULL
  state$resolve <- NULL
  state$reject <- NULL

  finish <- function(value) {
    if (isTRUE(state$settled)) {
      return(invisible(FALSE))
    }
    state$settled <- TRUE
    state$resolve(value)
    invisible(TRUE)
  }
  fail <- function(error) {
    if (isTRUE(state$settled)) {
      return(invisible(FALSE))
    }
    state$settled <- TRUE
    state$reject(error)
    invisible(TRUE)
  }
  remaining <- function() {
    timeout_ms - (proc.time()[["elapsed"]] - state$started) * 1000
  }

  run_attempt <- NULL
  schedule_attempt <- function(delay_ms) {
    state$timer_cancel <- later::later(
      run_attempt,
      delay = delay_ms / 1000
    )
  }
  handle_decision <- function(decision) {
    state$current <- NULL
    if (S7::S7_inherits(decision, RhoTimeoutError)) {
      finish(RhoTimeoutError(
        message = "Polling deadline elapsed",
        parent = decision
      ))
      return(NULL)
    }
    if (S7::S7_inherits(decision, RhoPollComplete)) {
      finish(decision@value)
      return(NULL)
    }
    if (S7::S7_inherits(decision, RhoPollFailed)) {
      finish(decision@error)
      return(NULL)
    }
    if (!S7::S7_inherits(decision, RhoPollPending)) {
      finish(RhoAsyncError(
        message = "Polling action must return a RhoPollDecision value",
        parent = decision
      ))
      return(NULL)
    }
    available <- remaining()
    if (available <= 0) {
      finish(RhoTimeoutError(
        message = "Polling deadline elapsed",
        parent = NULL
      ))
      return(NULL)
    }
    state$attempt <- state$attempt + 1L
    schedule_attempt(min(as.double(decision@delay_ms), available))
    NULL
  }
  run_attempt <- function() {
    state$timer_cancel <- NULL
    if (isTRUE(state$settled)) {
      return(NULL)
    }
    if (remaining() <= 0) {
      finish(RhoTimeoutError(
        message = "Polling deadline elapsed",
        parent = NULL
      ))
      return(NULL)
    }
    result <- tryCatch(action(state$attempt), error = identity)
    if (inherits(result, "error")) {
      fail(result)
      return(NULL)
    }
    available <- remaining()
    if (available <= 0) {
      finish(RhoTimeoutError(
        message = "Polling deadline elapsed",
        parent = NULL
      ))
      return(NULL)
    }
    state$current <- rho_then(
      rho_timeout(rho_as_task(result), available),
      handle_decision,
      function(error) {
        state$current <- NULL
        fail(error)
        NULL
      }
    )
    NULL
  }

  promise <- promises::promise(function(resolve, reject) {
    state$resolve <- resolve
    state$reject <- reject
    schedule_attempt(0)
  })
  rho_task_from_promise(
    promise,
    cancel = function(reason) {
      state$settled <- TRUE
      if (is.function(state$timer_cancel)) {
        state$timer_cancel()
      }
      if (rho_is_task(state$current)) {
        rho_cancel(state$current, reason)
      }
    },
    label = "poll"
  )
}
