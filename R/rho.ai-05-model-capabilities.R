rho_thinking_levels <- c("off", "minimal", "low", "medium", "high", "xhigh", "max")

rho_thinking_level_entry <- function(model, level) {
  mapping <- model@capabilities@thinking_level_map
  position <- match(level, names(mapping))
  if (is.na(position)) {
    return(list(present = FALSE, value = NULL))
  }
  list(present = TRUE, value = mapping[[position]])
}

S7::method(rho_supported_thinking_levels, Model) <- function(model, ...) {
  if (!model@capabilities@reasoning) {
    return("off")
  }
  Filter(
    function(level) {
      entry <- rho_thinking_level_entry(model, level)
      if (entry$present && is.null(entry$value)) {
        return(FALSE)
      }
      if (level %in% c("xhigh", "max")) {
        return(entry$present)
      }
      TRUE
    },
    rho_thinking_levels
  )
}

S7::method(rho_clamp_thinking_level, Model) <- function(model, level, ...) {
  if (!level %in% rho_thinking_levels) {
    rho_signal_contract_violation("Unknown thinking level: %s", level)
  }
  available <- rho_supported_thinking_levels(model)
  if (level %in% available) {
    return(level)
  }
  requested <- match(level, rho_thinking_levels)
  higher <- if (requested < length(rho_thinking_levels)) {
    rho_thinking_levels[seq.int(requested + 1L, length(rho_thinking_levels))]
  } else {
    character()
  }
  supported_higher <- intersect(higher, available)
  if (length(supported_higher)) {
    return(supported_higher[[1L]])
  }
  lower <- if (requested > 1L) rev(rho_thinking_levels[seq_len(requested - 1L)]) else character()
  supported_lower <- intersect(lower, available)
  if (length(supported_lower)) {
    return(supported_lower[[1L]])
  }
  if (length(available)) available[[1L]] else "off"
}

S7::method(rho_map_thinking_level, Model) <- function(model, level, ...) {
  clamped <- rho_clamp_thinking_level(model, level)
  entry <- rho_thinking_level_entry(model, clamped)
  if (entry$present) entry$value else clamped
}

S7::method(rho_model_supports_input, Model) <- function(model, input, ...) {
  input %in% model@capabilities@input
}

S7::method(rho_content_modalities, S7::class_character) <- function(x, ...) {
  if (length(x)) "text" else character()
}

S7::method(rho_content_modalities, TextContent) <- function(x, ...) "text"
S7::method(rho_content_modalities, ThinkingContent) <- function(x, ...) "text"
S7::method(rho_content_modalities, ImageContent) <- function(x, ...) "image"

S7::method(rho_content_modalities, S7::class_list) <- function(x, ...) {
  unique(unlist(lapply(x, rho_content_modalities), use.names = FALSE))
}

S7::method(rho_content_modalities, UserMessage) <- function(x, ...) {
  rho_content_modalities(x@content)
}

S7::method(rho_content_modalities, ToolResultMessage) <- function(x, ...) {
  rho_content_modalities(x@content)
}

S7::method(rho_content_modalities, AssistantMessage) <- function(x, ...) {
  rho_content_modalities(x@content)
}

S7::method(rho_content_modalities, Context) <- function(x, ...) {
  modalities <- rho_content_modalities(x@messages)
  if (nzchar(x@system_prompt)) {
    modalities <- c("text", modalities)
  }
  unique(modalities)
}

S7::method(rho_content_modalities, S7::class_any) <- function(x, ...) character()

S7::method(rho_content_text, S7::class_character) <- function(x, ...) {
  paste(x, collapse = "")
}

S7::method(rho_content_text, TextContent) <- function(x, ...) x@text

S7::method(rho_content_text, S7::class_list) <- function(x, ...) {
  paste(vapply(x, rho_content_text, character(1)), collapse = "")
}

S7::method(rho_content_text, S7::class_any) <- function(x, ...) ""

S7::method(
  rho_validate_model_input,
  list(Model, Context)
) <- function(model, context, ...) {
  modalities <- rho_content_modalities(context)
  unsupported <- setdiff(modalities, model@capabilities@input)
  if (length(unsupported)) {
    return(rho_provider_input_unsupported(model, modalities))
  }
  ModelInputAccepted(model = model, modalities = modalities)
}

S7::method(
  rho_model_supports_transport,
  list(Model, ProviderTransport)
) <- function(model, transport, ...) {
  transport_class <- S7::S7_class(transport)
  any(vapply(
    model@capabilities@transports,
    function(candidate) identical(S7::S7_class(candidate), transport_class),
    logical(1)
  ))
}

S7::method(rho_transport_id, SseTransport) <- function(transport, ...) "sse"
S7::method(rho_transport_id, WebSocketTransport) <- function(transport, ...) "websocket"
S7::method(rho_transport_id, CachedWebSocketTransport) <- function(transport, ...) {
  "websocket-cached"
}
S7::method(rho_transport_id, EmbeddedTransport) <- function(transport, ...) "embedded"
S7::method(rho_transport_id, AutomaticTransport) <- function(transport, ...) "auto"

rho_compile_model_transport <- function(id) {
  transport <- switch(
    id,
    sse = SseTransport(),
    websocket = WebSocketTransport(),
    `websocket-cached` = CachedWebSocketTransport(),
    embedded = EmbeddedTransport(),
    NULL
  )
  if (is.null(transport)) {
    rho_signal_contract_violation(
      "Unknown model transport id: %s",
      id
    )
  }
  transport
}

rho_compile_model_transports <- function(ids) {
  lapply(ids, rho_compile_model_transport)
}
