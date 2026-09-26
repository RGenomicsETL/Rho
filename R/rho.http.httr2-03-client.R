rho_httr2_transport_error <- function(url, message, parent = NULL) {
  RhoHttpTransportError(
    message = message,
    url = url,
    parent = parent
  )
}

rho_httr2_register_operation <- function(client, url) {
  state <- new.env(parent = emptyenv())
  state$worker <- NULL
  state$worker_monitor <- NULL
  state$worker_error <- NULL
  state$socket <- NULL
  state$active_receive <- NULL
  state$closed <- FALSE
  state$opened <- FALSE
  state$created_at <- Sys.time()
  operation <- RhoHttr2HttpOperation(
    id = client@state$next_operation_id,
    url = url,
    client = client,
    token = nanonext::random(32L),
    state = state
  )
  client@state$next_operation_id <- operation@id + 1L
  client@state$operations[[as.character(operation@id)]] <- operation
  operation
}

rho_httr2_unregister_operation <- function(operation) {
  operation@client@state$operations[[as.character(operation@id)]] <- NULL
  invisible(TRUE)
}

rho_httr2_close_socket <- function(operation) {
  if (is.null(operation@state$socket)) {
    return(invisible(TRUE))
  }
  closed <- tryCatch(
    {
      close(operation@state$socket)
      TRUE
    },
    error = function(error) error
  )
  operation@state$socket <- NULL
  closed
}

rho_httr2_stop_operation <- function(operation, reason = NULL) {
  if (isTRUE(operation@state$closed)) {
    return(invisible(FALSE))
  }
  operation@state$closed <- TRUE
  receive <- operation@state$active_receive
  operation@state$active_receive <- NULL
  if (S7::S7_inherits(receive, RhoTask)) {
    rho_cancel(receive, reason %||% "httr2 stream closed")
  }
  worker <- operation@state$worker
  if (S7::S7_inherits(worker, RhoTask) && rho_pending(worker)) {
    rho_cancel(worker, reason %||% "httr2 operation closed")
  }
  rho_httr2_close_socket(operation)
  rho_httr2_unregister_operation(operation)
  invisible(TRUE)
}

rho_httr2_finish_operation <- function(operation) {
  if (isTRUE(operation@state$closed)) {
    return(invisible(FALSE))
  }
  operation@state$closed <- TRUE
  operation@state$active_receive <- NULL
  rho_httr2_close_socket(operation)
  rho_httr2_unregister_operation(operation)
  invisible(TRUE)
}

rho_httr2_finish_after_worker <- function(operation, item) {
  rho_then(operation@state$worker, function(result) {
    rho_httr2_finish_operation(operation)
    item
  })
}

rho_httr2_owned_task <- function(operation, task, label) {
  settled <- rho_then(
    task,
    function(value) {
      rho_httr2_unregister_operation(operation)
      operation@state$closed <- TRUE
      value
    },
    function(error) {
      rho_httr2_unregister_operation(operation)
      operation@state$closed <- TRUE
      rho_httr2_transport_error(
        operation@url,
        sprintf("httr2 worker task failed: %s", conditionMessage(error)),
        error
      )
    }
  )
  rho_task_from_promise(
    rho_as_promise(settled),
    cancel = function(reason) {
      rho_cancel(settled, reason)
      rho_httr2_stop_operation(operation, reason)
    },
    label = label
  )
}

rho_httr2_compute_result <- function(result, url) {
  if (S7::S7_inherits(result, RhoComputeErrorValue)) {
    return(rho_httr2_transport_error(
      url,
      sprintf("httr2 worker failed: %s", result@message),
      result@source
    ))
  }
  if (!S7::S7_inherits(result, RhoHttpResponse)) {
    return(rho_httr2_transport_error(
      url,
      "httr2 worker returned an invalid response value",
      result
    ))
  }
  result
}

S7::method(rho_http_open_execution, RhoHttr2HttpClient) <- function(client, ...) {
  RhoHttpWorkerOpen(
    reason = paste(
      "curl's multi callback in the selected rho.compute worker relays the",
      "response head before its first body chunk"
    )
  )
}

S7::method(
  rho_http_send,
  list(RhoHttr2HttpClient, RhoHttpRequest)
) <- function(client, request, ...) {
  if (isTRUE(client@state$closed)) {
    return(rho_task(rho_httr2_transport_error(
      request@url,
      "httr2 client is closed"
    )))
  }
  payload <- rho_http_payload(client, request)
  operation <- rho_httr2_register_operation(client, payload@url)
  worker <- rho_submit_compute(
    client@compute,
    RhoComputeCallSpec(
      worker = rho_httr2_complete_worker,
      arguments = list(payload = payload),
      timeout_ms = payload@timeout_ms
    )
  )
  operation@state$worker <- worker
  translated <- rho_then(
    worker,
    function(result) rho_httr2_compute_result(result, payload@url)
  )
  rho_httr2_owned_task(operation, translated, "httr2-http-request")
}

rho_httr2_stream_address <- function(socket) {
  listeners <- attr(socket, "listener", exact = TRUE)
  if (!length(listeners)) {
    return(NULL)
  }
  attr(listeners[[1L]], "url", exact = TRUE)
}

rho_httr2_receive <- function(operation, timeout_ms) {
  aio <- tryCatch(
    nanonext::recv_aio(
      operation@state$socket,
      mode = "serial",
      timeout = timeout_ms
    ),
    error = function(error) error
  )
  if (inherits(aio, "error")) {
    return(rho_task(rho_httr2_transport_error(
      operation@url,
      sprintf("Could not start httr2 stream receive: %s", conditionMessage(aio)),
      aio
    )))
  }
  received <- rho_wrap_aio(aio)
  rho_then(
    received,
    function(message) {
      if (nanonext::is_error_value(message)) {
        return(rho_httr2_transport_error(
          operation@url,
          sprintf("httr2 stream receive failed: %s", as.character(message)),
          message
        ))
      }
      message
    },
    function(error) {
      rho_httr2_transport_error(
        operation@url,
        sprintf("httr2 stream receive failed: %s", conditionMessage(error)),
        error
      )
    }
  )
}

rho_httr2_monitor_worker <- function(operation) {
  operation@state$worker_monitor <- rho_then(
    operation@state$worker,
    function(result) {
      if (S7::S7_inherits(result, RhoComputeErrorValue)) {
        operation@state$worker_error <- rho_httr2_transport_error(
          operation@url,
          sprintf("httr2 stream worker failed: %s", result@message),
          result@source
        )
        rho_httr2_close_socket(operation)
      }
      result
    }
  )
  invisible(operation@state$worker_monitor)
}

rho_httr2_message_token <- function(message, operation) {
  if (!S7::S7_inherits(message, RhoHttr2StreamMessage)) {
    return(rho_httr2_transport_error(
      operation@url,
      "httr2 worker returned an invalid stream message",
      message
    ))
  }
  if (!identical(message@token, operation@token)) {
    return(rho_httr2_transport_error(
      operation@url,
      "httr2 worker returned a stream message with the wrong token",
      message
    ))
  }
  message
}

rho_httr2_open_message <- S7::new_generic(
  "rho_httr2_open_message",
  "message",
  function(message, operation, ...) S7::S7_dispatch()
)

S7::method(rho_httr2_open_message, RhoHttr2HeadMessage) <- function(
  message,
  operation,
  ...
) {
  operation@state$opened <- TRUE
  operation@state$active_receive <- NULL
  RhoHttr2HttpBodyStream(
    head = message@head,
    state = operation@state,
    operation = operation
  )
}

S7::method(rho_httr2_open_message, RhoHttr2ErrorMessage) <- function(
  message,
  operation,
  ...
) {
  rho_httr2_finish_after_worker(
    operation,
    rho_httr2_transport_error(operation@url, message@message, message)
  )
}

S7::method(rho_httr2_open_message, RhoHttpTransportError) <- function(
  message,
  operation,
  ...
) {
  rho_httr2_stop_operation(operation, message@message)
  message
}

S7::method(rho_httr2_open_message, S7::class_any) <- function(
  message,
  operation,
  ...
) {
  error <- rho_httr2_transport_error(
    operation@url,
    "httr2 worker did not begin with a response head",
    message
  )
  rho_httr2_stop_operation(operation, error@message)
  error
}

S7::method(
  rho_http_open_stream,
  list(RhoHttr2HttpClient, RhoHttpRequest)
) <- function(client, request, ...) {
  if (isTRUE(client@state$closed)) {
    return(rho_task(rho_httr2_transport_error(
      request@url,
      "httr2 client is closed"
    )))
  }
  payload <- rho_http_payload(client, request)
  operation <- rho_httr2_register_operation(client, payload@url)
  socket <- tryCatch(
    nanonext::socket("pair", listen = "tcp://127.0.0.1:0"),
    error = function(error) error
  )
  if (inherits(socket, "error")) {
    rho_httr2_unregister_operation(operation)
    operation@state$closed <- TRUE
    return(rho_task(rho_httr2_transport_error(
      payload@url,
      sprintf("Could not open httr2 relay socket: %s", conditionMessage(socket)),
      socket
    )))
  }
  operation@state$socket <- socket
  address <- rho_httr2_stream_address(socket)
  if (is.null(address)) {
    rho_httr2_stop_operation(operation, "Relay socket has no listener address")
    return(rho_task(rho_httr2_transport_error(
      payload@url,
      "httr2 relay socket has no listener address"
    )))
  }

  operation@state$worker <- rho_submit_compute(
    client@compute,
    RhoComputeCallSpec(
      worker = rho_httr2_stream_worker,
      arguments = list(
        address = address,
        token = operation@token,
        payload = payload,
        buffer_bytes = client@stream_buffer_size
      ),
      timeout_ms = NULL
    )
  )
  rho_httr2_monitor_worker(operation)

  received <- rho_httr2_receive(operation, payload@timeout_ms)
  operation@state$active_receive <- received
  opening <- rho_then(received, function(message) {
    if (!S7::S7_inherits(message, RhoHttpTransportError)) {
      message <- rho_httr2_message_token(message, operation)
    }
    rho_httr2_open_message(message, operation)
  })
  rho_task_from_promise(
    rho_as_promise(opening),
    cancel = function(reason) {
      rho_cancel(opening, reason)
      rho_httr2_stop_operation(operation, reason)
    },
    label = "httr2-http-stream-open"
  )
}

rho_httr2_stream_message <- S7::new_generic(
  "rho_httr2_stream_message",
  "message",
  function(message, operation, ...) S7::S7_dispatch()
)

S7::method(rho_httr2_stream_message, RhoHttr2ChunkMessage) <- function(
  message,
  operation,
  ...
) {
  operation@state$active_receive <- NULL
  rho_stream_value(message@data)
}

S7::method(rho_httr2_stream_message, RhoHttr2EndMessage) <- function(
  message,
  operation,
  ...
) {
  operation@state$active_receive <- NULL
  rho_httr2_finish_after_worker(operation, rho_stream_end())
}

S7::method(rho_httr2_stream_message, RhoHttr2ErrorMessage) <- function(
  message,
  operation,
  ...
) {
  operation@state$active_receive <- NULL
  rho_httr2_finish_after_worker(
    operation,
    rho_stream_value(rho_httr2_transport_error(
      operation@url,
      message@message,
      message
    ))
  )
}

S7::method(rho_httr2_stream_message, RhoHttpTransportError) <- function(
  message,
  operation,
  ...
) {
  operation@state$active_receive <- NULL
  rho_httr2_stop_operation(operation, message@message)
  rho_stream_value(message)
}

S7::method(rho_httr2_stream_message, S7::class_any) <- function(
  message,
  operation,
  ...
) {
  operation@state$active_receive <- NULL
  error <- rho_httr2_transport_error(
    operation@url,
    "httr2 worker returned an invalid response-body message",
    message
  )
  rho_httr2_stop_operation(operation, error@message)
  rho_stream_value(error)
}

S7::method(rho_stream_next, RhoHttr2HttpBodyStream) <- function(
  stream,
  timeout = NULL,
  ...
) {
  operation <- stream@operation
  if (isTRUE(operation@state$closed)) {
    return(rho_task(rho_stream_end()))
  }
  timeout_ms <- if (is.null(timeout)) {
    operation@client@timeout_ms
  } else {
    as.integer(timeout)
  }
  received <- rho_httr2_receive(operation, timeout_ms)
  operation@state$active_receive <- received
  next_item <- rho_then(received, function(message) {
    if (!S7::S7_inherits(message, RhoHttpTransportError)) {
      message <- rho_httr2_message_token(message, operation)
    }
    rho_httr2_stream_message(message, operation)
  })
  rho_task_from_promise(
    rho_as_promise(next_item),
    cancel = function(reason) {
      rho_cancel(next_item, reason)
      rho_httr2_stop_operation(operation, reason)
    },
    label = "httr2-http-stream-receive"
  )
}

S7::method(rho_stream_close, RhoHttr2HttpBodyStream) <- function(stream, ...) {
  rho_httr2_stop_operation(stream@operation, "httr2 stream closed")
}

S7::method(rho_http_client_close, RhoHttr2HttpClient) <- function(client, ...) {
  if (isTRUE(client@state$closed)) {
    return(invisible(FALSE))
  }
  client@state$closed <- TRUE
  operations <- unname(client@state$operations)
  for (operation in operations) {
    rho_httr2_stop_operation(operation, "httr2 client closed")
  }
  invisible(TRUE)
}
