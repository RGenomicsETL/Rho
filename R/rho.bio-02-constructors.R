BIO_MANIFEST_SCHEMA <- "rho.bio.manifest.v1"
RESOLUTION_RECEIPT_SCHEMA <- "rho.bio.resolution_receipt.v1"

rho_virtual_resource <- function(id, title, resolver, params = list(), schema_ref = "") {
  VirtualResourceSpec(id, title, "virtual", resolver, params, schema_ref)
}
rho_resolver_spec <- function(
  id,
  version,
  title,
  description,
  output = list(mode = "table"),
  temporal = list()
) {
  BioResolverSpec(id, version, title, description, output, temporal)
}
rho_operation_spec <- function(
  id,
  title,
  description = "",
  transport = "duckdb.sql",
  input_schema = list(),
  output_schema = list(),
  sql = list(),
  notes = character()
) {
  BioOperationSpec(id, title, description, transport, input_schema, output_schema, sql, notes)
}
rho_manifest <- function(id, version, title, description, provides = list()) {
  BioManifest(BIO_MANIFEST_SCHEMA, id, version, title, description, provides)
}
rho_resource_handle <- function(kind, value, media_type = "", schema_ref = "") {
  ResourceHandle(kind, value, media_type, schema_ref)
}
rho_bio_error <- function(message, kind = "bio", code = "", details = list()) {
  BioErrorValue(kind = kind, message = message, code = code, details = details)
}
rho_bio_registry <- function() {
  BioRegistry(
    state = rho_bio_new_state(
      manifests = new.env(parent = emptyenv()),
      resources = new.env(parent = emptyenv()),
      resolvers = new.env(parent = emptyenv()),
      resolver_impls = new.env(parent = emptyenv()),
      term_sets = new.env(parent = emptyenv()),
      operations = new.env(parent = emptyenv())
    )
  )
}
