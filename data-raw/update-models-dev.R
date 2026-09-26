#!/usr/bin/env Rscript

rho_model_effort_levels <- function(model) {
  options <- model$reasoning_options %||% list()
  effort <- Filter(function(option) identical(option$type, "effort"), options)
  if (!length(effort)) character() else effort[[1L]]$values %||% character()
}

rho_model_reasoning_modes <- function(model) {
  options <- model$reasoning_options %||% list()
  unique(vapply(options, function(option) option$type %||% "", character(1)))
}

rho_models_dev_record <- function(id, model) {
  list(
    id = id,
    name = model$name %||% id,
    status = model$status %||% "active",
    tool_call = isTRUE(model$tool_call),
    reasoning = isTRUE(model$reasoning),
    reasoning_modes = as.list(rho_model_reasoning_modes(model)),
    reasoning_levels = as.list(rho_model_effort_levels(model)),
    temperature = isTRUE(model$temperature %||% TRUE),
    input = as.list(model$modalities$input %||% "text"),
    context_window = model$limit$context,
    max_tokens = model$limit$output,
    pricing = list(
      input = model$cost$input,
      output = model$cost$output,
      cache_read = model$cost$cache_read %||% 0,
      cache_write = model$cost$cache_write %||% 0
    )
  )
}

rho_models_dev_provider <- function(provider) {
  model_ids <- sort(names(provider$models))
  models <- lapply(model_ids, function(id) {
    rho_models_dev_record(id, provider$models[[id]])
  })
  names(models) <- model_ids
  list(
    id = provider$id,
    name = provider$name,
    api = provider$api %||% "",
    package = provider$npm %||% "",
    documentation = provider$doc %||% "",
    models = models
  )
}

rho_fetch_models_dev <- function(url) {
  response <- nanonext::ncurl(
    url,
    convert = FALSE,
    follow = TRUE,
    timeout = 30000L
  )
  if (inherits(response, "errorValue")) {
    stop(sprintf("models.dev request failed: %s", conditionMessage(response)), call. = FALSE)
  }
  if (!identical(response$status, 200L)) {
    stop(sprintf("models.dev returned HTTP status %s", response$status), call. = FALSE)
  }
  response$data
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
  description = "Refresh the selected models.dev projection",
  option_list = list(
    optparse::make_option(
      "--output",
      type = "character",
      default = file.path(data_raw, "models-dev-selected.json")
    ),
    optparse::make_option(
      "--registry",
      type = "character",
      default = file.path(data_raw, "model-registry.R")
    )
  )
)
options <- optparse::parse_args(parser)
output <- options$output
sys.source(options$registry, envir = environment())
source_url <- "https://models.dev/api.json"
source_raw <- rho_fetch_models_dev(source_url)
source <- yyjsonr::read_json_raw(
  source_raw,
  arr_of_objs_to_df = FALSE,
  obj_of_arrs_to_df = FALSE
)
provider_ids <- rho_catalog_registry_source_ids(rho_model_registry)
missing <- setdiff(provider_ids, names(source))
if (length(missing)) {
  stop(
    sprintf("models.dev is missing required provider(s): %s", paste(missing, collapse = ", ")),
    call. = FALSE
  )
}
providers <- lapply(provider_ids, function(id) rho_models_dev_provider(source[[id]]))
names(providers) <- provider_ids
snapshot <- list(
  schema_version = 2L,
  source = list(
    url = source_url,
    sha256 = digest::digest(source_raw, algo = "sha256", serialize = FALSE)
  ),
  providers = providers
)
json <- yyjsonr::write_json_str(
  snapshot,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
writeLines(json, output, useBytes = TRUE)
message(sprintf("Updated %s", normalizePath(output, mustWork = TRUE)))
