# Generated from inst/tinytest/rmd/rho.graphics-graphics-artifact.Rmd; do not edit.

library(tinytest)
library(rho)

path <- tempfile(fileext = ".png")
spec <- rho_base_graphic(plot(points), data = list(points = 1:3))
t <- rho_render_graphic(
  spec,
  device = rho_png_device(),
  path = path,
  alt = "Three points"
)

expect_true(rho_is_task(t))
artifact <- rho_await(t, timeout = 10000)
expect_true(S7::S7_inherits(artifact, RhoGraphicArtifact))
expect_true(file.exists(artifact@path))
expect_equal(artifact@media_type, "image/png")
expect_equal(artifact@alt, "Three points")
expect_true(file.info(artifact@path)$size > 0)
expect_equal(
  artifact@sha256,
  digest::digest(file = artifact@path, algo = "sha256")
)
expect_false(identical(
  artifact@sha256,
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
))
unlink(artifact@path)
