
# rho.coding

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

[`rho.coding`](https://rgenomicsetl.github.io/Rho/rho.coding/) supplies
coding tools for file operations, Bash, isolated R evaluation in mirai,
and opt-in evaluation in a caller-supplied current-session environment.
The current file tools use the host user’s ordinary filesystem
permissions, and the Bash tool inherits the current process environment
by default. They are **not a sandbox or an explicit least-authority
execution profile**; that work is tracked in [issue
\#11](https://github.com/RGenomicsETL/Rho/issues/11).

## Isolated R evaluation

``` r
library(rho.async)
library(rho.ai)
library(rho.agent)
library(rho.coding)

r_tool <- rho_tool_r()
result <- rho_execute_tool(
  r_tool,
  ToolCall(
    id = "readme-r-1",
    name = "r",
    arguments = list(code = "sum((1:6)^2)")
  ),
  context = NULL
) |>
  rho_await(timeout = 10000)

data.frame(
  value = result@details$value,
  may_overlap = S7::S7_inherits(r_tool@overlap, ToolMayOverlap)
)
#>   value may_overlap
#> 1    91        TRUE
```

The ordinary R tool runs in an isolated mirai worker and may overlap
with another call. A `RhoCurrentSessionREvaluator` instead receives an
explicit environment and requires exclusive scheduling. `RhoRExpression`
is also a `RhoOperation`, and the chosen evaluator is recorded in a
`RhoREvaluationBinding`. Bash resolves a real Bash implementation rather
than translating model-generated Bash into another shell language. Mirai
placement alone does not restrict Bash filesystem, environment, process,
or network authority.

## Session replay

The coding host may persist the agent journal as locked JSONL without
making a path part of the agent contract. Versioned semantic records
form the storage schema; package names, S7 class names, and reflected
properties are not stored. Explicit adapters translate between those
records and the current R classes. The project documentation records the
[schema evolution
rules](https://rgenomicsetl.github.io/Rho/docs/session-jsonl-schema.html).

``` r
path <- tempfile(fileext = ".jsonl")
journal <- rho_jsonl_session_journal(path)

writer <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = journal
)
run <- rho_prompt(writer, "remember this turn") |>
  rho_await(timeout = 10000)

reader <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = rho_jsonl_session_journal(path)
)
reader <- rho_sync_session(reader) |>
  rho_await(timeout = 10000)

snapshot <- rho_session_snapshot(reader@journal) |>
  rho_await(timeout = 10000)

data.frame(
  committed_entries = snapshot@position,
  restored_messages = length(rho_state_messages(reader))
)
#>   committed_entries restored_messages
#> 1                 2                 2

unlink(c(path, paste0(path, ".lock")))
```

The native format is Rho JSONL, not Pi session JSONL. Pi import or
export can be added as another codec once session identity and branch
lineage are exercised by Rho consumers.

See the [`rho.coding`
reference](https://rgenomicsetl.github.io/Rho/rho.coding/reference/) and
its worker substrate,
[`rho.compute`](https://rgenomicsetl.github.io/Rho/rho.compute/).
