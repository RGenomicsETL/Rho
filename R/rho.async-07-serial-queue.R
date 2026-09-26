rho_serial_queue <- function() {
  RhoSerialQueue(
    state = rho_new_state(
      entries = list(),
      active = NULL,
      scheduled = FALSE
    )
  )
}

rho_queue_schedule <- function(queue) {
  if (!is.null(queue@state$active) || isTRUE(queue@state$scheduled)) {
    return(invisible(FALSE))
  }
  queue@state$scheduled <- TRUE
  later::later(function() {
    queue@state$scheduled <- FALSE
    rho_queue_advance(queue)
  })
  invisible(TRUE)
}

rho_queue_finish <- function(queue, entry, value = NULL, error = NULL) {
  if (!identical(queue@state$active, entry)) {
    return(invisible(FALSE))
  }
  if (identical(entry@state$status, "active")) {
    if (is.null(error)) {
      entry@state$status <- "resolved"
      entry@state$resolve(value)
    } else {
      entry@state$status <- "rejected"
      entry@state$reject(error)
    }
  }
  queue@state$active <- NULL
  rho_queue_schedule(queue)
  invisible(TRUE)
}

rho_queue_advance <- function(queue) {
  if (!is.null(queue@state$active)) {
    return(invisible(FALSE))
  }
  while (length(queue@state$entries)) {
    entry <- queue@state$entries[[1L]]
    queue@state$entries <- queue@state$entries[-1L]
    if (identical(entry@state$status, "cancelled")) {
      next
    }

    entry@state$status <- "active"
    queue@state$active <- entry
    result <- tryCatch(entry@action(), error = identity)
    if (inherits(result, "error")) {
      rho_queue_finish(queue, entry, error = result)
      return(invisible(TRUE))
    }
    entry@state$current <- rho_as_task(result)
    entry@state$monitor <- rho_then(
      entry@state$current,
      function(value) {
        rho_queue_finish(queue, entry, value = value)
        NULL
      },
      function(error) {
        rho_queue_finish(queue, entry, error = error)
        NULL
      }
    )
    return(invisible(TRUE))
  }
  invisible(FALSE)
}

rho_queue_cancel_entry <- function(queue, entry, reason) {
  if (!entry@state$status %in% c("queued", "active")) {
    return(invisible(FALSE))
  }
  active <- identical(entry@state$status, "active")
  entry@state$status <- "cancelled"
  if (active && rho_is_task(entry@state$current)) {
    rho_cancel(entry@state$current, reason)
  }
  if (!active) {
    rho_queue_schedule(queue)
  }
  invisible(TRUE)
}

S7::method(rho_enqueue, RhoSerialQueue) <- function(
  queue,
  action,
  label = NULL,
  ...
) {
  if (!is.function(action)) {
    rho_signal_contract_violation("`action` must be a function")
  }
  state <- rho_new_state(
    status = "queued",
    resolve = NULL,
    reject = NULL,
    current = NULL,
    monitor = NULL
  )
  entry <- RhoQueueEntry(
    action = action,
    label = label %||% "queue-entry",
    state = state
  )
  promise <- promises::promise(function(resolve, reject) {
    state$resolve <- resolve
    state$reject <- reject
  })
  task <- rho_task_from_promise(
    promise,
    cancel = function(reason) {
      rho_queue_cancel_entry(queue, entry, reason)
    },
    label = entry@label
  )
  queue@state$entries[[length(queue@state$entries) + 1L]] <- entry
  rho_queue_schedule(queue)
  task
}
