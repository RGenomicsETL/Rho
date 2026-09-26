# Generated from inst/tinytest/rmd/rho.ai-usage.Rmd; do not edit.

library(tinytest)
library(rho)

usage <- rho_provider_usage(
  provider = "fixture",
  input = 1e6,
  output = 1e5,
  cache_read = 5e5,
  cache_write = 1e5,
  cache_write_1h = 4e4,
  reasoning = 2e4
)

expect_true(S7::S7_inherits(usage, ProviderUsage))
expect_equal(usage@total, 1.7e6)
expect_equal(usage@reasoning, 2e4)
expect_equal(usage@cache_write_1h, 4e4)
expect_error(
  rho_provider_usage(provider = "fixture", output = 3, reasoning = 4),
  "subset of @output"
)
expect_error(
  rho_provider_usage(provider = "fixture", cache_write = 1, cache_write_1h = 2),
  "subset of @cache_write"
)

model <- rho_model(
  provider = "fixture",
  id = "priced",
  pricing = rho_model_pricing(
    input = 2,
    output = 8,
    cache_read = 0.2,
    cache_write = 2.5
  )
)
priced <- rho_price_usage(model, usage)

expect_true(S7::S7_inherits(priced@cost, UsageCost))
expect_equal(priced@cost@input, 2)
expect_equal(priced@cost@output, 0.8)
expect_equal(priced@cost@cache_read, 0.1)
expect_equal(priced@cost@cache_write, 0.31)
expect_equal(priced@cost@total, 3.21)
expect_true(S7::S7_inherits(priced, ProviderUsage))
expect_true(S7::S7_inherits(priced@cost, NominalUsageCost))
expect_null(usage@cost)

tiered <- rho_model(
  provider = "fixture",
  id = "tiered",
  pricing = rho_model_pricing(
    input = 1,
    output = 2,
    tiers = list(rho_model_pricing_tier(
      input_tokens_above = 1e6,
      input = 3,
      output = 6,
      cache_read = 0.3,
      cache_write = 3.75
    ))
  )
)
tiered_usage <- rho_price_usage(
  tiered,
  rho_provider_usage(
    provider = "fixture",
    input = 9e5,
    output = 1e5,
    cache_read = 2e5
  )
)

expect_equal(tiered_usage@cost@input, 2.7)
expect_equal(tiered_usage@cost@output, 0.6)
expect_equal(tiered_usage@cost@cache_read, 0.06)
expect_equal(tiered_usage@cost@total, 3.36)

estimated <- rho_estimated_usage(
  estimator = "character-count",
  method = "ceil(bytes / 4)",
  input = 12,
  output = 3
)
unavailable <- rho_usage_unavailable(
  provider = "subscription-provider",
  reason = "The provider response did not include token counts"
)
default_message <- rho_assistant_message(provider = "subscription-provider")

expect_true(S7::S7_inherits(estimated, EstimatedUsage))
expect_equal(estimated@estimator, "character-count")
expect_equal(estimated@method, "ceil(bytes / 4)")
expect_null(estimated@cost)
expect_true(S7::S7_inherits(unavailable, UsageUnavailable))
expect_equal(unavailable@provider, "subscription-provider")
expect_equal(unavailable@reason, "The provider response did not include token counts")
expect_identical(rho_price_usage(model, unavailable), unavailable)
expect_true(S7::S7_inherits(default_message@usage, UsageUnavailable))
expect_equal(default_message@usage@provider, "subscription-provider")

estimated_priced <- rho_price_usage(model, estimated)
summary <- rho_summarize_usage(list(
  rho_assistant_message(usage = priced),
  rho_assistant_message(usage = estimated_priced),
  rho_assistant_message(usage = unavailable)
))

expect_true(S7::S7_inherits(summary, UsageSummary))
expect_equal(length(summary@reported), 1L)
expect_equal(length(summary@estimated), 1L)
expect_equal(length(summary@unavailable), 1L)
expect_equal(summary@input, priced@input + estimated_priced@input)
expect_equal(summary@output, priced@output + estimated_priced@output)
expect_equal(summary@cache_read, priced@cache_read)
expect_equal(summary@cache_write, priced@cache_write)
expect_equal(
  summary@nominal_cost@total,
  priced@cost@total + estimated_priced@cost@total
)
expect_false(summary@complete)
expect_false(summary@cost_complete)
expect_equal(summary@latest_cache_hit_rate, 0)

unpriced_summary <- rho_summarize_usage(list(
  rho_assistant_message(usage = estimated)
))
expect_true(unpriced_summary@complete)
expect_false(unpriced_summary@cost_complete)
expect_equal(length(unpriced_summary@unpriced), 1L)
