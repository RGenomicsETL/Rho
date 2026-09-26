#!/usr/bin/env Rscript

rho_read_json <- function(path) {
  yyjsonr::read_json_file(
    path,
    arr_of_objs_to_df = FALSE,
    obj_of_arrs_to_df = FALSE
  )
}

rho_copilot_headers <- function(provider, auth) {
  identity <- provider@implementation@identity
  list(
    Accept = "application/json",
    Authorization = paste("Bearer", auth@api_key),
    `X-GitHub-Api-Version` = "2026-06-01",
    `User-Agent` = identity@user_agent,
    `Editor-Version` = identity@editor_version,
    `Editor-Plugin-Version` = identity@editor_plugin_version,
    `Copilot-Integration-Id` = identity@integration_id
  )
}

rho_copilot_document <- function(provider, credential_path) {
  store <- rho::rho_file_credential_store(credential_path, list(provider))
  models <- rho::rho_models(list(provider), store)
  auth <- rho::rho_resolve_model_auth(
    models,
    rho::rho_model("github-copilot", "catalog-update")
  ) |>
    rho::rho_await(timeout = 30000L)
  if (!auth@configured) {
    stop(auth@error@message, call. = FALSE)
  }
  url <- paste0(sub("/+$", "", auth@auth@base_url), "/models")
  request <- rho::rho_http_request(
    method = "GET",
    url = url,
    headers = rho_copilot_headers(provider, auth@auth),
    timeout_ms = 30000L,
    convert = FALSE
  )
  response <- rho::rho_http_send(provider@implementation@http, request) |>
    rho::rho_await(timeout = 30000L)
  if (!S7::S7_inherits(response, rho::RhoHttpResponse)) {
    stop("GitHub Copilot model request returned no HTTP response", call. = FALSE)
  }
  if (is.na(response@status) || response@status < 200L || response@status >= 300L) {
    stop(
      sprintf("GitHub Copilot model request returned status %s", response@status),
      call. = FALSE
    )
  }
  document <- yyjsonr::read_json_raw(
    response@data,
    arr_of_objs_to_df = FALSE,
    obj_of_arrs_to_df = FALSE
  )
  if (!is.list(document$data)) {
    stop("GitHub Copilot model response has no data array", call. = FALSE)
  }
  list(url = url, raw = response@data, data = document$data)
}

rho_copilot_live_models <- function(data) {
  models <- Filter(
    function(model) {
      is.list(model) &&
        is.character(model$id) &&
        length(model$id) == 1L &&
        !is.na(model$id) &&
        nzchar(model$id)
    },
    data
  )
  names(models) <- vapply(models, function(model) model$id, character(1))
  models
}

rho_copilot_descriptor <- function(id, live_models) {
  model <- live_models[[id]]
  if (is.null(model)) {
    return(list(
      id = id,
      observed = FALSE,
      vendor = "",
      supported_endpoints = list()
    ))
  }
  endpoints <- unlist(model$supported_endpoints, use.names = FALSE)
  valid_endpoints <- !length(endpoints) ||
    (is.character(endpoints) && !anyNA(endpoints) && all(nzchar(endpoints)))
  if (!valid_endpoints) {
    stop(sprintf("GitHub Copilot model %s has invalid supported_endpoints", id), call. = FALSE)
  }
  list(
    id = id,
    observed = TRUE,
    vendor = as.character(model$vendor %||% ""),
    supported_endpoints = as.list(unique(endpoints))
  )
}

file_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
if (!length(file_argument)) {
  stop("Cannot determine the updater script location", call. = FALSE)
}
script <- normalizePath(
  sub("^--file=", "", file_argument[[1L]]),
  mustWork = TRUE
)
data_raw <- dirname(script)
parser <- optparse::OptionParser(
  description = "Refresh sanitized GitHub Copilot model endpoint metadata",
  option_list = list(
    optparse::make_option(
      "--credential",
      type = "character",
      help = "Explicit Rho credential-store path"
    ),
    optparse::make_option(
      "--models-dev",
      dest = "models_dev",
      type = "character",
      default = file.path(data_raw, "models-dev-selected.json"),
      help = "Pinned models.dev projection [%default]"
    ),
    optparse::make_option(
      "--output",
      type = "character",
      default = file.path(data_raw, "github-copilot-models.json"),
      help = "Sanitized output path [%default]"
    )
  )
)
options <- optparse::parse_args(parser)
if (
  is.null(options$credential) ||
    !nzchar(options$credential) ||
    !file.exists(options$credential)
) {
  stop("--credential must name an existing file", call. = FALSE)
}
credential_path <- normalizePath(
  options$credential,
  winslash = "/",
  mustWork = TRUE
)
models_dev_path <- options$models_dev
output_path <- options$output
models_dev <- rho_read_json(models_dev_path)
provider_source <- models_dev$providers[["github-copilot"]]
if (is.null(provider_source) || !is.list(provider_source$models)) {
  stop("models.dev snapshot has no GitHub Copilot models", call. = FALSE)
}

provider <- rho::rho_github_copilot_provider()
live <- rho_copilot_document(provider, credential_path)
live_models <- rho_copilot_live_models(live$data)
model_ids <- sort(names(provider_source$models))
descriptors <- lapply(model_ids, rho_copilot_descriptor, live_models = live_models)
names(descriptors) <- model_ids
snapshot <- list(
  schema_version = 1L,
  source = list(
    url = live$url,
    sha256 = digest::digest(live$raw, algo = "sha256", serialize = FALSE)
  ),
  models_dev_sha256 = models_dev$source$sha256,
  models = descriptors
)
json <- yyjsonr::write_json_str(
  snapshot,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
writeLines(json, output_path, useBytes = TRUE)
message(sprintf("Updated %s", normalizePath(output_path, mustWork = TRUE)))
