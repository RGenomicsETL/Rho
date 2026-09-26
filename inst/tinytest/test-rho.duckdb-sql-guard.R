# Generated from inst/tinytest/rmd/rho.duckdb-sql-guard.Rmd; do not edit.

library(tinytest)
library(rho)

accepted <- rho_check_readonly_sql("select 1")
rejected <- rho_check_readonly_sql("drop table x")

expect_true(S7::S7_inherits(accepted, RhoSqlAccepted))
expect_true(S7::S7_inherits(rejected, RhoSqlRejected))
expect_match(rejected@message, "read-only|forbidden")

connection <- rho_duckdb_connect()
result <- rho::rho_sql_all(connection, "select 42::integer as answer") |>
  rho::rho_await(timeout = 5000)
rho_duckdb_disconnect(connection)

expect_equal(result$answer, 42L)
