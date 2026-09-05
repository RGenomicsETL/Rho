
# Rho

<!-- badges: start -->

[![R-CMD-check](https://github.com/RGenomicsETL/Rho/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RGenomicsETL/Rho/actions/workflows/R-CMD-check.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**An asynchronous agent runtime for R, inspired by
[Pi](https://github.com/badlogic/pi-mono).**

Rho expresses Pi’s provider and agent architecture through S7 classes
and open generics. nanonext provides asynchronous I/O, and mirai
provides worker evaluation.

An effectful operation returns a task or stream. Waiting is an explicit
edge operation, so a CLI can block while a Shiny application, extension,
or another agent keeps composing work.

## An agent run

The deterministic provider is the executable specification for the same
event protocol used by live providers. `rho_prompt()` returns before the
result is collected; `rho_await()` is the explicit wait.

``` r
library(rho.async)
library(rho.ai)
library(rho.agent)

agent <- rho_agent(
  provider = rho_faux_provider(),
  model = rho_model(provider = "faux", id = "faux")
)

run_task <- rho_prompt(agent, "hello from R")
rho_is_task(run_task)
#> [1] TRUE

run <- rho_await(run_task, timeout = 5000)
c(
  status = run@status,
  answer = run@messages[[2L]]@content[[1L]]@text
)
#>               status               answer
#>          "completed" "faux: hello from R"
```

The transcript contains typed messages and content; the lifecycle is an
ordered sequence of typed events rather than callbacks hidden inside the
provider.

``` r
vapply(run@events, function(event) event@type, character(1))
#>  [1] "agent_start"    "turn_start"     "message_start"  "message_end"
#>  [5] "message_start"  "message_update" "message_update" "message_update"
#>  [9] "message_end"    "turn_end"       "agent_end"      "agent_settled"
```

## OpenAI Codex with explicit credentials

Live authentication is a value passed to the provider catalog. Rho does
not search environment variables or process-global credential state. The
importer accepts a Pi or Codex auth file only when its path is supplied
by the caller.

``` r
library(rho.coding)

credential_path <- getOption("rho.openai_codex_credential")
credential <- rho_load_openai_codex_credential(
  path = credential_path
) |>
  rho_await(timeout = 5000)

codex_provider <- rho_openai_codex_provider()
models <- rho_models(
  providers = list(codex_provider),
  credentials = rho_memory_credential_store(
    list(`openai-codex` = credential)
  )
)

codex_model <- rho_openai_codex_model("gpt-5.3-codex-spark")
codex_agent <- rho_agent(
  provider = models,
  model = codex_model,
  tools = list(rho_tool_r()),
  stream_options = list(reasoning_effort = "minimal")
)

codex_run <- rho_prompt(
  codex_agent,
  paste(
    "Call the r tool exactly once with code sum((1:100)^2).",
    "Then answer with only the integer result."
  )
) |>
  rho_await(timeout = 120000)

tool_result <- codex_run@tool_results[[1L]]
result <- tool_result@content[[1L]]@text

codex_example <- data.frame(
  model = codex_model@id,
  status = codex_run@status,
  tool = tool_result@tool_name,
  result = result
)
codex_example
```

Rebuild this example by supplying the credential file explicitly:

``` bash
make rdm-codex CREDENTIAL=/absolute/path/to/auth.json
```

## The packages

Rho keeps transport, provider semantics, agent policy, and applications
in separate installable packages. Each package has a focused README and
reference site.

| package | role | documentation |
|---|---|---|
| **rho.async** | tasks, streams, cancellation, timeouts, and composition | [guide](https://rgenomicsetl.github.io/Rho/rho.async/) · [reference](https://rgenomicsetl.github.io/Rho/rho.async/reference/) |
| **rho.http** | transport-neutral HTTP requests, response bodies, and SSE decoding, with a nanonext client | [guide](https://rgenomicsetl.github.io/Rho/rho.http/) · [reference](https://rgenomicsetl.github.io/Rho/rho.http/reference/) |
| **rho.http.httr2** | worker-owned httr2 implementation of the HTTP client contract | [guide](https://rgenomicsetl.github.io/Rho/rho.http.httr2/) · [reference](https://rgenomicsetl.github.io/Rho/rho.http.httr2/reference/) |
| **rho.ai** | messages, models, capabilities, credentials, providers, and tools | [guide](https://rgenomicsetl.github.io/Rho/rho.ai/) · [reference](https://rgenomicsetl.github.io/Rho/rho.ai/reference/) |
| **rho.agent** | multi-turn execution, session compaction, tool scheduling, queues, cancellation, and events | [guide](https://rgenomicsetl.github.io/Rho/rho.agent/) · [reference](https://rgenomicsetl.github.io/Rho/rho.agent/reference/) |
| **rho.ext** | asynchronous extension handlers and capability registration | [guide](https://rgenomicsetl.github.io/Rho/rho.ext/) · [reference](https://rgenomicsetl.github.io/Rho/rho.ext/reference/) |
| **rho.compute** | typed mirai expression and function-call tasks | [guide](https://rgenomicsetl.github.io/Rho/rho.compute/) · [reference](https://rgenomicsetl.github.io/Rho/rho.compute/reference/) |
| **rho.graphics** | declared graphics devices and hashed artifacts | [guide](https://rgenomicsetl.github.io/Rho/rho.graphics/) · [reference](https://rgenomicsetl.github.io/Rho/rho.graphics/reference/) |
| **rho.coding** | Bash, file, isolated-worker R, and explicit current-session R tools | [guide](https://rgenomicsetl.github.io/Rho/rho.coding/) · [reference](https://rgenomicsetl.github.io/Rho/rho.coding/reference/) |
| **rho.bio** | manifests, resolvers, receipts, and database-neutral SQL contracts | [guide](https://rgenomicsetl.github.io/Rho/rho.bio/) · [reference](https://rgenomicsetl.github.io/Rho/rho.bio/reference/) |
| **rho.duckdb** | DuckDB implementation of the asynchronous SQL contracts | [guide](https://rgenomicsetl.github.io/Rho/rho.duckdb/) · [reference](https://rgenomicsetl.github.io/Rho/rho.duckdb/reference/) |
| **rho.bio.agent** | bioinformatics tools registered through the extension API | [guide](https://rgenomicsetl.github.io/Rho/rho.bio.agent/) · [reference](https://rgenomicsetl.github.io/Rho/rho.bio.agent/reference/) |
| **rho.testkit** | bounded assertions for asynchronous tests | [guide](https://rgenomicsetl.github.io/Rho/rho.testkit/) · [reference](https://rgenomicsetl.github.io/Rho/rho.testkit/reference/) |

The table names package responsibilities, not completion. The current
`rho.ext` runtime is not connected to `rho.agent`; `rho.bio.agent` only
lists registered manifests; the DuckDB SQL guard is lexical; and coding
file/Bash tools still inherit host filesystem and environment authority.
These gaps are tracked in issues
[\#7](https://github.com/RGenomicsETL/Rho/issues/7),
[\#9](https://github.com/RGenomicsETL/Rho/issues/9), and
[\#11](https://github.com/RGenomicsETL/Rho/issues/11).

Provider implementations with no independent dependency or ABI
constraint live in `rho.ai`. OpenAI Codex, GitHub Copilot, Z.ai, OpenAI,
Anthropic, Ollama, and the deterministic faux provider therefore share
one typed provider surface without a package per API. The [Pi parity
ledger](https://rgenomicsetl.github.io/Rho/docs/pi-parity.html)
distinguishes complete wire adapters from request translators whose
normalized stream is not yet complete. OpenAI, OpenAI Codex, GitHub
Copilot, Z.ai, and Anthropic have executable normalized-stream fixtures;
the ledger records the executable and external-account evidence for each
adapter.

Bioinformatics remains downstream: `rho.bio`, `rho.duckdb`, and
`rho.bio.agent` consume the provider and agent substrate but do not
define it.

## Install and develop

Rho targets R 4.4 or newer. Install the development monorepo from a
checkout:

``` bash
git clone git@github.com:RGenomicsETL/Rho.git
cd Rho
make deps
make hooks
make install
```

The authored API documentation is roxygen; the authored tests are R
Markdown files under each package’s `inst/tinytest/rmd/` directory.
Generated manuals, namespaces, executable tests, and READMEs are
reproducible from their sources.

``` bash
make format       # Air
make rd           # roxygen2
make purl-tests   # Rmd tests -> executable tinytest files
make rdm          # rebuild package READMEs
make check-publication
make check-secrets # Gitleaks over history and working tree
make test
make check        # every package must report Status: OK
make public-ready # complete publication gate
```

The [Pi parity
ledger](https://rgenomicsetl.github.io/Rho/docs/pi-parity.html) records
behavioral contracts and the fixtures that verify them. Public release
and addition to the [RGenomicsETL
R-universe](https://rgenomicsetl.r-universe.dev) follow green package
checks, live provider checks, documentation, and secret scanning. The
exact sequence is recorded in the [publishing
guide](https://rgenomicsetl.github.io/Rho/docs/releasing.html).

## License

MIT.
