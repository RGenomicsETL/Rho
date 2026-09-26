#!/usr/bin/env Rscript

if (!requireNamespace("litedown", quietly = TRUE)) {
  stop("Package 'litedown' is required", call. = FALSE)
}

source_docs <- sort(list.files("docs", pattern = "\\.md$", full.names = TRUE))
if (!length(source_docs)) {
  stop("No project documentation files were found", call. = FALSE)
}

landing_css <- normalizePath(
  "tools/landing.css",
  winslash = "/",
  mustWork = TRUE
)
docs_header <- normalizePath(
  "tools/docs-header.html",
  winslash = "/",
  mustWork = TRUE
)
destination <- file.path("_site", "docs")
dir.create(destination, recursive = TRUE, showWarnings = FALSE)

metadata <- c(
  "---",
  "output:",
  "  html:",
  "    options:",
  "      toc: true",
  "    meta:",
  paste0(
    "      css: [\"@default@1.14.69\", \"@article@1.14.69\", ",
    "\"@site@1.14.69\", \"",
    landing_css,
    "\"]"
  ),
  paste0("      include_before: \"", docs_header, "\""),
  "---"
)

for (source in source_docs) {
  name <- tools::file_path_sans_ext(basename(source))
  markdown <- readLines(source, warn = FALSE, encoding = "UTF-8")
  litedown::mark(
    text = c(metadata, markdown),
    output = file.path(destination, paste0(name, ".html"))
  )
  file.copy(source, file.path(destination, basename(source)), overwrite = TRUE)
}
