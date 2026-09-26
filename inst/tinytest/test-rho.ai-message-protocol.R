# Generated from inst/tinytest/rmd/rho.ai-message-protocol.Rmd; do not edit.

library(tinytest)
library(rho)

msg <- rho_user_message("hello", timestamp = 1)
expect_equal(msg@content, "hello")
expect_equal(msg@timestamp, 1)

tool <- rho_tool_spec("echo", description = "echo", parameters = list(required = "x"), execute = function(id, params, signal, on_update, ctx) rho_tool_result(list(rho_text(params$x))))
args <- rho_validate_tool_args(tool, list(x = "ok"))
expect_equal(args$x, "ok")
invalid <- rho_validate_tool_args(tool, list())
expect_true(S7::S7_inherits(invalid, ToolErrorResult))
expect_equal(invalid@details$missing, "x")
