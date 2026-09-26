#' DuckDB implementation of the Rho SQL contract
#'
#' Connections are explicit `RhoDuckDbConn` values. Queries and statements
#' return tasks through the generic SQL API declared in `rho.bio`.
#' `rho_check_readonly_sql()` is intentionally conservative and is not a
#' substitute for the parser-backed guard required before accepting untrusted
#' SQL. It returns a typed `RhoSqlAccepted` or `RhoSqlRejected` value. Database
#' failures resolve to `RhoDuckDbErrorValue` rather than aborting the task.
#'
#' @name rho_duckdb_contracts
#' @aliases RhoDuckDbConn RhoDuckDbErrorValue RhoSqlStatement RhoSqlGuard
#' @aliases RhoConservativeSqlGuard RhoSqlGuardResult RhoSqlAccepted
#' @aliases RhoSqlRejected rho_duckdb_connect rho_duckdb_disconnect
#' @aliases rho_sql_guard rho_check_readonly_sql
#' @export RhoDuckDbConn
#' @export RhoDuckDbErrorValue
#' @export RhoSqlStatement
#' @export RhoSqlGuard
#' @export RhoConservativeSqlGuard
#' @export RhoSqlGuardResult
#' @export RhoSqlAccepted
#' @export RhoSqlRejected
#' @export rho_duckdb_connect
#' @export rho_duckdb_disconnect
#' @export rho_sql_guard
#' @export rho_check_readonly_sql
NULL
