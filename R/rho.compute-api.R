#' Typed compute specifications and the mirai backend
#'
#' `RhoComputeExpressionSpec` carries captured R code plus an explicit named
#' argument list. `RhoComputeCallSpec` carries a worker function plus explicit
#' arguments, avoiding dynamically injected globals in calling packages.
#' [rho_submit_compute()] is the backend extension point. The convenience
#' functions [rho_mirai_eval()] and [rho_mirai_call()] construct the respective
#' specifications and return `RhoMiraiTask` values.
#'
#' Worker failures resolve as `RhoComputeErrorValue`; they are values that
#' downstream packages may translate through S7 dispatch.
#'
#' @name rho_compute_contracts
#' @aliases RhoComputeBackend RhoComputeSpec RhoComputeExpressionSpec
#' @aliases RhoComputeCallSpec RhoMiraiBackend RhoMiraiTask
#' @aliases RhoComputeErrorValue rho_mirai_backend rho_mirai_eval
#' @aliases rho_mirai_call rho_submit_compute
#' @export RhoComputeBackend
#' @export RhoComputeSpec
#' @export RhoComputeExpressionSpec
#' @export RhoComputeCallSpec
#' @export RhoMiraiBackend
#' @export RhoMiraiTask
#' @export RhoComputeErrorValue
#' @export rho_mirai_backend
#' @export rho_mirai_eval
#' @export rho_mirai_call
#' @export rho_submit_compute
#' @importFrom promises as.promise catch then
NULL
