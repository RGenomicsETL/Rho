#' Coding tools and their execution contracts
#'
#' The shell contract preserves Bash semantics across platforms and returns a
#' typed resolution explaining which executable was selected. Shell processes
#' execute through `rho.compute` and `processx`.
#'
#' R evaluation has explicit state semantics: `RhoMiraiExpressionEvaluator` is
#' isolated and may overlap, while `RhoCurrentSessionREvaluator` receives a
#' caller-supplied environment and requires exclusive scheduling.
#'
#' @name rho_coding_contracts
#' @aliases RhoPlatform RhoUnixPlatform RhoWindowsPlatform RhoShellResolution
#' @aliases RhoShellConfig RhoArgumentShell RhoBashShell
#' @aliases RhoLegacyWslBashShell RhoShellUnavailable RhoShellBackend
#' @aliases RhoMiraiShellBackend RhoShellOutcome RhoShellCompleted
#' @aliases RhoShellFailure RhoRExpression RhoREvaluator
#' @aliases RhoCurrentSessionREvaluator RhoMiraiExpressionEvaluator
#' @aliases RhoREvaluationBinding
#' @aliases RhoREvaluationOutcome RhoREvaluationSuccess RhoREvaluationFailure
#' @aliases rho_current_platform rho_resolve_bash rho_run_shell
#' @aliases rho_shell_outcome rho_shell_tool_result rho_evaluate_r
#' @aliases rho_r_evaluation_binding rho_r_evaluator_reason
#' @aliases rho_r_evaluation_outcome rho_r_tool_result rho_r_evaluator_overlap
#' @aliases rho_tool_read rho_tool_write rho_tool_bash rho_tool_r rho_coding_tools
#' @export RhoPlatform
#' @export RhoUnixPlatform
#' @export RhoWindowsPlatform
#' @export RhoShellResolution
#' @export RhoShellConfig
#' @export RhoArgumentShell
#' @export RhoBashShell
#' @export RhoLegacyWslBashShell
#' @export RhoShellUnavailable
#' @export RhoShellBackend
#' @export RhoMiraiShellBackend
#' @export RhoShellOutcome
#' @export RhoShellCompleted
#' @export RhoShellFailure
#' @export RhoRExpression
#' @export RhoREvaluator
#' @export RhoCurrentSessionREvaluator
#' @export RhoMiraiExpressionEvaluator
#' @export RhoREvaluationBinding
#' @export RhoREvaluationOutcome
#' @export RhoREvaluationSuccess
#' @export RhoREvaluationFailure
#' @export rho_current_platform
#' @export rho_resolve_bash
#' @export rho_run_shell
#' @export rho_shell_outcome
#' @export rho_shell_tool_result
#' @export rho_evaluate_r
#' @export rho_r_evaluation_binding
#' @export rho_r_evaluator_reason
#' @export rho_r_evaluation_outcome
#' @export rho_r_tool_result
#' @export rho_r_evaluator_overlap
#' @export rho_tool_read
#' @export rho_tool_write
#' @export rho_tool_bash
#' @export rho_tool_r
#' @export rho_coding_tools
#' @importFrom utils capture.output
NULL
