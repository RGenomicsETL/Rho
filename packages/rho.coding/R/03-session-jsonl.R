rho_session_adapter_tag <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty stable wire tag"
    }
  }
)

rho_session_adapter_class <- S7::new_property(
  S7::class_any,
  validator = function(value) {
    if (!inherits(value, "S7_class")) "must be an S7 class object"
  }
)

rho_session_adapter_fields <- S7::new_property(
  S7::class_character,
  default = character(),
  validator = function(value) {
    if (length(value) && (is.null(names(value)) || any(!nzchar(names(value))))) {
      return("must name every stable wire field")
    }
    if (anyDuplicated(names(value)) || anyDuplicated(value)) {
      "must map unique wire fields to unique S7 properties"
    }
  }
)

RhoJsonSemanticAdapter <- S7::new_class(
  "RhoJsonSemanticAdapter",
  properties = list(
    tag = rho_session_adapter_tag,
    value_class = rho_session_adapter_class,
    fields = rho_session_adapter_fields
  ),
  validator = function(self) {
    unknown <- setdiff(unname(self@fields), names(self@value_class@properties))
    if (length(unknown)) {
      "@fields must identify properties declared by @value_class"
    }
  }
)

rho_session_codec_adapters <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    if (is.null(names(value)) || any(!nzchar(names(value)))) {
      return("must be a named semantic-adapter registry")
    }
    invalid <- Filter(
      function(adapter) !S7::S7_inherits(adapter, RhoJsonSemanticAdapter),
      value
    )
    if (length(invalid)) {
      return("must contain only RhoJsonSemanticAdapter values")
    }
    tags <- unname(vapply(value, function(adapter) adapter@tag, character(1)))
    if (!identical(names(value), tags) || anyDuplicated(tags)) {
      "names must equal unique stable adapter tags"
    }
  }
)

rho_jsonl_path <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty path"
    }
  }
)

rho_jsonl_timeout <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) {
      "must be one positive integer"
    }
  }
)

rho_session_document_storage <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    supported <- c("logical", "integer", "double", "character", "raw")
    if (length(value) != 1L || is.na(value) || !value %in% supported) {
      "must name one supported R atomic storage mode"
    }
  }
)

rho_session_document_size <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer"
    }
  }
)

rho_session_property_documents <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    if (length(value) && (is.null(names(value)) || any(!nzchar(names(value))))) {
      "must be a named property document list"
    }
  }
)

RhoJsonSessionCodec <- S7::new_class(
  "RhoJsonSessionCodec",
  properties = list(adapters = rho_session_codec_adapters)
)

RhoSessionCodecErrorValue <- S7::new_class(
  "RhoSessionCodecErrorValue",
  parent = rho.agent::RhoSessionJournalErrorValue
)

RhoJsonlSessionJournalErrorValue <- S7::new_class(
  "RhoJsonlSessionJournalErrorValue",
  parent = rho.agent::RhoSessionJournalErrorValue
)

RhoJsonlSessionJournal <- S7::new_class(
  "RhoJsonlSessionJournal",
  properties = list(
    path = rho_jsonl_path,
    identity = rho.agent::RhoSessionIdentity,
    codec = RhoJsonSessionCodec,
    compute = S7::class_any,
    timeout_ms = rho_jsonl_timeout
  )
)

rho_jsonl_position <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0L) {
      "must be one non-negative integer"
    }
  }
)

rho_jsonl_entries <- S7::new_property(S7::class_list, default = list())

rho_jsonl_message <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty message"
    }
  }
)

rho_jsonl_session_id <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty session identifier"
    }
  }
)

rho_jsonl_parent_session_id <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing parent session identifier"
    }
  }
)

RhoJsonlInspection <- S7::new_class(
  "RhoJsonlInspection",
  abstract = TRUE,
  properties = list(
    position = rho_jsonl_position,
    entries = rho_jsonl_entries
  )
)

RhoJsonlEmptyInspection <- S7::new_class(
  "RhoJsonlEmptyInspection",
  parent = RhoJsonlInspection,
  validator = function(self) {
    if (self@position != 0L || length(self@entries)) {
      "must have position zero and no entries"
    }
  }
)

RhoJsonlPresentInspection <- S7::new_class(
  "RhoJsonlPresentInspection",
  parent = RhoJsonlInspection,
  properties = list(
    session_id = rho_jsonl_session_id,
    parent_session_id = rho_jsonl_parent_session_id
  )
)

RhoJsonlWorkerFailure <- S7::new_class(
  "RhoJsonlWorkerFailure",
  abstract = TRUE,
  properties = list(
    message = rho_jsonl_message,
    retryable = S7::class_logical
  )
)

RhoJsonlCorruptFile <- S7::new_class(
  "RhoJsonlCorruptFile",
  parent = RhoJsonlWorkerFailure
)

RhoJsonlIoFailure <- S7::new_class(
  "RhoJsonlIoFailure",
  parent = RhoJsonlWorkerFailure
)

RhoJsonlLockUnavailable <- S7::new_class(
  "RhoJsonlLockUnavailable",
  parent = RhoJsonlWorkerFailure
)

RhoJsonlPositionConflict <- S7::new_class(
  "RhoJsonlPositionConflict",
  properties = list(
    expected = rho_jsonl_position,
    current = rho_jsonl_position
  )
)

RhoJsonlCommitted <- S7::new_class(
  "RhoJsonlCommitted",
  properties = list(
    session_id = rho_jsonl_session_id,
    parent_session_id = rho_jsonl_parent_session_id,
    position = rho_jsonl_position,
    entries = rho_jsonl_entries
  )
)

RhoJsonSessionDocument <- S7::new_class("RhoJsonSessionDocument")

RhoJsonNullDocument <- S7::new_class(
  "RhoJsonNullDocument",
  parent = RhoJsonSessionDocument
)

RhoJsonAtomicDocument <- S7::new_class(
  "RhoJsonAtomicDocument",
  parent = RhoJsonSessionDocument,
  properties = list(
    storage = rho_session_document_storage,
    size = rho_session_document_size,
    values = S7::class_list,
    missing = S7::class_list,
    names_document = S7::class_list
  ),
  validator = function(self) {
    if (length(self@values) != self@size) {
      return("@values must have @size elements")
    }
    scalar_strings <- vapply(
      self@values,
      function(value) is.character(value) && length(value) == 1L && !is.na(value),
      logical(1)
    )
    if (!all(scalar_strings)) {
      return("@values must contain scalar strings")
    }
    values <- unlist(self@values, recursive = FALSE, use.names = FALSE)
    validators <- list(
      logical = function(value) all(value %in% c("TRUE", "FALSE")),
      integer = function(value) {
        parsed <- suppressWarnings(as.integer(value))
        all(grepl("^-?[0-9]+$", value)) && !anyNA(parsed)
      },
      double = function(value) {
        special <- value %in% c("NaN", "Inf", "-Inf")
        parsed <- suppressWarnings(as.double(value))
        all(special | (!is.na(parsed) & is.finite(parsed)))
      },
      character = function(value) TRUE,
      raw = function(value) {
        parsed <- suppressWarnings(as.integer(value))
        all(grepl("^[0-9]+$", value)) &&
          !anyNA(parsed) &&
          all(parsed >= 0L & parsed <= 255L)
      }
    )
    if (!validators[[self@storage]](values)) {
      return("@values are invalid for @storage")
    }
    missing <- unlist(self@missing, recursive = FALSE, use.names = FALSE)
    if (length(missing)) {
      positions <- suppressWarnings(as.integer(missing))
      if (
        !is.numeric(missing) ||
          anyNA(missing) ||
          anyNA(positions) ||
          any(missing != positions)
      ) {
        return("@missing must contain integer positions")
      }
      if (any(positions < 1L | positions > self@size) || anyDuplicated(positions)) {
        return("@missing positions must be unique and within @size")
      }
      if (identical(self@storage, "raw")) {
        return("raw session documents cannot contain missing positions")
      }
    }
  }
)

RhoJsonListDocument <- S7::new_class(
  "RhoJsonListDocument",
  parent = RhoJsonSessionDocument,
  properties = list(
    values = S7::class_list,
    names_document = S7::class_list
  )
)

RhoJsonSemanticDocument <- S7::new_class(
  "RhoJsonSemanticDocument",
  parent = RhoJsonSessionDocument,
  properties = list(
    tag = rho_session_adapter_tag,
    property_documents = rho_session_property_documents
  )
)

rho_encode_session_value <- S7::new_generic(
  "rho_encode_session_value",
  c("codec", "value"),
  function(codec, value, ...) S7::S7_dispatch()
)

rho_decode_session_value <- S7::new_generic(
  "rho_decode_session_value",
  c("codec", "document"),
  function(codec, document, ...) S7::S7_dispatch()
)

rho_encode_atomic_values <- S7::new_generic(
  "rho_encode_atomic_values",
  "value",
  function(value, ...) S7::S7_dispatch()
)

rho_session_codec_error <- function(message, details = list()) {
  RhoSessionCodecErrorValue(
    kind = "session_codec",
    message = message,
    retryable = FALSE,
    details = details
  )
}

rho_jsonl_session_error <- function(message, path, retryable = FALSE, details = list()) {
  RhoJsonlSessionJournalErrorValue(
    kind = "jsonl_session",
    message = message,
    retryable = retryable,
    details = c(list(path = path), details)
  )
}

rho_json_fields <- function(fields = character()) {
  if (!length(fields) || !is.null(names(fields))) {
    return(fields)
  }
  stats::setNames(fields, fields)
}

rho_json_semantic_adapter <- function(tag, class, fields = character()) {
  RhoJsonSemanticAdapter(
    tag = tag,
    value_class = class,
    fields = rho_json_fields(fields)
  )
}

rho_builtin_session_adapters <- function() {
  list(
    rho_json_semantic_adapter(
      "session.message",
      rho.agent::RhoSessionMessageEntry,
      c("id", "timestamp", "parent_id", "message")
    ),
    rho_json_semantic_adapter(
      "session.compaction",
      rho.agent::RhoSessionCompactionEntry,
      c("id", "timestamp", "parent_id", "result", "reason", "will_retry")
    ),
    rho_json_semantic_adapter(
      "session.context_exclusion",
      rho.agent::RhoSessionContextExclusionEntry,
      c("id", "timestamp", "parent_id", "target_entry_id", "reason")
    ),
    rho_json_semantic_adapter(
      "session.reset",
      rho.agent::RhoSessionResetEntry,
      c("id", "timestamp", "parent_id")
    ),
    rho_json_semantic_adapter(
      "session.leaf",
      rho.agent::RhoSessionLeafEntry,
      c("id", "timestamp", "previous_leaf_id", "target_leaf_id")
    ),
    rho_json_semantic_adapter(
      "message.user",
      rho.ai::UserMessage,
      c("content", "timestamp")
    ),
    rho_json_semantic_adapter(
      "message.assistant",
      rho.ai::AssistantMessage,
      c(
        "content",
        "provider",
        "model",
        "stop_reason",
        "usage",
        "context_revision",
        "response_id",
        "timestamp"
      )
    ),
    rho_json_semantic_adapter(
      "message.tool_result",
      rho.ai::ToolResultMessage,
      c(
        "tool_call_id",
        "tool_name",
        "content",
        "details",
        "is_error",
        "terminate",
        "timestamp",
        "added_tool_names"
      )
    ),
    rho_json_semantic_adapter(
      "content.text",
      rho.ai::TextContent,
      c("text", "signature", "annotations")
    ),
    rho_json_semantic_adapter(
      "content.thinking",
      rho.ai::ThinkingContent,
      c("text", "signature", "redacted")
    ),
    rho_json_semantic_adapter(
      "content.image",
      rho.ai::ImageContent,
      c("data", "mime_type")
    ),
    rho_json_semantic_adapter(
      "content.artifact_ref",
      rho.ai::ArtifactRefContent,
      c("artifact_id", "media_type")
    ),
    rho_json_semantic_adapter(
      "content.tool_call",
      rho.ai::ToolCall,
      c("id", "name", "arguments", "arguments_prepared")
    ),
    rho_json_semantic_adapter(
      "content.web_search_call",
      rho.ai::WebSearchCallContent,
      c("id", "status", "action")
    ),
    rho_json_semantic_adapter(
      "content.web_search_result",
      rho.ai::WebSearchResultContent,
      c("call_id", "results", "error")
    ),
    rho_json_semantic_adapter(
      "web_search.result",
      rho.ai::WebSearchResult,
      c("url", "title", "age", "encrypted_content")
    ),
    rho_json_semantic_adapter("operation.pending", rho.ai::OperationPending),
    rho_json_semantic_adapter(
      "operation.in_progress",
      rho.ai::OperationInProgress
    ),
    rho_json_semantic_adapter("operation.completed", rho.ai::OperationCompleted),
    rho_json_semantic_adapter("operation.failed", rho.ai::OperationFailed),
    rho_json_semantic_adapter(
      "web_search.action.unspecified",
      rho.ai::WebSearchActionUnspecified
    ),
    rho_json_semantic_adapter(
      "web_search.action.search",
      rho.ai::WebSearchSearchAction,
      c("queries", "sources")
    ),
    rho_json_semantic_adapter(
      "web_search.action.open_page",
      rho.ai::WebSearchOpenPageAction,
      "url"
    ),
    rho_json_semantic_adapter(
      "web_search.action.find_in_page",
      rho.ai::WebSearchFindInPageAction,
      c("url", "pattern")
    ),
    rho_json_semantic_adapter(
      "web_search.action.unknown",
      rho.ai::WebSearchUnknownAction,
      "payload"
    ),
    rho_json_semantic_adapter(
      "usage.provider",
      rho.ai::ProviderUsage,
      c(
        "input",
        "output",
        "cache_read",
        "cache_write",
        "cache_write_1h",
        "reasoning",
        "total",
        "cost",
        "provider"
      )
    ),
    rho_json_semantic_adapter(
      "usage.estimated",
      rho.ai::EstimatedUsage,
      c(
        "input",
        "output",
        "cache_read",
        "cache_write",
        "cache_write_1h",
        "reasoning",
        "total",
        "cost",
        "estimator",
        "method"
      )
    ),
    rho_json_semantic_adapter(
      "usage.unavailable",
      rho.ai::UsageUnavailable,
      c("provider", "reason")
    ),
    rho_json_semantic_adapter(
      "usage.cost.nominal",
      rho.ai::NominalUsageCost,
      c("input", "output", "cache_read", "cache_write", "total")
    ),
    rho_json_semantic_adapter(
      "context.revision",
      rho.ai::RhoContextRevision,
      "digest"
    ),
    rho_json_semantic_adapter(
      "compaction.result",
      rho.agent::RhoCompactionResult,
      c("summary", "first_kept_entry_id", "tokens_before", "details", "source")
    ),
    rho_json_semantic_adapter(
      "compaction.reason.manual",
      rho.agent::RhoManualCompaction
    ),
    rho_json_semantic_adapter(
      "compaction.reason.threshold",
      rho.agent::RhoThresholdCompaction
    ),
    rho_json_semantic_adapter(
      "compaction.reason.provider_input_limit",
      rho.agent::RhoProviderInputLimitCompaction
    ),
    rho_json_semantic_adapter(
      "compaction.source.generated",
      rho.agent::RhoGeneratedCompaction
    ),
    rho_json_semantic_adapter(
      "compaction.source.provided",
      rho.agent::RhoProvidedCompaction
    ),
    rho_json_semantic_adapter(
      "memory.link",
      RhoMemoryLink,
      c("predicate", "to")
    ),
    rho_json_semantic_adapter(
      "memory.source",
      RhoMemorySource,
      c("path", "url", "locator", "quote")
    ),
    rho_json_semantic_adapter(
      "memory.note",
      RhoMemoryNote,
      c("slug", "title", "hook", "body", "tags", "links", "sources")
    ),
    rho_json_semantic_adapter(
      "memory.remembered",
      RhoMemoryRemembered,
      c(
        "revision_id",
        "sequence",
        "recorded_at",
        "author",
        "note",
        "supersedes_revision_id"
      )
    ),
    rho_json_semantic_adapter(
      "memory.edited",
      RhoMemoryEdited,
      c(
        "revision_id",
        "sequence",
        "recorded_at",
        "author",
        "note",
        "supersedes_revision_id",
        "retracted_links"
      )
    ),
    rho_json_semantic_adapter(
      "memory.forgotten",
      RhoMemoryForgotten,
      c(
        "revision_id",
        "sequence",
        "recorded_at",
        "author",
        "slug",
        "supersedes_revision_id",
        "reason",
        "retracted_links"
      )
    ),
    rho_json_semantic_adapter("memory.found", RhoMemoryFound, "revision"),
    rho_json_semantic_adapter(
      "memory.absent",
      RhoMemoryAbsent,
      c("slug", "last_revision_id")
    ),
    rho_json_semantic_adapter(
      "memory.history",
      RhoMemoryHistory,
      c("slug", "revisions")
    ),
    rho_json_semantic_adapter("memory.index", RhoMemoryIndex, "revisions"),
    rho_json_semantic_adapter(
      "memory.error.already_exists",
      RhoMemoryAlreadyExists,
      c("slug", "message", "current_revision_id")
    ),
    rho_json_semantic_adapter(
      "memory.error.conflict",
      RhoMemoryConflict,
      c("slug", "message", "expected_revision_id", "actual_revision_id")
    ),
    rho_json_semantic_adapter(
      "memory.error.not_found",
      RhoMemoryNotFound,
      c("slug", "message", "last_revision_id")
    ),
    rho_json_semantic_adapter(
      "memory.error.edit_unsupported",
      RhoMemoryEditUnsupported,
      c("slug", "message")
    )
  )
}

rho_json_session_codec <- function(adapters = list()) {
  registered <- c(rho_builtin_session_adapters(), adapters)
  tags <- vapply(registered, function(adapter) adapter@tag, character(1))
  if (anyDuplicated(tags)) {
    rho.async::rho_signal_contract_violation(
      "Session semantic adapters must have unique stable wire tags"
    )
  }
  RhoJsonSessionCodec(adapters = stats::setNames(registered, tags))
}

rho_jsonl_session_journal <- function(
  path,
  identity = rho.agent::rho_session_identity(),
  codec = rho_json_session_codec(),
  compute = NULL,
  timeout_ms = 5000L
) {
  RhoJsonlSessionJournal(
    path = normalizePath(path.expand(path), mustWork = FALSE),
    identity = identity,
    codec = codec,
    compute = compute,
    timeout_ms = timeout_ms
  )
}

rho_encoded_names <- function(codec, value) {
  if (is.null(names(value))) {
    return(list(kind = "null"))
  }
  rho_encode_session_value(codec, unname(names(value)))
}

S7::method(rho_encode_atomic_values, S7::class_logical) <- function(value, ...) {
  encoded <- rep("FALSE", length(value))
  encoded[!is.na(value) & value] <- "TRUE"
  encoded
}

S7::method(rho_encode_atomic_values, S7::class_integer) <- function(value, ...) {
  encoded <- as.character(value)
  encoded[is.na(value)] <- "0"
  encoded
}

S7::method(rho_encode_atomic_values, S7::class_double) <- function(value, ...) {
  vapply(
    value,
    function(element) {
      if (is.nan(element)) {
        "NaN"
      } else if (is.na(element)) {
        "0"
      } else if (is.infinite(element)) {
        if (element > 0) "Inf" else "-Inf"
      } else {
        sprintf("%.17g", element)
      }
    },
    character(1)
  )
}

S7::method(rho_encode_atomic_values, S7::class_character) <- function(value, ...) {
  encoded <- value
  encoded[is.na(value)] <- ""
  encoded
}

S7::method(rho_encode_atomic_values, S7::class_raw) <- function(value, ...) {
  as.character(as.integer(value))
}

S7::method(rho_encode_atomic_values, S7::class_any) <- function(value, ...) NULL

S7::method(
  rho_encode_session_value,
  list(RhoJsonSessionCodec, S7::class_list)
) <- function(codec, value, ...) {
  if (is.object(value)) {
    return(rho_session_codec_error(
      "Only unclassed lists can be encoded as session data",
      details = list(class = class(value))
    ))
  }
  documents <- lapply(value, function(element) rho_encode_session_value(codec, element))
  invalid <- which(vapply(
    documents,
    function(document) S7::S7_inherits(document, RhoSessionCodecErrorValue),
    logical(1)
  ))
  if (length(invalid)) {
    return(documents[[invalid[[1L]]]])
  }
  encoded_names <- rho_encoded_names(codec, value)
  if (S7::S7_inherits(encoded_names, RhoSessionCodecErrorValue)) {
    return(encoded_names)
  }
  list(
    kind = "list",
    values = I(unname(documents)),
    names = encoded_names
  )
}

S7::method(
  rho_encode_session_value,
  list(RhoJsonSessionCodec, S7::S7_object)
) <- function(codec, value, ...) {
  matches <- vapply(
    codec@adapters,
    function(adapter) S7::S7_inherits(value, adapter@value_class),
    logical(1)
  )
  if (!any(matches)) {
    return(rho_session_codec_error(
      "The session value has no semantic JSON adapter",
      details = list(class = S7::S7_class(value)@name)
    ))
  }
  adapter <- codec@adapters[[which(matches)[[1L]]]]
  documents <- lapply(
    unname(adapter@fields),
    function(property) {
      rho_encode_session_value(codec, S7::prop(value, property))
    }
  )
  names(documents) <- names(adapter@fields)
  invalid <- which(vapply(
    documents,
    function(document) S7::S7_inherits(document, RhoSessionCodecErrorValue),
    logical(1)
  ))
  if (length(invalid)) {
    return(documents[[invalid[[1L]]]])
  }
  list(kind = "semantic", type = adapter@tag, fields = documents)
}

S7::method(
  rho_encode_session_value,
  list(RhoJsonSessionCodec, S7::class_any)
) <- function(codec, value, ...) {
  if (is.null(value)) {
    return(list(kind = "null"))
  }
  if (!is.atomic(value) || is.object(value)) {
    return(rho_session_codec_error(
      "The session value is not JSON-serializable",
      details = list(class = class(value), type = typeof(value))
    ))
  }
  values <- rho_encode_atomic_values(value)
  if (is.null(values)) {
    return(rho_session_codec_error(
      "The atomic session value has an unsupported storage type",
      details = list(type = typeof(value))
    ))
  }
  encoded_names <- rho_encoded_names(codec, value)
  if (S7::S7_inherits(encoded_names, RhoSessionCodecErrorValue)) {
    return(encoded_names)
  }
  list(
    kind = "atomic",
    storage = typeof(value),
    length = length(value),
    values = I(as.list(unname(values))),
    missing = I(as.list(as.integer(which(
      is.na(value) & (typeof(value) != "double" | !is.nan(value))
    )))),
    names = encoded_names
  )
}

rho_decoded_atomic_values <- function(storage, values, missing) {
  values <- unlist(values, recursive = FALSE, use.names = FALSE)
  decoders <- list(
    logical = function(value) value == "TRUE",
    integer = as.integer,
    double = as.double,
    character = as.character,
    raw = function(value) as.raw(as.integer(value))
  )
  decoded <- decoders[[storage]](values)
  if (length(missing)) {
    decoded[as.integer(unlist(missing, use.names = FALSE))] <- NA
  }
  decoded
}

rho_json_session_document <- function(document) {
  if (
    !is.list(document) ||
      length(document$kind) != 1L ||
      !is.character(document$kind) ||
      is.na(document$kind) ||
      !nzchar(document$kind)
  ) {
    return(rho_session_codec_error("The session document has no scalar kind"))
  }

  constructors <- list(
    null = function(value) RhoJsonNullDocument(),
    atomic = function(value) {
      RhoJsonAtomicDocument(
        storage = value$storage,
        size = as.integer(value$length),
        values = unname(as.list(value$values)),
        missing = unname(as.list(value$missing)),
        names_document = as.list(value$names)
      )
    },
    list = function(value) {
      RhoJsonListDocument(
        values = unname(as.list(value$values)),
        names_document = as.list(value$names)
      )
    },
    semantic = function(value) {
      RhoJsonSemanticDocument(
        tag = value$type,
        property_documents = as.list(value$fields)
      )
    }
  )
  constructor <- constructors[[document$kind]]
  if (is.null(constructor)) {
    return(rho_session_codec_error(
      "The session document kind is unsupported",
      details = list(kind = document$kind)
    ))
  }
  tryCatch(
    constructor(document),
    error = function(error) {
      rho_session_codec_error(
        "The session document is invalid",
        details = list(kind = document$kind, message = conditionMessage(error))
      )
    }
  )
}

rho_session_codec_first_error <- function(values) {
  invalid <- which(vapply(
    values,
    function(value) S7::S7_inherits(value, RhoSessionCodecErrorValue),
    logical(1)
  ))
  if (length(invalid)) values[[invalid[[1L]]]] else NULL
}

rho_session_document_names <- function(codec, document, size, description) {
  decoded <- rho_decode_session_value(codec, document)
  if (S7::S7_inherits(decoded, RhoSessionCodecErrorValue)) {
    return(decoded)
  }
  if (!is.null(decoded) && length(decoded) != size) {
    return(rho_session_codec_error(
      paste("The", description, "session document has invalid names")
    ))
  }
  decoded
}

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, S7::class_list)
) <- function(
  codec,
  document,
  ...
) {
  normalized <- rho_json_session_document(document)
  if (S7::S7_inherits(normalized, RhoSessionCodecErrorValue)) {
    return(normalized)
  }
  rho_decode_session_value(codec, normalized)
}

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, S7::class_any)
) <- function(codec, document, ...) {
  rho_session_codec_error(
    "The session document must be a JSON object or typed JSON session document",
    details = list(class = class(document), type = typeof(document))
  )
}

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, RhoJsonNullDocument)
) <- function(codec, document, ...) NULL

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, RhoJsonAtomicDocument)
) <- function(codec, document, ...) {
  decoded <- rho_decoded_atomic_values(
    document@storage,
    document@values,
    document@missing
  )
  decoded_names <- rho_session_document_names(
    codec,
    document@names_document,
    document@size,
    "atomic"
  )
  if (S7::S7_inherits(decoded_names, RhoSessionCodecErrorValue)) {
    return(decoded_names)
  }
  if (!is.null(decoded_names)) {
    names(decoded) <- decoded_names
  }
  decoded
}

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, RhoJsonListDocument)
) <- function(codec, document, ...) {
  decoded <- lapply(
    document@values,
    function(value) rho_decode_session_value(codec, value)
  )
  invalid <- rho_session_codec_first_error(decoded)
  if (!is.null(invalid)) {
    return(invalid)
  }
  decoded_names <- rho_session_document_names(
    codec,
    document@names_document,
    length(decoded),
    "list"
  )
  if (S7::S7_inherits(decoded_names, RhoSessionCodecErrorValue)) {
    return(decoded_names)
  }
  if (!is.null(decoded_names)) {
    names(decoded) <- decoded_names
  }
  decoded
}

S7::method(
  rho_decode_session_value,
  list(RhoJsonSessionCodec, RhoJsonSemanticDocument)
) <- function(codec, document, ...) {
  adapter <- codec@adapters[[document@tag]]
  if (is.null(adapter)) {
    return(rho_session_codec_error(
      "The semantic session record type is unsupported",
      details = list(type = document@tag)
    ))
  }
  expected <- names(adapter@fields)
  if (!setequal(names(document@property_documents), expected)) {
    return(rho_session_codec_error(
      "The semantic session record fields do not match its schema",
      details = list(type = document@tag)
    ))
  }
  properties <- lapply(
    document@property_documents[expected],
    function(value) rho_decode_session_value(codec, value)
  )
  invalid <- rho_session_codec_first_error(properties)
  if (!is.null(invalid)) {
    return(invalid)
  }
  names(properties) <- unname(adapter@fields)
  tryCatch(
    do.call(adapter@value_class, properties),
    error = function(error) {
      rho_session_codec_error(
        "The semantic session record failed in-memory validation",
        details = list(type = document@tag, message = conditionMessage(error))
      )
    }
  )
}

rho_jsonl_header_line <- function(identity) {
  yyjsonr::write_json_str(
    list(
      schema = "rho.session.jsonl",
      type = "session",
      id = identity@id,
      parent_id = identity@parent_id
    ),
    auto_unbox = TRUE,
    null = "null",
    digits = -1L
  )
}

rho_jsonl_record_line <- function(codec, entry, position) {
  document <- rho_encode_session_value(codec, entry)
  if (S7::S7_inherits(document, RhoSessionCodecErrorValue)) {
    return(document)
  }
  yyjsonr::write_json_str(
    list(
      schema = "rho.session.jsonl",
      type = "entry",
      position = position,
      entry = document
    ),
    auto_unbox = TRUE,
    null = "null",
    digits = -1L
  )
}

rho_jsonl_corrupt_file <- function(message) {
  RhoJsonlCorruptFile(message = message, retryable = FALSE)
}

rho_jsonl_read_line <- function(line, invalid_message) {
  tryCatch(
    yyjsonr::read_json_str(
      line,
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) rho_jsonl_corrupt_file(invalid_message)
  )
}

rho_jsonl_header_identity <- function(line) {
  invalid <- "The JSONL journal header is invalid"
  header <- rho_jsonl_read_line(line, invalid)
  valid <- is.list(header) &&
    all(
      !S7::S7_inherits(header, RhoJsonlCorruptFile),
      identical(header$schema, "rho.session.jsonl"),
      identical(header$type, "session")
    )
  if (!valid) {
    return(rho_jsonl_corrupt_file(invalid))
  }
  tryCatch(
    rho.agent::RhoSessionIdentity(
      id = header$id,
      parent_id = header$parent_id
    ),
    error = function(error) rho_jsonl_corrupt_file(invalid)
  )
}

rho_jsonl_record_entries <- function(lines) {
  entries <- vector("list", length(lines))
  for (index in seq_along(lines)) {
    line_number <- index + 1L
    if (endsWith(lines[[index]], "\r")) {
      return(rho_jsonl_corrupt_file(
        "The JSONL journal must use LF framing"
      ))
    }
    record <- rho_jsonl_read_line(
      lines[[index]],
      sprintf("JSONL line %d is not valid JSON", line_number)
    )
    if (S7::S7_inherits(record, RhoJsonlCorruptFile)) {
      return(record)
    }
    valid <- is.list(record) &&
      all(
        identical(record$schema, "rho.session.jsonl"),
        identical(record$type, "entry"),
        identical(as.integer(record$position), as.integer(index)),
        is.list(record$entry)
      )
    if (!valid) {
      return(rho_jsonl_corrupt_file(sprintf(
        "JSONL line %d has an invalid session record",
        line_number
      )))
    }
    entries[[index]] <- record$entry
  }
  entries
}

rho_jsonl_inspect_file <- function(path) {
  tryCatch(
    {
      if (!file.exists(path)) {
        return(RhoJsonlEmptyInspection(position = 0L, entries = list()))
      }
      size <- file.info(path)$size
      if (is.na(size) || size > .Machine$integer.max) {
        return(rho_jsonl_corrupt_file("The JSONL journal size is invalid"))
      }
      if (size == 0) {
        return(RhoJsonlEmptyInspection(position = 0L, entries = list()))
      }
      connection <- file(path, open = "rb")
      on.exit(close(connection), add = TRUE)
      bytes <- readBin(connection, what = "raw", n = as.integer(size))
      if (!identical(bytes[[length(bytes)]], as.raw(10L))) {
        return(rho_jsonl_corrupt_file(
          "The JSONL journal ends with a partial line"
        ))
      }
      text <- rawToChar(bytes[-length(bytes)])
      if (!nzchar(text) || startsWith(text, "\n") || endsWith(text, "\n")) {
        return(rho_jsonl_corrupt_file(
          "The JSONL journal contains an empty line"
        ))
      }
      lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
      if (any(!nzchar(lines))) {
        return(rho_jsonl_corrupt_file(
          "The JSONL journal contains an empty line"
        ))
      }
      identity <- rho_jsonl_header_identity(lines[[1L]])
      if (S7::S7_inherits(identity, RhoJsonlCorruptFile)) {
        return(identity)
      }
      entries <- rho_jsonl_record_entries(lines[-1L])
      if (S7::S7_inherits(entries, RhoJsonlCorruptFile)) {
        return(entries)
      }
      RhoJsonlPresentInspection(
        session_id = identity@id,
        parent_session_id = identity@parent_id,
        position = as.integer(length(entries)),
        entries = entries
      )
    },
    error = function(error) {
      RhoJsonlIoFailure(
        message = conditionMessage(error),
        retryable = FALSE
      )
    }
  )
}

rho_jsonl_snapshot_worker <- function(path, inspect) {
  inspect(path)
}

rho_jsonl_commit_worker <- function(
  path,
  header,
  line,
  session_id,
  parent_session_id,
  after,
  timeout_ms,
  inspect
) {
  tryCatch(
    {
      directory <- dirname(path)
      if (!dir.exists(directory)) {
        dir.create(directory, recursive = TRUE, showWarnings = FALSE)
      }
      lock <- filelock::lock(paste0(path, ".lock"), timeout = timeout_ms)
      if (is.null(lock)) {
        return(RhoJsonlLockUnavailable(
          message = "The JSONL journal lock timed out",
          retryable = TRUE
        ))
      }
      on.exit(filelock::unlock(lock), add = TRUE)

      inspected <- inspect(path)
      if (!S7::S7_inherits(inspected, RhoJsonlInspection)) {
        return(inspected)
      }
      if (!identical(inspected@position, after)) {
        return(RhoJsonlPositionConflict(
          expected = after,
          current = inspected@position
        ))
      }

      record <- yyjsonr::read_json_str(
        line,
        arr_of_objs_to_df = FALSE,
        obj_of_arrs_to_df = FALSE
      )
      if (!identical(as.integer(record$position), after + 1L)) {
        return(RhoJsonlIoFailure(
          message = "The append record position is invalid",
          retryable = FALSE
        ))
      }
      connection <- file(path, open = "ab")
      on.exit(
        {
          if (!is.null(connection)) {
            close(connection)
          }
        },
        add = TRUE
      )
      empty <- S7::S7_inherits(inspected, RhoJsonlEmptyInspection)
      if (empty) {
        writeBin(c(charToRaw(header), as.raw(10L)), connection)
      }
      writeBin(c(charToRaw(line), as.raw(10L)), connection)
      flush(connection)
      close(connection)
      connection <- NULL
      Sys.chmod(path, mode = "0600")
      RhoJsonlCommitted(
        session_id = if (empty) session_id else inspected@session_id,
        parent_session_id = if (empty) {
          parent_session_id
        } else {
          inspected@parent_session_id
        },
        position = after + 1L,
        entries = c(inspected@entries, list(record$entry))
      )
    },
    error = function(error) {
      RhoJsonlIoFailure(
        message = conditionMessage(error),
        retryable = FALSE
      )
    }
  )
}

rho_jsonl_worker_error <- S7::new_generic(
  "rho_jsonl_worker_error",
  c("result", "journal"),
  function(result, journal, ...) S7::S7_dispatch()
)

S7::method(
  rho_jsonl_worker_error,
  list(rho.compute::RhoComputeErrorValue, RhoJsonlSessionJournal)
) <- function(result, journal, ...) {
  rho_jsonl_session_error(
    result@message,
    journal@path,
    retryable = TRUE,
    details = list(source = result@source)
  )
}

S7::method(
  rho_jsonl_worker_error,
  list(RhoJsonlPositionConflict, RhoJsonlSessionJournal)
) <- function(result, journal, ...) {
  rho.agent::rho_session_conflict(
    "The JSONL session journal has advanced beyond the expected position",
    details = list(
      path = journal@path,
      expected = result@expected,
      current = result@current
    )
  )
}

S7::method(
  rho_jsonl_worker_error,
  list(RhoJsonlWorkerFailure, RhoJsonlSessionJournal)
) <- function(result, journal, ...) {
  rho_jsonl_session_error(
    result@message,
    journal@path,
    retryable = result@retryable,
    details = list(source = result)
  )
}

S7::method(
  rho_jsonl_worker_error,
  list(S7::class_any, RhoJsonlSessionJournal)
) <- function(result, journal, ...) {
  rho_jsonl_session_error(
    "The JSONL journal worker returned an invalid result",
    journal@path,
    details = list(source = result)
  )
}

rho_jsonl_decode_entries <- function(journal, documents) {
  entries <- lapply(
    documents,
    function(document) rho_decode_session_value(journal@codec, document)
  )
  invalid <- which(vapply(
    entries,
    function(entry) S7::S7_inherits(entry, RhoSessionCodecErrorValue),
    logical(1)
  ))
  if (length(invalid)) entries[[invalid[[1L]]]] else entries
}

S7::method(
  rho_commit_session_entry,
  list(RhoJsonlSessionJournal, rho.agent::RhoSessionAppend)
) <- function(journal, append, ...) {
  line <- rho_jsonl_record_line(
    journal@codec,
    append@entry,
    append@after + 1L
  )
  if (S7::S7_inherits(line, RhoSessionCodecErrorValue)) {
    return(rho.async::rho_task(line))
  }
  header <- rho_jsonl_header_line(journal@identity)
  task <- rho.compute::rho_mirai_call(
    rho_jsonl_commit_worker,
    args = list(
      path = journal@path,
      header = header,
      line = line,
      session_id = journal@identity@id,
      parent_session_id = journal@identity@parent_id,
      after = append@after,
      timeout_ms = journal@timeout_ms,
      inspect = rho_jsonl_inspect_file
    ),
    timeout_ms = journal@timeout_ms,
    compute = journal@compute
  )
  rho.async::rho_then(task, function(result) {
    if (!S7::S7_inherits(result, RhoJsonlCommitted)) {
      return(rho_jsonl_worker_error(result, journal))
    }
    entries <- rho_jsonl_decode_entries(journal, result@entries)
    if (S7::S7_inherits(entries, RhoSessionCodecErrorValue)) {
      return(entries)
    }
    replay <- rho.agent::rho_session_replay(entries)
    if (S7::S7_inherits(replay, rho.agent::RhoSessionJournalErrorValue)) {
      return(replay)
    }
    rho.agent::RhoSessionCommit(
      identity = rho.agent::RhoSessionIdentity(
        id = result@session_id,
        parent_id = result@parent_session_id
      ),
      entry = append@entry,
      position = result@position,
      leaf_id = replay@leaf_id
    )
  })
}

S7::method(
  rho_session_snapshot,
  RhoJsonlSessionJournal
) <- function(journal, ...) {
  task <- rho.compute::rho_mirai_call(
    rho_jsonl_snapshot_worker,
    args = list(path = journal@path, inspect = rho_jsonl_inspect_file),
    timeout_ms = journal@timeout_ms,
    compute = journal@compute
  )
  rho.async::rho_then(task, function(result) {
    if (!S7::S7_inherits(result, RhoJsonlInspection)) {
      return(rho_jsonl_worker_error(result, journal))
    }
    identity <- if (S7::S7_inherits(result, RhoJsonlEmptyInspection)) {
      journal@identity
    } else {
      rho.agent::RhoSessionIdentity(
        id = result@session_id,
        parent_id = result@parent_session_id
      )
    }
    entries <- rho_jsonl_decode_entries(journal, result@entries)
    if (S7::S7_inherits(entries, RhoSessionCodecErrorValue)) {
      return(entries)
    }
    replay <- rho.agent::rho_session_replay(entries)
    if (S7::S7_inherits(replay, rho.agent::RhoSessionJournalErrorValue)) {
      return(replay)
    }
    tryCatch(
      rho.agent::RhoSessionSnapshot(
        identity = identity,
        entries = entries,
        position = result@position,
        leaf_id = replay@leaf_id
      ),
      error = function(error) {
        rho_jsonl_session_error(
          "The JSONL journal does not form a valid session snapshot",
          journal@path,
          details = list(message = conditionMessage(error))
        )
      }
    )
  })
}
