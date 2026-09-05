
# rho.duckdb

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

[`rho.duckdb`](https://rgenomicsetl.github.io/Rho/rho.duckdb/)
implements the database-neutral
[`rho.bio`](https://rgenomicsetl.github.io/Rho/rho.bio/) SQL generics
for DuckDB. Queries return tasks, but the current guard is only a
first-token and forbidden-keyword check. It is **not safe for
model-authored or otherwise untrusted SQL**; parser-backed statement and
resource admission is tracked in [issue
\#7](https://github.com/RGenomicsETL/Rho/issues/7).

## An asynchronous query

``` r
library(rho.async)
library(rho.bio)
library(rho.duckdb)

connection <- rho_duckdb_connect()
rows <- rho_sql_all(
  connection,
  "select * from (values ('TP53', 12), ('BRCA1', 8)) as genes(gene, samples)"
) |>
  rho_await(timeout = 5000)
rho_duckdb_disconnect(connection)
rows
#>    gene samples
#> 1  TP53      12
#> 2 BRCA1       8
```

`rho_check_readonly_sql()` rejects a small set of obvious write, DDL,
extension-loading, and attach spellings. It does not establish
one-statement, AST, relation, path, network, or effect safety. The S7
connection class remains the dispatch point for a future parser-backed
guard.

See the [`rho.duckdb`
reference](https://rgenomicsetl.github.io/Rho/rho.duckdb/reference/) and
the upstream [`rho.bio`](https://rgenomicsetl.github.io/Rho/rho.bio/)
contracts.
