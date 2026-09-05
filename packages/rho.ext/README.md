
# rho.ext

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

[`rho.ext`](https://rgenomicsetl.github.io/Rho/rho.ext/) is currently a
standalone extension-registry prototype. It can register handlers,
tools, commands, and providers through an explicit API object, but it is
**not yet bound to `rho.agent`’s typed lifecycle**. Registered tools are
not admitted to an agent automatically, and character event dispatch is
not the intended durable event protocol. That integration-or-removal
decision is tracked in [issue
\#9](https://github.com/RGenomicsETL/Rho/issues/9).

## An asynchronous handler chain

``` r
library(rho.async)
library(rho.ext)

runtime <- rho_extension_runtime()
api <- rho_extension_api(runtime, source = "README")
rho_on(api, "prompt", function(event, context) {
  rho_task(list(text = toupper(event$text)))
})

results <- rho_dispatch_event(
  runtime,
  list(type = "prompt", text = "compose me")
) |>
  rho_await(timeout = 1000)
results[[1L]]
#> $text
#> [1] "COMPOSE ME"
```

The standalone dispatcher normalizes plain handler values and tasks.
This example proves ordering only inside `RhoExtensionRuntime`; it does
not prove agent event ordering, policy admission, committed-session
notification, or shutdown flushing.

See the [`rho.ext`
reference](https://rgenomicsetl.github.io/Rho/rho.ext/reference/), the
upstream [`rho.agent`](https://rgenomicsetl.github.io/Rho/rho.agent/)
lifecycle, and the downstream
[`rho.bio.agent`](https://rgenomicsetl.github.io/Rho/rho.bio.agent/)
application.
