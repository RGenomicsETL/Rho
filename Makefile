.PHONY: deps install test check rd rdm rdm-codex purl-tests check-purled-tests format check-format check-style check-version check-publication check-models check-parity check-secrets hooks models site

R ?= R
RSCRIPT ?= Rscript

# remotes honors the pinned fork in DESCRIPTION's Remotes field.
deps:
	$(RSCRIPT) -e 'remotes::install_deps(dependencies = TRUE)'

install:
	$(R) CMD INSTALL .

hooks:
	git config core.hooksPath .githooks

models:
	$(RSCRIPT) data-raw/compile-model-catalog.R

check-models:
	$(RSCRIPT) data-raw/compile-model-catalog.R --check

test: purl-tests install
	$(RSCRIPT) -e 'x <- tinytest::test_package("rho", verbose = 0); print(summary(x)); stopifnot(tinytest::all_pass(x))'

check: purl-tests
	$(R) CMD build .
	$(R) CMD check --no-manual rho_$$(cat VERSION).tar.gz

rd:
	$(RSCRIPT) -e 'roxygen2::roxygenise()'

rdm:
	$(RSCRIPT) scripts/render-readmes.R

rdm-codex:
	$(RSCRIPT) scripts/render-readmes.R "$(CREDENTIAL)"

purl-tests:
	$(RSCRIPT) scripts/purl-tests.R

check-purled-tests:
	$(RSCRIPT) scripts/purl-tests.R --check

format:
	air format R inst/tinytest/rmd scripts data-raw

check-format:
	air format R inst/tinytest/rmd scripts data-raw --check

check-style:
	$(RSCRIPT) scripts/check-style.R

check-version:
	$(RSCRIPT) scripts/check-version.R

check-publication:
	$(RSCRIPT) scripts/check-publication.R

check-parity:
	$(RSCRIPT) scripts/check-parity.R

check-secrets:
	$(RSCRIPT) scripts/check-secrets.R

site:
	$(RSCRIPT) scripts/build-site.R
