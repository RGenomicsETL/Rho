# Generated from inst/tinytest/rmd/rho.ext-extension-runtime.Rmd; do not edit.

library(tinytest)
library(rho)

rt <- rho_extension_runtime()
api <- rho_extension_api(rt)
rho_on(api, "ping", function(event, ctx) list(ok = TRUE))
out <- rho_await(rho_dispatch_event(rt, list(type = "ping")), timeout = 1000L)
expect_equal(length(out), 1)
expect_true(out[[1]]$ok)

rt <- rho_extension_runtime()
api <- rho_extension_api(rt)
state <- new.env(parent = emptyenv())
state$resolve <- NULL
state$second_started <- FALSE

rho_on(api, "ordered", function(event, ctx) {
  rho_task_from_promise(promises::promise(function(resolve, reject) {
    state$resolve <- resolve
  }))
})
rho_on(api, "ordered", function(event, ctx) {
  state$second_started <- TRUE
  "second"
})

dispatched <- rho_dispatch_event(rt, list(type = "ordered"))
later::run_now(0.05)
expect_false(state$second_started)
state$resolve("first")
expect_equal(
  rho_await(dispatched, timeout = 1000L),
  list("first", "second")
)
expect_true(state$second_started)

rt <- rho_extension_runtime()
api <- rho_extension_api(rt)
cancel_reason <- NULL
rho_on(api, "cancel", function(event, ctx) {
  rho_task_from_promise(
    promises::promise(function(resolve, reject) NULL),
    cancel = function(reason) cancel_reason <<- reason
  )
})

dispatched <- rho_dispatch_event(rt, list(type = "cancel"))
expect_true(rho_cancel(dispatched, reason = "stop dispatch"))
expect_equal(cancel_reason, "stop dispatch")
expect_true(S7::S7_inherits(
  rho_await(dispatched, timeout = 1000L),
  RhoCancellation
))
