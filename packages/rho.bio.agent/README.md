
# rho.bio.agent

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

[`rho.bio.agent`](https://rgenomicsetl.github.io/Rho/rho.bio.agent/) is
currently a thin `rho.ext` prototype that registers one manifest-listing
tool. It does **not yet bind that tool to a `rho.agent`, resolve
resources, execute manifest operations or SQL, retain receipts, or
project a ledger**. The first real downstream integration is tracked in
[issue \#9](https://github.com/RGenomicsETL/Rho/issues/9).

## Register and call a bio tool

``` r
library(rho.async)
library(rho.ai)
library(rho.bio)
library(rho.ext)
library(rho.bio.agent)

registry <- rho_bio_registry()
rho_register_manifest(registry, rho_manifest(
  id = "example",
  version = "1.0.0",
  title = "Example manifest",
  description = "A registered manifest"
))

runtime <- rho_extension_runtime()
rho_register_bio_extension(rho_extension_api(runtime), registry)
tool <- get("bio_describe_manifest", runtime@state$tools)
result <- rho_execute_tool(
  tool,
  ToolCall("bio-1", "bio_describe_manifest", list()),
  context = NULL
) |>
  rho_await(timeout = 1000)

list(
  tool = tool@name,
  manifests = result@details$count
)
#> $tool
#> [1] "bio_describe_manifest"
#>
#> $manifests
#> [1] 1
```

This example translates registry facts into a manually retrieved tool
result; it proves neither agent integration nor a receipt-backed
bioinformatics answer. Do not expand the package surface until the
declared-resource vertical slice in issue \#9 is executable.

See the [`rho.bio.agent`
reference](https://rgenomicsetl.github.io/Rho/rho.bio.agent/reference/)
and the underlying
[`rho.bio`](https://rgenomicsetl.github.io/Rho/rho.bio/) substrate.
