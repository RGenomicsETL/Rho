#!/usr/bin/env Rscript

roots <- c("R", "extensions", "scripts", "data-raw")
files <- unlist(
  lapply(roots[dir.exists(roots)], function(root) {
    list.files(root, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
  }),
  use.names = FALSE
)

definition_pattern <- "^[[:space:]]*\\.[A-Za-z][A-Za-z0-9_.]*[[:space:]]*<-"
standard_hook_pattern <- "^[[:space:]]*\\.(onLoad|onAttach|onUnload|onDetach)[[:space:]]*<-"
violations <- unlist(
  lapply(files, function(path) {
    lines <- readLines(path, warn = FALSE)
    indexes <- grep(definition_pattern, lines)
    indexes <- setdiff(indexes, grep(standard_hook_pattern, lines))
    if (!length(indexes)) {
      return(character())
    }
    sprintf("%s:%d: %s", path, indexes, trimws(lines[indexes]))
  }),
  use.names = FALSE
)

base_operator_pattern <- "^[[:space:]]*`%\\|\\|%`[[:space:]]*<-"
base_operator_violations <- unlist(
  lapply(files, function(path) {
    lines <- readLines(path, warn = FALSE)
    indexes <- grep(base_operator_pattern, lines)
    if (!length(indexes)) {
      return(character())
    }
    sprintf("%s:%d: %s", path, indexes, trimws(lines[indexes]))
  }),
  use.names = FALSE
)
violations <- c(violations, base_operator_violations)

if (length(violations)) {
  stop(
    paste(
      "Forbidden compatibility or pseudo-private definitions found:",
      paste(violations, collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )
}

message("Style contract passed: no dot-prefixed definitions")
