#!/usr/bin/env Rscript
version <- trimws(readLines("VERSION", warn = FALSE))
if (length(version) != 1L || !nzchar(version)) {
  stop("VERSION must contain one version", call. = FALSE)
}
package_version(version)
description <- read.dcf("DESCRIPTION")
stopifnot(
  identical(description[[1L, "Package"]], "rho"),
  identical(description[[1L, "Version"]], version),
  grepl("R \\(>= 4\\.4\\.0\\)", description[[1L, "Depends"]])
)
message("Package version contract passed: rho ", version)
