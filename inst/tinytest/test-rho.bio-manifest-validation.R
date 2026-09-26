# Generated from inst/tinytest/rmd/rho.bio-manifest-validation.Rmd; do not edit.

library(tinytest)
library(rho)

reg <- rho_bio_registry()
res <- rho_resolver_spec("file.scan", "0.1.0", "File scan", "scan file")
vr <- rho_virtual_resource("variants", "Variants", "file.scan", list(path = "x.csv"))
manifest <- rho_manifest("demo", "0.1.0", "Demo", "Demo", provides = list(resolvers = list(res), resources = list(vr)))
rho_register_manifest(reg, manifest)
failure <- rho_await(rho_resolve_resource(reg, "variants"), timeout = 1000L)
expect_true(S7::S7_inherits(failure, BioErrorValue))
expect_equal(failure@code, "resolver_unbound")

state <- new.env(parent = emptyenv())
state$resolve <- NULL
rho_bind_resolver_impl(reg, "file.scan", function(resource, ctx) {
  rho_task_from_promise(promises::promise(function(resolve, reject) {
    state$resolve <- resolve
  }))
})

resolution <- rho_resolve_resource(reg, "variants")
expect_true(rho_pending(resolution))
state$resolve(list(
  result = rho_resource_handle("file", "x.csv", "text/csv"),
  provenance = list(origin = "fixture")
))
receipt <- rho_await(resolution, timeout = 1000L)

expect_true(S7::S7_inherits(receipt, ResolutionReceipt))
expect_equal(receipt@result@value, "x.csv")
expect_equal(receipt@provenance$origin, "fixture")

cancel_reason <- NULL
rho_bind_resolver_impl(
  reg,
  "file.scan",
  function(resource, ctx) {
    rho_task_from_promise(
      promises::promise(function(resolve, reject) NULL),
      cancel = function(reason) cancel_reason <<- reason
    )
  },
  replace = TRUE
)

resolution <- rho_resolve_resource(reg, "variants")
expect_true(rho_cancel(resolution, reason = "cancel resolution"))
expect_equal(cancel_reason, "cancel resolution")
expect_true(S7::S7_inherits(
  rho_await(resolution, timeout = 1000L),
  RhoCancellation
))
