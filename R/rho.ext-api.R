#' Extension registration and asynchronous dispatch
#'
#' An extension receives `RhoExtensionAPI` and registers typed tools,
#' providers, commands, or event handlers. [rho_dispatch_event()] normalizes an
#' event pipeline to a task so asynchronous handlers remain part of the agent
#' control flow.
#'
#' @name rho_extension_contracts
#' @aliases RhoExtensionRuntime RhoExtensionAPI RhoExtensionContext
#' @aliases rho_extension_runtime rho_extension_api rho_on rho_register_tool
#' @aliases rho_register_command rho_register_provider rho_dispatch_event
#' @export RhoExtensionRuntime
#' @export RhoExtensionAPI
#' @export RhoExtensionContext
#' @export rho_extension_runtime
#' @export rho_extension_api
#' @export rho_on
#' @export rho_register_tool
#' @export rho_register_command
#' @export rho_register_provider
#' @export rho_dispatch_event
NULL
