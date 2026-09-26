# Generated from inst/tinytest/rmd/rho.testkit-testkit.Rmd; do not edit.

library(tinytest)
library(rho)

value <- rho:::expect_resolves(rho_task(1), 1)
expect_equal(value, 1)
