ContentAddress <- S7::new_class(
  "ContentAddress",
  properties = list(
    algorithm = rho_bio_non_empty_string,
    digest = rho_bio_non_empty_string,
    media_type = S7::class_character,
    size_bytes = S7::class_double
  )
)

ResourceHandle <- S7::new_class(
  "ResourceHandle",
  properties = list(
    kind = rho_bio_non_empty_string,
    value = S7::class_any,
    media_type = S7::class_character,
    schema_ref = S7::class_character
  )
)

VirtualResourceSpec <- S7::new_class(
  "VirtualResourceSpec",
  properties = list(
    id = rho_bio_non_empty_string,
    title = S7::class_character,
    kind = rho_bio_non_empty_string,
    resolver = rho_bio_non_empty_string,
    params = S7::class_list,
    schema_ref = S7::class_character
  )
)

BioResolverSpec <- S7::new_class(
  "BioResolverSpec",
  properties = list(
    id = rho_bio_non_empty_string,
    version = rho_bio_non_empty_string,
    title = S7::class_character,
    description = S7::class_character,
    output = S7::class_list,
    temporal = S7::class_list
  )
)

TermRef <- S7::new_class(
  "TermRef",
  properties = list(
    id = rho_bio_non_empty_string,
    label = S7::class_character,
    rank = S7::class_integer
  )
)

TermSet <- S7::new_class(
  "TermSet",
  properties = list(
    id = rho_bio_non_empty_string,
    title = S7::class_character,
    ordered = S7::class_logical,
    members = S7::class_list
  )
)

BioOperationSpec <- S7::new_class(
  "BioOperationSpec",
  properties = list(
    id = rho_bio_non_empty_string,
    title = S7::class_character,
    description = S7::class_character,
    transport = rho_bio_non_empty_string,
    input_schema = S7::class_any,
    output_schema = S7::class_any,
    sql = S7::class_list,
    notes = S7::class_character
  )
)

BioManifest <- S7::new_class(
  "BioManifest",
  properties = list(
    schema = rho_bio_non_empty_string,
    id = rho_bio_non_empty_string,
    version = rho_bio_non_empty_string,
    title = S7::class_character,
    description = S7::class_character,
    provides = S7::class_list
  )
)

ResolutionReceipt <- S7::new_class(
  "ResolutionReceipt",
  properties = list(
    schema = rho_bio_non_empty_string,
    resource_id = rho_bio_non_empty_string,
    resolver_id = rho_bio_non_empty_string,
    resolver_version = rho_bio_non_empty_string,
    resolved_at = rho_bio_non_empty_string,
    params_digest = rho_bio_non_empty_string,
    source_snapshots = S7::class_list,
    result = ResourceHandle,
    provenance = S7::class_list
  )
)

BioRegistry <- S7::new_class(
  "BioRegistry",
  properties = list(state = S7::class_environment)
)

BioErrorValue <- S7::new_class(
  "BioErrorValue",
  properties = list(
    kind = rho_bio_non_empty_string,
    message = rho_bio_non_empty_string,
    code = S7::class_character,
    details = S7::class_list
  )
)
