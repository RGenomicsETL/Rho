#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
check <- "--check" %in% args

if (!requireNamespace("knitr", quietly = TRUE)) {
  stop("Package 'knitr' is required to purl Rmd-driven tests.", call. = FALSE)
}

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
rel_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  sub(paste0("^", root, "/?"), "", path)
}

rmd_dir <- file.path("inst", "tinytest", "rmd")
out_dir <- file.path("inst", "tinytest")
changed <- character()

for (rmd in list.files(rmd_dir, pattern = "[.]Rmd$", full.names = TRUE)) {
  stem <- tools::file_path_sans_ext(basename(rmd))
  out <- file.path(out_dir, paste0("test-", stem, ".R"))
  tmp <- tempfile(fileext = ".R")
  knitr::purl(rmd, output = tmp, documentation = 0, quiet = TRUE)
  generated <- c(
    sprintf("# Generated from %s; do not edit.", rel_path(rmd)),
    "",
    readLines(tmp, warn = FALSE)
  )
  existing <- if (file.exists(out)) readLines(out, warn = FALSE) else character()
  same <- identical(existing, generated)
  if (check && !same) {
    changed <- c(changed, rel_path(out))
  }
  if (!check && !same) {
    writeLines(generated, out, useBytes = TRUE)
    message("wrote ", rel_path(out))
  }
}

if (check && length(changed)) {
  cat("Purled tinytest files are stale:\n")
  cat(paste0("  - ", changed, "\n"), sep = "")
  cat("\nRun: Rscript scripts/purl-tests.R\n")
  quit(status = 1)
}
