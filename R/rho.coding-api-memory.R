#' Authored memory revisions and tools
#'
#' Authored memory is an append-only temporal port. [rho_remember()] creates a
#' live note, [rho_edit_memory()] applies a typed edit only when its expected
#' revision is still current, and [rho_forget()] appends a tombstone. Recall and
#' history retain attribution and revision identity; no operation destroys an
#' earlier observation.
#'
#' `MemoryStore` is the structural interface consumed by the coding tools.
#' [rho_in_memory_memory_store()] is the process-local reference
#' implementation. Other packages can implement the same generics over DuckDB,
#' NNG, or another temporal observation store.
#'
#' [rho_memory_tools()] returns `remember`, `recall`, `edit_memory`, `forget`,
#' and `memory_history`. Mutating calls require an explicit author. Edit and
#' forget require the revision identifier returned by recall, so a stale model
#' action resolves to `RhoMemoryConflict` instead of overwriting newer work.
#'
#' @name rho_coding_memory
#' @aliases MemoryStore RhoMemoryStore RhoInMemoryMemoryStore
#' @aliases RhoMemoryClock RhoSystemMemoryClock RhoMemoryLink RhoMemorySource
#' @aliases RhoMemoryNote RhoMemoryEdit RhoMemoryReplacement
#' @aliases RhoMemoryCommand RhoRememberMemoryCommand RhoRecallMemoryCommand
#' @aliases RhoEditMemoryCommand RhoForgetMemoryCommand RhoMemoryHistoryCommand
#' @aliases RhoMemoryObservation
#' @aliases RhoMemoryContentRevision RhoMemoryRemembered RhoMemoryEdited
#' @aliases RhoMemoryForgotten RhoMemoryResult RhoMemoryFound RhoMemoryAbsent
#' @aliases RhoMemoryHistory RhoMemoryIndex RhoMemoryErrorValue
#' @aliases RhoMemoryAlreadyExists RhoMemoryConflict RhoMemoryNotFound
#' @aliases RhoMemoryEditUnsupported
#' @aliases rho_memory_link rho_memory_source
#' @aliases rho_memory_note rho_memory_replacement rho_in_memory_memory_store
#' @aliases rho_memory_now rho_remember rho_recall rho_edit_memory
#' @aliases rho_apply_memory_edit rho_forget rho_memory_history rho_list_memory
#' @aliases rho_memory_slug rho_as_memory_link rho_as_memory_source
#' @aliases rho_execute_memory_command
#' @aliases rho_memory_tool_result rho_memory_tools rho_tool_remember
#' @aliases rho_tool_recall rho_tool_edit_memory rho_tool_forget
#' @aliases rho_tool_memory_history
#' @export MemoryStore
#' @export RhoMemoryStore
#' @export RhoInMemoryMemoryStore
#' @export RhoMemoryClock
#' @export RhoSystemMemoryClock
#' @export RhoMemoryLink
#' @export RhoMemorySource
#' @export RhoMemoryNote
#' @export RhoMemoryEdit
#' @export RhoMemoryReplacement
#' @export RhoMemoryCommand
#' @export RhoRememberMemoryCommand
#' @export RhoRecallMemoryCommand
#' @export RhoEditMemoryCommand
#' @export RhoForgetMemoryCommand
#' @export RhoMemoryHistoryCommand
#' @export RhoMemoryObservation
#' @export RhoMemoryContentRevision
#' @export RhoMemoryRemembered
#' @export RhoMemoryEdited
#' @export RhoMemoryForgotten
#' @export RhoMemoryResult
#' @export RhoMemoryFound
#' @export RhoMemoryAbsent
#' @export RhoMemoryHistory
#' @export RhoMemoryIndex
#' @export RhoMemoryErrorValue
#' @export RhoMemoryAlreadyExists
#' @export RhoMemoryConflict
#' @export RhoMemoryNotFound
#' @export RhoMemoryEditUnsupported
#' @export rho_memory_link
#' @export rho_memory_source
#' @export rho_memory_note
#' @export rho_memory_replacement
#' @export rho_in_memory_memory_store
#' @export rho_memory_now
#' @export rho_remember
#' @export rho_recall
#' @export rho_edit_memory
#' @export rho_apply_memory_edit
#' @export rho_forget
#' @export rho_memory_history
#' @export rho_list_memory
#' @export rho_memory_slug
#' @export rho_memory_tool_result
#' @export rho_as_memory_link
#' @export rho_as_memory_source
#' @export rho_execute_memory_command
#' @export rho_memory_tools
#' @export rho_tool_remember
#' @export rho_tool_recall
#' @export rho_tool_edit_memory
#' @export rho_tool_forget
#' @export rho_tool_memory_history
#' @importFrom s7contract interface_requirement new_interface
NULL
