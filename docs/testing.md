# Rmd-driven tinytest

Edit `inst/tinytest/rmd/*.Rmd` only. Generate test files with:

```bash
Rscript scripts/purl-tests.R
```

CI uses:

```bash
make check-purled-tests
make check-style
make test
make check
```

Generated `inst/tinytest/test-*.R` files are committed to make `tinytest::test_package()` ordinary and transparent.

`make check` builds the `rho` source tarball and runs `R CMD check --no-manual`
on that single package. Install dependencies first using `make deps`.
Roxygen2 documentation is regenerated with `make rd`; the committed `NAMESPACE`
and `man/` files are generated artifacts.
