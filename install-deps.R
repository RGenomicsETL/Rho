configured_repos <- getOption("repos")
configured_repos[configured_repos == "@CRAN@"] <- "https://cloud.r-project.org"
repos <- c(
  RGenomicsETL = "https://rgenomicsetl.r-universe.dev",
  coolbutuseless = "https://coolbutuseless.r-universe.dev",
  configured_repos
)
repos <- repos[!duplicated(unname(repos))]

nanonext_commit <- "084c8eb82a35c38b2aaf7dd203414829c2bd8011"
nanonext_source <- sprintf(
  "https://github.com/RGenomicsETL/nanonext/archive/%s.tar.gz",
  nanonext_commit
)

install.packages(nanonext_source, repos = NULL, type = "source")
if (!"ncurl_stream_aio" %in% getNamespaceExports("nanonext")) {
  stop("Pinned nanonext build does not export ncurl_stream_aio", call. = FALSE)
}
install.packages(
  c(
    "S7",
    "s7contract",
    "mirai",
    "coro",
    "httr2",
    "later",
    "promises",
    "tinytest",
    "knitr",
    "rmarkdown",
    "litedown",
    "optparse",
    "pkgdown",
    "rdocdump",
    "roxygen2",
    "yyjsonr",
    "base64enc",
    "digest",
    "keyring",
    "rmonocypher",
    "processx",
    "DBI",
    "duckdb",
    "ggplot2",
    "svglite",
    "ragg"
  ),
  repos = repos
)
