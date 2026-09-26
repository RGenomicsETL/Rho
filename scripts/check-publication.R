#!/usr/bin/env Rscript

version <- trimws(readLines("VERSION", warn = FALSE, encoding = "UTF-8"))
version <- version[nzchar(version)]
if (length(version) != 1L) {
  stop("VERSION must contain exactly one non-empty line", call. = FALSE)
}

lifecycle_badge <- "https://img.shields.io/badge/lifecycle-experimental-orange.svg"
errors <- character()

record_error <- function(message) {
  errors <<- c(errors, message)
}

check_file <- function(path, description) {
  if (!file.exists(path)) {
    record_error(sprintf("missing %s: %s", description, path))
    return(FALSE)
  }
  TRUE
}

check_readme <- function(path) {
  if (!check_file(path, "README")) {
    return(invisible(NULL))
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (!any(grepl(lifecycle_badge, lines, fixed = TRUE))) {
    record_error(sprintf("%s has no experimental lifecycle badge", path))
  }
  relative_readme_links <- grep(
    "\\]\\(\\.\\./(?:\\.\\./)?[^)]*README[.]md\\)",
    lines,
    perl = TRUE,
    value = TRUE
  )
  if (length(relative_readme_links)) {
    record_error(sprintf(
      "%s contains a relative README link that pkgdown rewrites incorrectly",
      path
    ))
  }
  invisible(NULL)
}

check_news <- function(path, heading) {
  if (!check_file(path, "NEWS")) {
    return(invisible(NULL))
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (!length(lines) || !identical(lines[[1L]], heading)) {
    record_error(sprintf("%s must begin with `%s`", path, heading))
  }
  invisible(NULL)
}

check_news("NEWS.md", sprintf("# Rho %s", version))
check_readme("README.Rmd")
check_readme("README.md")

tracked_readme_cache <- system2(
  "git",
  c("ls-files", "--", "README_cache"),
  stdout = TRUE,
  stderr = FALSE
)
if (length(tracked_readme_cache)) {
  record_error(sprintf(
    "README cache files must not be tracked: %s",
    paste(tracked_readme_cache, collapse = ", ")
  ))
}

if (length(errors)) {
  message("Publication metadata contract failed:")
  message(paste0("- ", errors, collapse = "\n"))
  quit(status = 1L)
}

message("Publication metadata contract passed: rho")
