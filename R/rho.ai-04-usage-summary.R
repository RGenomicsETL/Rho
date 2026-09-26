S7::method(rho_usage_observations, S7::class_any) <- function(x, ...) list()

S7::method(rho_usage_observations, UsageObservation) <- function(x, ...) {
  list(x)
}

S7::method(rho_usage_observations, AssistantMessage) <- function(x, ...) {
  rho_usage_observations(x@usage)
}

S7::method(rho_usage_observations, S7::class_list) <- function(x, ...) {
  Reduce(
    function(observations, value) c(observations, rho_usage_observations(value)),
    x,
    init = list()
  )
}

rho_usage_component_total <- function(observations, property) {
  sum(vapply(
    observations,
    function(observation) S7::prop(observation, property),
    double(1)
  ))
}

S7::method(rho_summarize_usage, S7::class_any) <- function(x, ...) {
  observations <- rho_usage_observations(x)
  counted <- Filter(
    function(observation) S7::S7_inherits(observation, Usage),
    observations
  )
  reported <- Filter(
    function(observation) S7::S7_inherits(observation, ProviderUsage),
    observations
  )
  estimated <- Filter(
    function(observation) S7::S7_inherits(observation, EstimatedUsage),
    observations
  )
  unavailable <- Filter(
    function(observation) S7::S7_inherits(observation, UsageUnavailable),
    observations
  )
  unpriced <- Filter(function(observation) is.null(observation@cost), counted)
  costs <- lapply(counted, function(observation) observation@cost)
  nominal_costs <- Filter(
    function(cost) S7::S7_inherits(cost, NominalUsageCost),
    costs
  )
  input <- rho_usage_component_total(counted, "input")
  output <- rho_usage_component_total(counted, "output")
  cache_read <- rho_usage_component_total(counted, "cache_read")
  cache_write <- rho_usage_component_total(counted, "cache_write")
  latest_cache_hit_rate <- NULL
  if (length(counted)) {
    latest <- counted[[length(counted)]]
    latest_prompt <- latest@input + latest@cache_read + latest@cache_write
    if (latest_prompt > 0) {
      latest_cache_hit_rate <- as.double(latest@cache_read / latest_prompt)
    }
  }
  complete <- length(counted) == length(observations)
  UsageSummary(
    observations = observations,
    reported = reported,
    estimated = estimated,
    unavailable = unavailable,
    unpriced = unpriced,
    input = input,
    output = output,
    cache_read = cache_read,
    cache_write = cache_write,
    total = input + output + cache_read + cache_write,
    nominal_cost = rho_nominal_usage_cost(
      input = rho_usage_component_total(nominal_costs, "input"),
      output = rho_usage_component_total(nominal_costs, "output"),
      cache_read = rho_usage_component_total(nominal_costs, "cache_read"),
      cache_write = rho_usage_component_total(nominal_costs, "cache_write")
    ),
    complete = complete,
    cost_complete = complete && !length(unpriced),
    latest_cache_hit_rate = latest_cache_hit_rate
  )
}
