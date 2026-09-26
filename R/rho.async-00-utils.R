rho_contract_violation <- function(message, call = NULL) {
  structure(
    list(message = as.character(message), call = call),
    class = c("rho_contract_violation", "error", "condition")
  )
}

rho_signal_contract_violation <- function(..., call = sys.call(-1L)) {
  base::stop(rho_contract_violation(sprintf(...), call = call))
}

rho_signal_task_failure <- function(error) {
  if (!inherits(error, "condition")) {
    error <- simpleError(as.character(error))
  }
  base::stop(error)
}

rho_new_state <- function(parent = emptyenv(), ...) {
  e <- new.env(parent = parent)
  vals <- list(...)
  for (nm in names(vals)) {
    assign(nm, vals[[nm]], envir = e)
  }
  e
}

rho_is_task <- function(x) {
  isTRUE(tryCatch(S7::S7_inherits(x, RhoTask), error = function(e) FALSE))
}

rho_is_stream <- function(x) {
  isTRUE(tryCatch(S7::S7_inherits(x, RhoStream), error = function(e) FALSE))
}
