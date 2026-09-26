#' JSON session documents and the coding-host JSONL journal
#'
#' [rho_json_session_codec()] contains an explicit registry of stable semantic
#' record types. A [RhoJsonSemanticAdapter] maps one stable wire tag and field
#' set to the current in-memory S7 class. Package names, S7 class names, and
#' reflected property sets are never written to the journal. An extension adds
#' a value by supplying [rho_json_semantic_adapter()] with its own stable tag
#' and explicit fields.
#'
#' [rho_encode_session_value()] and [rho_decode_session_value()] retain R atomic
#' storage modes, list names, missing values, and registered semantic values.
#' Unknown S7 objects resolve to `RhoSessionCodecErrorValue` rather than acquiring
#' an accidental storage schema from the current package namespace.
#'
#' [rho_jsonl_session_journal()] implements the `SessionJournal` interface as a
#' coding-host adapter. File reads, locking, validation, and append run in mirai
#' workers. Each LF-delimited entry record carries a committed position and
#' typed entry document. A file lock and the append request's
#' expected position reject stale writers before mutation. A missing final LF,
#' malformed record, or invalid semantic document resolves to a typed error value.
#'
#' @name rho_coding_session_contracts
#' @aliases RhoJsonSessionCodec RhoJsonSemanticAdapter RhoSessionCodecErrorValue
#' @aliases RhoJsonlSessionJournal RhoJsonlSessionJournalErrorValue
#' @aliases rho_json_semantic_adapter rho_json_session_codec
#' @aliases rho_jsonl_session_journal
#' @aliases rho_encode_session_value rho_decode_session_value
#' @export RhoJsonSessionCodec
#' @export RhoJsonSemanticAdapter
#' @export RhoSessionCodecErrorValue
#' @export RhoJsonlSessionJournal
#' @export RhoJsonlSessionJournalErrorValue
#' @export rho_json_session_codec
#' @export rho_json_semantic_adapter
#' @export rho_jsonl_session_journal
#' @export rho_encode_session_value
#' @export rho_decode_session_value
NULL
