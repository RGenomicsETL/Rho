# Generated from inst/tinytest/rmd/rho.ai-model-catalog.Rmd; do not edit.

library(tinytest)
library(rho)

catalog <- rho_default_model_catalog()

expect_true(S7::S7_inherits(catalog, ModelCatalog))
expect_true(all(vapply(
  catalog@records,
  S7::S7_inherits,
  logical(1),
  class = ModelCatalogRecord
)))
expect_true(all(vapply(
  catalog@sources,
  function(source) nchar(source@sha256) == 64L,
  logical(1)
)))
expect_true(all(c(
  "anthropic",
  "github-copilot",
  "kimi-coding",
  "openai",
  "openai-codex",
  "zai",
  "zai-coding-cn"
) %in% vapply(
  catalog@records,
  function(record) record@provider@id,
  character(1)
)))

kimi_record <- Filter(
  function(candidate) {
    identical(candidate@provider@id, "kimi-coding") &&
      identical(candidate@id, "k3")
  },
  catalog@records
)[[1L]]

expect_true(S7::S7_inherits(
  kimi_record@provider,
  KimiCodeModelCatalogProvider
))
expect_true(S7::S7_inherits(
  kimi_record@protocol,
  AnthropicMessagesProtocol
))
expect_true(S7::S7_inherits(
  rho_compile_catalog_model(kimi_record)@compatibility@thinking,
  AnthropicAdaptiveThinkingCapability
))

record <- Filter(
  function(candidate) {
    identical(candidate@provider@id, "github-copilot") &&
      identical(candidate@id, "gpt-5.3-codex")
  },
  catalog@records
)[[1L]]
expression <- rho_model_expression(record@provider, record@protocol, record)
model <- rho_compile_catalog_model(record)

expect_true(is.call(expression))
expect_identical(expression[[1L]], quote(rho_new_model))
expect_identical(expression$class, quote(GitHubCopilotResponsesModel))
expect_true(S7::S7_inherits(model, GitHubCopilotResponsesModel))
expect_equal(model@limits@context_window, 400000L)
expect_equal(model@capabilities@input, c("text", "image"))
expect_equal(model@capabilities@thinking_level_map$minimal, "low")
expect_equal(
  vapply(model@capabilities@transports, rho_transport_id, character(1)),
  c("sse", "websocket")
)
expect_equal(record@source@id, "github-copilot")

responses <- rho_catalog_models(
  catalog,
  "github-copilot",
  OpenAIResponsesProtocol()
)
messages <- rho_catalog_models(
  catalog,
  "github-copilot",
  AnthropicMessagesProtocol()
)
completions <- rho_catalog_models(
  catalog,
  "github-copilot",
  OpenAIChatCompletionsProtocol()
)

expect_true(length(responses) > 0L)
expect_true(length(messages) > 0L)
expect_true(length(completions) > 0L)
expect_true(all(vapply(
  responses,
  S7::S7_inherits,
  logical(1),
  class = OpenAIResponsesModel
)))
expect_true(all(vapply(
  messages,
  S7::S7_inherits,
  logical(1),
  class = AnthropicMessagesModel
)))
expect_true(all(vapply(
  completions,
  S7::S7_inherits,
  logical(1),
  class = OpenAIChatCompletionsModel
)))

zai <- rho_catalog_model(catalog, "zai", "glm-5.2")
codex <- rho_catalog_model(catalog, "openai-codex", "gpt-5.3-codex-spark")

expect_true(S7::S7_inherits(zai, ZaiChatCompletionsModel))
expect_true(S7::S7_inherits(zai@thinking_control, ZaiThinkingControl))
expect_identical(zai@thinking_control@preserve_previous, TRUE)
expect_equal(zai@limits@context_window, 1000000L)
expect_true(S7::S7_inherits(codex, OpenAIResponsesModel))
expect_equal(codex@api, "openai-codex-responses")
expect_equal(vapply(
  codex@capabilities@transports,
  rho_transport_id,
  character(1)
), c(
  "sse",
  "websocket",
  "websocket-cached"
))

expect_equal(
  rho_openai_codex_model("gpt-5.3-codex-spark")@limits@context_window,
  codex@limits@context_window
)
expect_equal(
  rho_github_copilot_model("gpt-5.3-codex")@limits@context_window,
  model@limits@context_window
)
expect_true(S7::S7_inherits(
  rho_zai_model("glm-5.2"),
  ZaiChatCompletionsModel
))

missing <- rho_catalog_model(catalog, "openai", "not-a-model")

expect_true(S7::S7_inherits(missing, ModelCatalogModelNotFound))
expect_equal(missing@provider, "openai")
expect_equal(missing@model, "not-a-model")
expect_identical(missing@retryable, FALSE)

bindings <- rho_catalog_bindings(catalog)

expect_true(bindingIsActive("github-copilot", bindings))
copilot <- bindings[["github-copilot"]]
expect_true(is.environment(copilot))
expect_true(bindingIsActive("gpt-5.3-codex", copilot))

first <- copilot[["gpt-5.3-codex"]]
second <- copilot[["gpt-5.3-codex"]]
expect_true(S7::S7_inherits(first, OpenAIResponsesModel))
expect_identical(first, second)
expect_error(
  copilot[["gpt-5.3-codex"]] <- first,
  pattern = "read-only"
)

defaults <- rho_default_model_bindings()
expect_true(bindingIsActive("openai-codex", defaults))
expect_true(S7::S7_inherits(
  defaults[["openai-codex"]][["gpt-5.3-codex-spark"]],
  OpenAIResponsesModel
))
