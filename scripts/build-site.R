#!/usr/bin/env Rscript
if (!requireNamespace("pkgdown", quietly = TRUE)) {
  stop("Package 'pkgdown' is required", call. = FALSE)
}
dir.create("_site", showWarnings = FALSE)
pkgdown::build_site(
  pkg = ".",
  new_process = FALSE,
  install = FALSE,
  preview = FALSE,
  override = list(destination = normalizePath("_site", mustWork = TRUE))
)
