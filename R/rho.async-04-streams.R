rho_stream_value <- function(value) RhoStreamValue(value = value)
rho_stream_end <- function() RhoStreamEnd()

rho_list_stream <- function(values) {
  RhoListStream(
    state = rho_new_state(
      values = values,
      index = 0L,
      closed = FALSE,
      created_at = Sys.time()
    )
  )
}

rho_stream_from_task <- function(task) {
  RhoTaskStream(
    state = rho_new_state(
      task = rho_as_task(task),
      source = NULL,
      closing = NULL,
      closed = FALSE,
      created_at = Sys.time()
    )
  )
}

S7::method(rho_stream_next, RhoListStream) <- function(stream, timeout = NULL, ...) {
  if (isTRUE(stream@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  stream@state$index <- stream@state$index + 1L
  if (stream@state$index > length(stream@state$values)) {
    stream@state$closed <- TRUE
    return(rho_task(rho_stream_end()))
  }
  rho_task(rho_stream_value(stream@state$values[[stream@state$index]]))
}

S7::method(rho_stream_close, RhoStream) <- function(stream, ...) {
  stream@state$closed <- TRUE
  invisible(TRUE)
}

S7::method(rho_stream_collect, RhoStream) <- function(stream, limit = Inf, timeout = NULL, ...) {
  if (
    !is.numeric(limit) ||
      length(limit) != 1L ||
      is.na(limit) ||
      limit < 0 ||
      (!is.infinite(limit) && limit != floor(limit))
  ) {
    rho_signal_contract_violation("`limit` must be one non-negative whole number or Inf")
  }
  timeout <- rho_validate_timeout(timeout)
  values <- list()
  started <- proc.time()[["elapsed"]]
  while (length(values) < limit) {
    remaining <- timeout
    if (!is.null(timeout)) {
      remaining <- timeout - (proc.time()[["elapsed"]] - started) * 1000
      if (remaining <= 0) {
        return(RhoTimeoutError(
          message = "Stream collection deadline elapsed",
          parent = NULL
        ))
      }
    }
    next_task <- rho_stream_next(stream, timeout = remaining)
    item <- rho_await(next_task, timeout = remaining)
    if (S7::S7_inherits(item, RhoAsyncError)) {
      if (S7::S7_inherits(item, RhoTimeoutError)) {
        rho_cancel(next_task, reason = "Stream collection deadline elapsed")
      }
      return(item)
    }
    if (S7::S7_inherits(item, RhoStreamEnd)) {
      break
    }
    if (!S7::S7_inherits(item, RhoStreamValue)) {
      rho_signal_contract_violation(
        "A stream must yield a RhoStreamValue or RhoStreamEnd"
      )
    }
    values[[length(values) + 1L]] <- item@value
  }
  values
}

S7::method(rho_stream_map, RhoStream) <- function(stream, f, ...) {
  if (!is.function(f)) {
    rho_signal_contract_violation("`f` must be a function")
  }
  RhoMappedStream(
    state = rho_new_state(
      source = stream,
      f = f,
      closed = FALSE,
      created_at = Sys.time()
    )
  )
}

S7::method(rho_stream_flat_map, RhoStream) <- function(stream, f, ...) {
  if (!is.function(f)) {
    rho_signal_contract_violation("`f` must be a function")
  }
  RhoFlatMappedStream(
    state = rho_new_state(
      source = stream,
      f = f,
      buffer = list(),
      closed = FALSE,
      created_at = Sys.time()
    )
  )
}

S7::method(rho_stream_next, RhoMappedStream) <- function(stream, timeout = NULL, ...) {
  if (isTRUE(stream@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  rho_then(rho_stream_next(stream@state$source, timeout = timeout), function(item) {
    if (S7::S7_inherits(item, RhoAsyncError)) {
      return(item)
    }
    if (S7::S7_inherits(item, RhoStreamEnd)) {
      stream@state$closed <- TRUE
      return(item)
    }
    rho_stream_value(stream@state$f(item@value))
  })
}

rho_flat_mapped_stream_next <- function(stream, timeout = NULL) {
  if (isTRUE(stream@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  if (length(stream@state$buffer)) {
    value <- stream@state$buffer[[1L]]
    stream@state$buffer <- stream@state$buffer[-1L]
    return(rho_task(rho_stream_value(value)))
  }

  rho_then(rho_stream_next(stream@state$source, timeout = timeout), function(item) {
    if (S7::S7_inherits(item, RhoAsyncError)) {
      return(item)
    }
    if (S7::S7_inherits(item, RhoStreamEnd)) {
      stream@state$closed <- TRUE
      return(item)
    }
    values <- stream@state$f(item@value)
    if (is.null(values)) {
      values <- list()
    }
    if (!is.list(values)) {
      rho_signal_contract_violation("A flat-map function must return a list or NULL")
    }
    stream@state$buffer <- values
    rho_flat_mapped_stream_next(stream, timeout = timeout)
  })
}

S7::method(rho_stream_next, RhoFlatMappedStream) <- function(stream, timeout = NULL, ...) {
  rho_flat_mapped_stream_next(stream, timeout = timeout)
}

S7::method(rho_stream_next, RhoTaskStream) <- function(stream, timeout = NULL, ...) {
  if (isTRUE(stream@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  if (is.null(stream@state$source)) {
    source_task <- stream@state$task
    if (!is.null(timeout)) {
      source_task <- rho_timeout(source_task, timeout)
    }
    return(rho_then(source_task, function(source) {
      if (S7::S7_inherits(source, RhoAsyncError)) {
        return(source)
      }
      if (!rho_is_stream(source)) {
        rho_signal_contract_violation("A task-backed stream must resolve to a RhoStream")
      }
      if (isTRUE(stream@state$closed)) {
        rho_stream_close(source)
        return(rho_stream_end())
      }
      stream@state$source <- source
      rho_stream_next(source, timeout = timeout)
    }))
  }
  rho_then(rho_stream_next(stream@state$source, timeout = timeout), function(item) {
    if (S7::S7_inherits(item, RhoStreamEnd)) {
      stream@state$closed <- TRUE
    }
    item
  })
}

S7::method(rho_stream_close, RhoMappedStream) <- function(stream, ...) {
  if (!isTRUE(stream@state$closed)) {
    rho_stream_close(stream@state$source)
    stream@state$closed <- TRUE
  }
  invisible(TRUE)
}

S7::method(rho_stream_close, RhoFlatMappedStream) <- function(stream, ...) {
  if (!isTRUE(stream@state$closed)) {
    rho_stream_close(stream@state$source)
    stream@state$buffer <- list()
    stream@state$closed <- TRUE
  }
  invisible(TRUE)
}

S7::method(rho_stream_close, RhoTaskStream) <- function(stream, ...) {
  if (isTRUE(stream@state$closed)) {
    return(invisible(FALSE))
  }
  if (is.null(stream@state$source)) {
    cancelled <- rho_cancel(stream@state$task, reason = "stream closed")
    if (!isTRUE(cancelled)) {
      stream@state$closing <- rho_then(stream@state$task, function(source) {
        if (rho_is_stream(source)) {
          rho_stream_close(source)
        }
        NULL
      })
    }
  } else {
    rho_stream_close(stream@state$source)
  }
  stream@state$closed <- TRUE
  invisible(TRUE)
}
