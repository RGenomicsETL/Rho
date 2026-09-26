rho_httr2_http_client <- function(
  headers = list(),
  timeout_ms = 30000L,
  stream_buffer_size = 65536L,
  max_error_body_bytes = 1048576L,
  compute = rho_mirai_backend()
) {
  if (!requireNamespace("httr2", quietly = TRUE) || !requireNamespace("curl", quietly = TRUE)) {
    stop("Packages 'httr2' and 'curl' are required for the httr2 HTTP backend", call. = FALSE)
  }
  state <- new.env(parent = emptyenv())
  state$closed <- FALSE
  state$next_operation_id <- 1L
  state$operations <- list()
  RhoHttr2HttpClient(
    headers = headers,
    timeout_ms = as.integer(timeout_ms),
    stream_buffer_size = as.integer(stream_buffer_size),
    max_error_body_bytes = as.integer(max_error_body_bytes),
    compute = compute,
    state = state
  )
}

rho_httr2_request <- function(payload) {
  request <- httr2::request(payload@url)
  request <- httr2::req_method(request, payload@method)
  if (length(payload@headers)) {
    request <- do.call(
      httr2::req_headers,
      c(list(request), payload@headers)
    )
  }
  if (!is.null(payload@data)) {
    request <- httr2::req_body_raw(request, payload@data)
  }
  httr2::req_error(request, is_error = function(response) FALSE)
}

rho_httr2_complete_request <- function(payload) {
  rho_httr2_request(payload) |>
    httr2::req_timeout(payload@timeout_ms / 1000)
}

rho_httr2_response_headers <- function(response) {
  unclass(as.list(httr2::resp_headers(response)))
}

rho_httr2_response_head <- function(response) {
  RhoHttpResponseHead(
    status = as.integer(httr2::resp_status(response)),
    headers = rho_httr2_response_headers(response),
    url = httr2::resp_url(response)
  )
}

rho_httr2_complete_worker <- function(payload) {
  tryCatch(
    {
      response <- httr2::req_perform(rho_httr2_complete_request(payload))
      data <- httr2::resp_body_raw(response)
      if (payload@convert) {
        data <- rawToChar(data)
      }
      RhoHttpResponse(
        status = as.integer(httr2::resp_status(response)),
        headers = rho_httr2_response_headers(response),
        data = data,
        url = httr2::resp_url(response)
      )
    },
    error = function(error) {
      RhoHttpTransportError(
        message = sprintf("httr2 request failed: %s", conditionMessage(error)),
        url = payload@url,
        parent = error
      )
    }
  )
}

rho_httr2_send_message <- function(socket, message) {
  sent <- nanonext::send(socket, message, mode = "serial")
  !nanonext::is_error_value(sent)
}

rho_httr2_worker_message <- function(value, default) {
  message <- paste(as.character(value), collapse = " ")
  if (!length(message) || is.na(message) || !nzchar(message)) {
    default
  } else {
    message
  }
}

rho_httr2_curl_response_head <- function(handle, fallback_url) {
  metadata <- curl::handle_data(handle)
  status <- metadata$status_code
  if (is.null(status)) {
    status <- NA_integer_
  }
  status <- as.integer(status)
  if (is.na(status) || status < 100L) {
    return(RhoHttpTransportError(
      message = "curl has not received a final HTTP response head",
      url = fallback_url,
      parent = NULL
    ))
  }
  header_bytes <- metadata$headers
  if (is.null(header_bytes)) {
    header_bytes <- raw()
  }
  headers <- curl::parse_headers_list(header_bytes)
  url <- metadata$url
  if (is.null(url)) {
    url <- fallback_url
  }
  RhoHttpResponseHead(
    status = status,
    headers = headers,
    url = url
  )
}

rho_httr2_curl_handle <- function(payload, buffer_bytes) {
  handle <- curl::new_handle()
  options <- list(
    url = payload@url,
    customrequest = payload@method,
    timeout_ms = payload@timeout_ms,
    connecttimeout_ms = payload@timeout_ms,
    buffersize = as.integer(buffer_bytes)
  )
  if (identical(payload@method, "HEAD")) {
    options$nobody <- TRUE
  }
  if (!is.null(payload@data)) {
    options$postfields <- payload@data
    options$postfieldsize_large <- as.double(length(payload@data))
  }
  curl::handle_setopt(handle, .list = options)
  if (length(payload@headers)) {
    curl::handle_setheaders(handle, .list = payload@headers)
  }
  handle
}

rho_httr2_stream_worker <- function(address, token, payload, buffer_bytes) {
  socket <- nanonext::socket("pair", dial = address)
  on.exit(close(socket), add = TRUE)

  tryCatch(
    {
      state <- new.env(parent = emptyenv())
      state$head_sent <- FALSE
      state$failure <- NULL
      handle <- rho_httr2_curl_handle(payload, buffer_bytes)
      pool <- curl::new_pool(total_con = 1L, host_con = 1L)

      send_head <- function() {
        if (state$head_sent) {
          return(TRUE)
        }
        head <- rho_httr2_curl_response_head(handle, payload@url)
        if (S7::S7_inherits(head, RhoHttpTransportError)) {
          state$failure <- head@message
          return(FALSE)
        }
        state$head_sent <- rho_httr2_send_message(
          socket,
          RhoHttr2HeadMessage(token = token, head = head)
        )
        if (!state$head_sent) {
          state$failure <- "Could not relay the response head"
          return(FALSE)
        }
        TRUE
      }

      curl::multi_add(
        handle,
        pool = pool,
        data = function(bytes, finalize = FALSE) {
          if (!length(bytes)) {
            return(invisible(TRUE))
          }
          if (!send_head()) {
            curl::multi_cancel(handle)
            return(invisible(FALSE))
          }
          if (
            !rho_httr2_send_message(
              socket,
              RhoHttr2ChunkMessage(token = token, data = bytes)
            )
          ) {
            state$failure <- "Could not relay a response-body chunk"
            curl::multi_cancel(handle)
          }
          invisible(TRUE)
        },
        done = function(response) {
          if (!send_head()) {
            curl::multi_cancel(handle)
            return(invisible(FALSE))
          }
          if (
            !rho_httr2_send_message(
              socket,
              RhoHttr2EndMessage(token = token)
            )
          ) {
            state$failure <- "Could not relay response completion"
          }
          invisible(TRUE)
        },
        fail = function(message) {
          state$failure <- rho_httr2_worker_message(
            message,
            "curl could not complete the HTTP stream"
          )
          invisible(TRUE)
        }
      )
      curl::multi_run(pool = pool)
      if (!is.null(state$failure)) {
        rho_httr2_send_message(
          socket,
          RhoHttr2ErrorMessage(token = token, message = state$failure)
        )
        return(RhoHttr2WorkerFailure(message = state$failure))
      }
      RhoHttr2WorkerComplete()
    },
    error = function(error) {
      message <- sprintf(
        "curl stream failed: %s",
        rho_httr2_worker_message(error, "unknown worker error")
      )
      rho_httr2_send_message(
        socket,
        RhoHttr2ErrorMessage(token = token, message = message)
      )
      RhoHttr2WorkerFailure(message = message)
    }
  )
}
