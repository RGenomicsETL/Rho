rho_tool_read <- function() {
  rho_tool_spec(
    name = "read",
    label = "Read",
    description = "Read a UTF-8 text file",
    parameters = list(required = "path"),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_task_from_function(
        function() {
          path <- params$path
          if (!file.exists(path)) {
            return(rho_tool_error_result(
              content = list(rho_text(sprintf("File not found: %s", path))),
              details = list(path = path, reason = "not_found")
            ))
          }
          text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
          rho_tool_result(list(rho_text(text)), details = list(path = path))
        },
        label = "tool-read"
      )
    }
  )
}

rho_tool_write <- function() {
  rho_tool_spec(
    name = "write",
    label = "Write",
    description = "Write a UTF-8 text file",
    parameters = list(required = c("path", "text")),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_task_from_function(
        function() {
          dir.create(dirname(params$path), recursive = TRUE, showWarnings = FALSE)
          writeLines(params$text, params$path, useBytes = TRUE)
          rho_tool_result(
            list(rho_text(sprintf("wrote %s", params$path))),
            details = list(path = params$path)
          )
        },
        label = "tool-write"
      )
    }
  )
}

rho_coding_tools <- function(memory_store = NULL, memory_author = "agent") {
  tools <- list(rho_tool_read(), rho_tool_write(), rho_tool_bash(), rho_tool_r())
  if (!is.null(memory_store)) {
    tools <- c(tools, rho_memory_tools(memory_store, memory_author))
  }
  tools
}
