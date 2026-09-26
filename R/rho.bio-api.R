#' Bioinformatics resource and operation contracts
#'
#' Manifests declare virtual resources, resolvers, term sets, and operations.
#' Resolution is asynchronous and returns a `ResolutionReceipt` containing the
#' selected resolver version, parameter digest, source snapshots, result handle,
#' and provenance.
#'
#' `rho.bio` defines the generic SQL contract but does not depend on a database
#' implementation or the agent packages.
#'
#' @name rho_bio_contracts
#' @aliases ContentAddress ResourceHandle VirtualResourceSpec BioResolverSpec
#' @aliases TermRef TermSet BioOperationSpec BioManifest ResolutionReceipt
#' @aliases BioRegistry BioErrorValue BIO_MANIFEST_SCHEMA RESOLUTION_RECEIPT_SCHEMA
#' @aliases rho_virtual_resource rho_resolver_spec rho_operation_spec
#' @aliases rho_manifest rho_resource_handle rho_bio_error rho_bio_registry
#' @aliases rho_validate_manifest rho_register_manifest rho_bind_resolver_impl
#' @aliases rho_resolve_resource rho_get_operation rho_sql_all rho_sql_run
#' @export ContentAddress
#' @export ResourceHandle
#' @export VirtualResourceSpec
#' @export BioResolverSpec
#' @export TermRef
#' @export TermSet
#' @export BioOperationSpec
#' @export BioManifest
#' @export ResolutionReceipt
#' @export BioRegistry
#' @export BioErrorValue
#' @export BIO_MANIFEST_SCHEMA
#' @export RESOLUTION_RECEIPT_SCHEMA
#' @export rho_virtual_resource
#' @export rho_resolver_spec
#' @export rho_operation_spec
#' @export rho_manifest
#' @export rho_resource_handle
#' @export rho_bio_error
#' @export rho_bio_registry
#' @export rho_validate_manifest
#' @export rho_register_manifest
#' @export rho_bind_resolver_impl
#' @export rho_resolve_resource
#' @export rho_get_operation
#' @export rho_sql_all
#' @export rho_sql_run
#' @importFrom digest digest
NULL
