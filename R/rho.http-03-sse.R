rho_sse_decoder <- function() {
  state <- new.env(parent = emptyenv())
  state$buffer <- raw()
  state$started <- FALSE
  state$data <- character()
  state$event <- ""
  state$last_event_id <- ""
  state$retry <- NA_integer_
  state$closed <- FALSE
  RhoSseDecoder(state = state)
}

rho_sse_decode <- S7::new_generic(
  "rho_sse_decode",
  c("decoder", "chunk"),
  function(decoder, chunk = raw(), final = FALSE, ...) S7::S7_dispatch()
)

rho_sse_line_text <- function(bytes) {
  if (!length(bytes)) {
    return("")
  }
  nul <- which(bytes == as.raw(0))
  if (length(nul)) {
    replacement <- as.raw(c(0xef, 0xbf, 0xbd))
    parts <- vector("list", length(bytes))
    for (index in seq_along(bytes)) {
      parts[[index]] <- if (index %in% nul) replacement else bytes[[index]]
    }
    bytes <- do.call(c, parts)
  }
  text <- rawToChar(bytes)
  iconv(text, from = "UTF-8", to = "UTF-8", sub = "\uFFFD")
}

rho_sse_strip_bom <- function(bytes) {
  bom <- as.raw(c(0xef, 0xbb, 0xbf))
  if (length(bytes) >= 3L && identical(bytes[seq_len(3L)], bom)) {
    return(bytes[-seq_len(3L)])
  }
  bytes
}

rho_sse_dispatch_event <- function(decoder) {
  state <- decoder@state
  if (!length(state$data)) {
    state$event <- ""
    state$retry <- NA_integer_
    return(NULL)
  }
  event <- RhoSseEvent(
    event = if (nzchar(state$event)) state$event else "message",
    data = paste(state$data, collapse = "\n"),
    id = state$last_event_id,
    retry = state$retry
  )
  state$data <- character()
  state$event <- ""
  state$retry <- NA_integer_
  event
}

rho_sse_process_line <- function(decoder, bytes) {
  state <- decoder@state
  contains_nul <- any(bytes == as.raw(0))
  if (!state$started) {
    bytes <- rho_sse_strip_bom(bytes)
    state$started <- TRUE
  }
  line <- rho_sse_line_text(bytes)
  if (!nzchar(line)) {
    return(rho_sse_dispatch_event(decoder))
  }
  if (startsWith(line, ":")) {
    return(NULL)
  }

  delimiter <- regexpr(":", line, fixed = TRUE)[[1L]]
  if (delimiter < 0L) {
    field <- line
    value <- ""
  } else {
    field <- substr(line, 1L, delimiter - 1L)
    value <- substr(line, delimiter + 1L, nchar(line))
    if (startsWith(value, " ")) {
      value <- substr(value, 2L, nchar(value))
    }
  }

  if (identical(field, "event")) {
    state$event <- value
  } else if (identical(field, "data")) {
    state$data <- c(state$data, value)
  } else if (identical(field, "id") && !contains_nul) {
    state$last_event_id <- value
  } else if (identical(field, "retry") && grepl("^[0-9]+$", value)) {
    state$retry <- as.integer(value)
  }
  NULL
}

rho_sse_take_line <- function(decoder, final) {
  buffer <- decoder@state$buffer
  terminators <- which(buffer == as.raw(0x0a) | buffer == as.raw(0x0d))
  if (!length(terminators)) {
    if (!final || !length(buffer)) {
      return(NULL)
    }
    decoder@state$buffer <- raw()
    return(list(line = buffer, complete = FALSE))
  }

  position <- terminators[[1L]]
  if (buffer[[position]] == as.raw(0x0d) && position == length(buffer) && !final) {
    return(NULL)
  }
  delimiter_length <- if (
    buffer[[position]] == as.raw(0x0d) &&
      position < length(buffer) &&
      buffer[[position + 1L]] == as.raw(0x0a)
  ) {
    2L
  } else {
    1L
  }
  line <- if (position == 1L) raw() else buffer[seq_len(position - 1L)]
  consumed <- position + delimiter_length - 1L
  decoder@state$buffer <- if (consumed == length(buffer)) {
    raw()
  } else {
    buffer[seq.int(consumed + 1L, length(buffer))]
  }
  list(line = line, complete = TRUE)
}

S7::method(
  rho_sse_decode,
  list(RhoSseDecoder, S7::class_character)
) <- function(
  decoder,
  chunk,
  final = FALSE,
  ...
) {
  if (length(chunk) != 1L || is.na(chunk)) {
    rho_signal_contract_violation(
      "An SSE character chunk must be one non-missing string"
    )
  }
  rho_sse_decode(decoder, charToRaw(enc2utf8(chunk)), final = final, ...)
}

S7::method(
  rho_sse_decode,
  list(RhoSseDecoder, S7::class_any)
) <- function(
  decoder,
  chunk,
  final = FALSE,
  ...
) {
  rho_signal_contract_violation(
    "An SSE chunk must be one string or a raw vector"
  )
}

S7::method(
  rho_sse_decode,
  list(RhoSseDecoder, S7::class_raw)
) <- function(
  decoder,
  chunk,
  final = FALSE,
  ...
) {
  if (decoder@state$closed) {
    rho_signal_contract_violation(
      "An SSE decoder cannot receive data after it is finalized"
    )
  }
  decoder@state$buffer <- c(decoder@state$buffer, chunk)

  events <- list()
  repeat {
    item <- rho_sse_take_line(decoder, final = isTRUE(final))
    if (is.null(item)) {
      break
    }
    event <- rho_sse_process_line(decoder, item$line)
    if (!is.null(event)) {
      events[[length(events) + 1L]] <- event
    }
    if (!item$complete) {
      break
    }
  }
  if (isTRUE(final)) {
    decoder@state$closed <- TRUE
  }
  events
}

rho_sse_parse <- function(text) {
  if (!is.character(text)) {
    rho_signal_contract_violation("`text` must be a character vector")
  }
  text <- paste(text, collapse = "\n")
  rho_sse_decode(rho_sse_decoder(), text, final = TRUE)
}

rho_sse_connect <- S7::new_generic(
  "rho_sse_connect",
  c("client", "request"),
  function(client, request, ...) S7::S7_dispatch()
)

rho_http_collect_error_body <- function(stream, limit, bytes = raw()) {
  rho_then(
    rho_stream_next(stream),
    function(item) {
      if (S7::S7_inherits(item, RhoAsyncError)) {
        return(item)
      }
      if (S7::S7_inherits(item, RhoStreamEnd)) {
        return(RhoHttpErrorBody(bytes = bytes, truncated = FALSE))
      }
      if (!S7::S7_inherits(item, RhoStreamValue)) {
        rho_signal_contract_violation(
          "An HTTP body stream must yield a RhoStreamValue or RhoStreamEnd"
        )
      }
      if (S7::S7_inherits(item@value, RhoHttpError)) {
        return(item@value)
      }

      chunk <- item@value
      remaining <- limit - length(bytes)
      if (length(chunk) > remaining) {
        if (remaining > 0L) {
          bytes <- c(bytes, chunk[seq_len(remaining)])
        }
        rho_stream_close(stream)
        return(RhoHttpErrorBody(bytes = bytes, truncated = TRUE))
      }
      rho_http_collect_error_body(stream, limit, c(bytes, chunk))
    }
  )
}

rho_http_status_error_stream <- function(stream, head, limit) {
  rho_then(
    rho_http_collect_error_body(stream, limit),
    function(body) {
      if (S7::S7_inherits(body, RhoAsyncError)) {
        return(rho_list_stream(list(body)))
      }
      if (S7::S7_inherits(body, RhoHttpError)) {
        return(rho_list_stream(list(body)))
      }
      rho_list_stream(list(RhoHttpStatusError(
        message = sprintf("HTTP stream returned status %s", head@status),
        url = head@url,
        status = head@status,
        headers = head@headers,
        body = body@bytes,
        body_truncated = body@truncated
      )))
    }
  )
}

S7::method(rho_sse_connect, list(RhoHttpClient, RhoHttpRequest)) <- function(
  client,
  request,
  ...
) {
  request@headers <- c(request@headers, list(Accept = "text/event-stream"))
  source <- rho_then(rho_http_open_stream(client, request), function(body) {
    if (S7::S7_inherits(body, RhoAsyncError)) {
      return(body)
    }
    if (S7::S7_inherits(body, RhoHttpError)) {
      return(rho_list_stream(list(body)))
    }
    if (!S7::S7_inherits(body, RhoHttpBodyStream)) {
      rho_signal_contract_violation(
        "An HTTP stream opener must yield a RhoHttpBodyStream or typed error"
      )
    }
    head <- body@head
    if (is.na(head@status) || head@status < 200L || head@status >= 300L) {
      return(rho_http_status_error_stream(
        body,
        head,
        client@max_error_body_bytes
      ))
    }

    state <- new.env(parent = emptyenv())
    state$source <- body
    state$decoder <- rho_sse_decoder()
    state$buffer <- list()
    state$closed <- FALSE
    state$created_at <- Sys.time()
    RhoSseStream(state = state)
  })
  rho_stream_from_task(source)
}
