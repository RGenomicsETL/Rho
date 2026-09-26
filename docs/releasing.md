# Publishing Rho

`rho` is one top-level package. `VERSION` and `DESCRIPTION` must agree;
`make check-version` verifies the release version. The `Remotes` field points
to the pinned RGenomicsETL nanonext fork used for streaming HTTP. A CRAN-style
`R CMD check` does not install `Remotes`; install dependencies with `make deps`
before running the package checks.

Run `make rd`, `make rdm`, and `make purl-tests` to regenerate the namespace,
manuals, README, and executable tests. Run `make test` and `make check`, and
require `R CMD check --no-manual` to report `Status: OK` before publishing.
Review the Pi parity ledger separately; package checks do not prove parity.

The repository history scan uses Gitleaks 8.30.1. CI installs its Linux x86-64
release archive with SHA-256 digest
`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`.
Local runs require the same `gitleaks` executable on `PATH`.

Before releasing, confirm that the pinned nanonext streaming commit is publicly
available to the build environment. Track its upstream API in
[nanonext issue #329](https://github.com/r-lib/nanonext/issues/329).
