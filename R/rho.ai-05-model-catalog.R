ModelProtocol <- S7::new_class("ModelProtocol", abstract = TRUE)
OpenAIResponsesProtocol <- S7::new_class(
  "OpenAIResponsesProtocol",
  parent = ModelProtocol
)
OpenAIChatCompletionsProtocol <- S7::new_class(
  "OpenAIChatCompletionsProtocol",
  parent = ModelProtocol
)
AnthropicMessagesProtocol <- S7::new_class(
  "AnthropicMessagesProtocol",
  parent = ModelProtocol
)

ModelCatalogProvider <- S7::new_class(
  "ModelCatalogProvider",
  abstract = TRUE,
  properties = list(
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    base_url = rho_non_empty_string
  )
)
OpenAIModelCatalogProvider <- S7::new_class(
  "OpenAIModelCatalogProvider",
  parent = ModelCatalogProvider
)
OpenAICodexModelCatalogProvider <- S7::new_class(
  "OpenAICodexModelCatalogProvider",
  parent = ModelCatalogProvider
)
GitHubCopilotModelCatalogProvider <- S7::new_class(
  "GitHubCopilotModelCatalogProvider",
  parent = ModelCatalogProvider
)
AnthropicModelCatalogProvider <- S7::new_class(
  "AnthropicModelCatalogProvider",
  parent = ModelCatalogProvider
)
KimiCodeModelCatalogProvider <- S7::new_class(
  "KimiCodeModelCatalogProvider",
  parent = AnthropicModelCatalogProvider
)
KimiPlatformModelCatalogProvider <- S7::new_class(
  "KimiPlatformModelCatalogProvider",
  parent = ModelCatalogProvider
)
ZaiModelCatalogProvider <- S7::new_class(
  "ZaiModelCatalogProvider",
  parent = ModelCatalogProvider,
  properties = list(preserve_thinking = rho_scalar_logical)
)

ModelCatalogSource <- S7::new_class(
  "ModelCatalogSource",
  properties = list(
    id = rho_non_empty_string,
    location = rho_non_empty_string,
    sha256 = rho_non_empty_string
  )
)

ModelCatalogRecord <- S7::new_class(
  "ModelCatalogRecord",
  properties = list(
    provider = ModelCatalogProvider,
    protocol = ModelProtocol,
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    input = rho_input_modalities,
    reasoning = rho_scalar_logical,
    thinking_level_map = rho_thinking_level_map,
    tools = rho_scalar_logical,
    parallel_tool_calls = rho_scalar_logical,
    transports = rho_model_transport_ids,
    context_window = rho_positive_integer,
    max_tokens = rho_positive_integer,
    pricing = ModelPricing,
    headers = S7::class_list,
    provider_capabilities = S7::class_list,
    source = ModelCatalogSource
  )
)

ModelCatalog <- S7::new_class(
  "ModelCatalog",
  properties = list(
    records = S7::class_list,
    sources = S7::class_list
  ),
  validator = function(self) {
    invalid_records <- Filter(
      function(record) !S7::S7_inherits(record, ModelCatalogRecord),
      self@records
    )
    if (length(invalid_records)) {
      return("@records must contain only ModelCatalogRecord values")
    }
    invalid_sources <- Filter(
      function(source) !S7::S7_inherits(source, ModelCatalogSource),
      self@sources
    )
    if (length(invalid_sources)) {
      "@sources must contain only ModelCatalogSource values"
    }
  }
)

ModelCatalogModelNotFound <- S7::new_class(
  "ModelCatalogModelNotFound",
  parent = ProviderErrorValue,
  properties = list(
    provider = rho_non_empty_string,
    model = rho_non_empty_string
  )
)

rho_model_expression <- S7::new_generic(
  "rho_model_expression",
  c("provider", "protocol", "record"),
  function(provider, protocol, record, ...) S7::S7_dispatch()
)

rho_compile_catalog_model <- S7::new_generic(
  "rho_compile_catalog_model",
  "record",
  function(record, ...) S7::S7_dispatch()
)

rho_catalog_models <- S7::new_generic(
  "rho_catalog_models",
  "catalog",
  function(catalog, provider = NULL, protocol = NULL, ...) S7::S7_dispatch()
)

rho_catalog_model <- S7::new_generic(
  "rho_catalog_model",
  "catalog",
  function(catalog, provider, model, ...) S7::S7_dispatch()
)

rho_catalog_bindings <- S7::new_generic(
  "rho_catalog_bindings",
  "catalog",
  function(catalog, ...) S7::S7_dispatch()
)

rho_catalog_source <- function(data) {
  ModelCatalogSource(
    id = data$id,
    location = data$location,
    sha256 = data$sha256
  )
}

rho_catalog_evaluate <- function(expression, class, label) {
  if (!is.call(expression)) {
    rho_signal_contract_violation(
      "Model-catalog %s must be an R constructor call",
      label
    )
  }
  value <- eval(expression, envir = environment(rho_catalog_evaluate))
  if (!S7::S7_inherits(value, class)) {
    rho_signal_contract_violation(
      "Model-catalog %s constructed %s instead of %s",
      label,
      rho_class_label(value),
      class@name
    )
  }
  value
}

rho_catalog_record_from_data <- function(data, sources) {
  source <- sources[[data$source]]
  if (is.null(source)) {
    rho_signal_contract_violation("Unknown model-catalog source: %s", data$source)
  }
  provider <- rho_catalog_evaluate(
    data$provider,
    ModelCatalogProvider,
    "provider"
  )
  protocol <- rho_catalog_evaluate(
    data$protocol,
    ModelProtocol,
    "protocol"
  )
  ModelCatalogRecord(
    provider = provider,
    protocol = protocol,
    id = data$id,
    name = data$name,
    input = unlist(data$input, use.names = FALSE),
    reasoning = isTRUE(data$reasoning),
    thinking_level_map = data$thinking_level_map %||% list(),
    tools = isTRUE(data$tools),
    parallel_tool_calls = isTRUE(data$parallel_tool_calls),
    transports = unlist(data$transports, use.names = FALSE),
    context_window = as.integer(data$context_window),
    max_tokens = as.integer(data$max_tokens),
    pricing = rho_model_pricing(
      input = data$pricing$input,
      output = data$pricing$output,
      cache_read = data$pricing$cache_read,
      cache_write = data$pricing$cache_write
    ),
    headers = data$headers %||% list(),
    provider_capabilities = data$provider_capabilities %||% list(),
    source = source
  )
}

rho_default_model_catalog <- function() {
  if (!identical(rho_model_catalog_data$schema_version, 2L)) {
    rho_signal_contract_violation(
      "Unsupported model-catalog schema version: %s",
      rho_model_catalog_data$schema_version
    )
  }
  sources <- lapply(rho_model_catalog_data$sources, rho_catalog_source)
  names(sources) <- vapply(sources, function(source) source@id, character(1))
  records <- lapply(
    rho_model_catalog_data$records,
    rho_catalog_record_from_data,
    sources = sources
  )
  ModelCatalog(records = records, sources = sources)
}

rho_catalog_model_pricing_expression <- function(pricing) {
  as.call(list(
    quote(rho_model_pricing),
    input = pricing@input,
    output = pricing@output,
    cache_read = pricing@cache_read,
    cache_write = pricing@cache_write,
    tiers = pricing@tiers
  ))
}

rho_catalog_model_call <- function(
  class,
  record,
  api,
  compatibility = quote(list()),
  extra = quote(list())
) {
  as.call(list(
    quote(rho_new_model),
    class = as.name(class),
    provider = record@provider@id,
    id = record@id,
    name = record@name,
    api = api,
    base_url = record@provider@base_url,
    context_window = record@context_window,
    max_tokens = record@max_tokens,
    input = record@input,
    reasoning = record@reasoning,
    thinking_level_map = record@thinking_level_map,
    tools = record@tools,
    parallel_tool_calls = record@parallel_tool_calls,
    transports = as.call(list(
      quote(rho_compile_model_transports),
      record@transports
    )),
    pricing = rho_catalog_model_pricing_expression(record@pricing),
    headers = record@headers,
    compatibility = compatibility,
    extra = extra
  ))
}

rho_unavailable_web_search_expression <- function() {
  quote(RhoWebSearchUnavailable(
    reason = "Hosted web search is not declared for this model and endpoint"
  ))
}

rho_openai_web_search_expression <- function(capabilities) {
  capability <- capabilities$web_search
  if (is.null(capability)) {
    return(rho_unavailable_web_search_expression())
  }
  expression <- list(
    text = quote(OpenAIWebSearchText()),
    text_and_image = quote(OpenAIWebSearchTextAndImage())
  )[[capability]]
  if (is.null(expression)) {
    rho_signal_contract_violation(
      "Unknown OpenAI web-search capability: %s",
      capability
    )
  }
  expression
}

rho_openai_catalog_compatibility_expression <- function(capabilities) {
  as.call(list(
    quote(rho_openai_responses_compatibility),
    supports_tool_search = isTRUE(capabilities$supports_tool_search),
    supports_native_compaction = isTRUE(capabilities$supports_native_compaction),
    web_search = rho_openai_web_search_expression(capabilities)
  ))
}

S7::method(
  rho_model_expression,
  list(ModelCatalogProvider, OpenAIResponsesProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "OpenAIResponsesModel",
    record,
    api = "openai-responses",
    compatibility = rho_openai_catalog_compatibility_expression(
      record@provider_capabilities
    )
  )
}

S7::method(
  rho_model_expression,
  list(OpenAICodexModelCatalogProvider, OpenAIResponsesProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "OpenAICodexResponsesModel",
    record,
    api = "openai-codex-responses",
    compatibility = rho_openai_catalog_compatibility_expression(
      record@provider_capabilities
    )
  )
}

S7::method(
  rho_model_expression,
  list(GitHubCopilotModelCatalogProvider, OpenAIResponsesProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "GitHubCopilotResponsesModel",
    record,
    api = "openai-responses",
    compatibility = rho_openai_catalog_compatibility_expression(
      record@provider_capabilities
    )
  )
}

S7::method(
  rho_model_expression,
  list(ModelCatalogProvider, OpenAIChatCompletionsProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "OpenAIChatCompletionsModel",
    record,
    api = "openai-chat-completions"
  )
}

rho_anthropic_catalog_compatibility_expression <- function(capabilities) {
  thinking <- list(
    none = quote(AnthropicNoThinkingCapability()),
    budget = quote(AnthropicBudgetThinkingCapability()),
    adaptive = quote(AnthropicAdaptiveThinkingCapability())
  )[[capabilities$thinking]]
  if (is.null(thinking)) {
    rho_signal_contract_violation(
      "Unknown Anthropic thinking capability: %s",
      capabilities$thinking
    )
  }
  temperature <- if (isTRUE(capabilities$temperature)) {
    quote(AnthropicTemperatureAccepted())
  } else {
    quote(AnthropicTemperatureOmitted())
  }
  tool_input <- list(
    eager = quote(AnthropicEagerToolInput()),
    fine_grained = quote(AnthropicFineGrainedToolInput())
  )[[capabilities$tool_input %||% "eager"]]
  if (is.null(tool_input)) {
    rho_signal_contract_violation(
      "Unknown Anthropic tool-input capability: %s",
      capabilities$tool_input
    )
  }
  web_search_capability <- capabilities$web_search
  web_search <- if (is.null(web_search_capability)) {
    rho_unavailable_web_search_expression()
  } else {
    expression <- list(
      basic = quote(AnthropicWebSearch20250305()),
      dynamic = quote(AnthropicWebSearch20260209()),
      response_inclusion = quote(AnthropicWebSearch20260318())
    )[[web_search_capability]]
    if (is.null(expression)) {
      rho_signal_contract_violation(
        "Unknown Anthropic web-search capability: %s",
        web_search_capability
      )
    }
    expression
  }
  as.call(list(
    quote(rho_anthropic_messages_compatibility),
    thinking = thinking,
    temperature = temperature,
    cache = as.call(list(
      quote(AnthropicCacheCapability),
      long_retention = isTRUE(capabilities$long_cache_retention %||% TRUE),
      tools = isTRUE(capabilities$cache_tools %||% TRUE)
    )),
    tool_input = tool_input,
    allow_empty_signature = isTRUE(capabilities$allow_empty_signature),
    supports_tool_references = isTRUE(capabilities$supports_tool_references),
    web_search = web_search
  ))
}

S7::method(
  rho_model_expression,
  list(ModelCatalogProvider, AnthropicMessagesProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  rho_catalog_model_call(
    "AnthropicMessagesModel",
    record,
    api = "anthropic-messages",
    compatibility = rho_anthropic_catalog_compatibility_expression(
      record@provider_capabilities
    )
  )
}

S7::method(rho_compile_catalog_model, ModelCatalogRecord) <- function(record, ...) {
  expression <- rho_model_expression(record@provider, record@protocol, record)
  eval(expression, envir = environment(rho_compile_catalog_model))
}

rho_catalog_protocol_matches <- function(record, protocol) {
  is.null(protocol) || S7::S7_inherits(record@protocol, S7::S7_class(protocol))
}

rho_catalog_records_for <- function(catalog, provider, model = NULL) {
  Filter(
    function(record) {
      identical(record@provider@id, provider) &&
        (is.null(model) || identical(record@id, model))
    },
    catalog@records
  )
}

rho_catalog_record_with_provider <- function(record, provider) {
  ModelCatalogRecord(
    provider = provider,
    protocol = record@protocol,
    id = record@id,
    name = record@name,
    input = record@input,
    reasoning = record@reasoning,
    thinking_level_map = record@thinking_level_map,
    tools = record@tools,
    parallel_tool_calls = record@parallel_tool_calls,
    transports = record@transports,
    context_window = record@context_window,
    max_tokens = record@max_tokens,
    pricing = record@pricing,
    headers = record@headers,
    provider_capabilities = record@provider_capabilities,
    source = record@source
  )
}

rho_catalog_active_binding <- function(factory, label) {
  force(factory)
  force(label)
  forced <- FALSE
  cached <- NULL
  function(value) {
    if (!missing(value)) {
      rho_signal_contract_violation(
        "Model catalog binding `%s` is read-only",
        label
      )
    }
    if (!forced) {
      cached <<- factory()
      forced <<- TRUE
    }
    cached
  }
}

rho_catalog_model_factory <- function(record) {
  force(record)
  function() rho_compile_catalog_model(record)
}

rho_catalog_provider_factory <- function(records) {
  force(records)
  function() rho_catalog_provider_bindings(records)
}

rho_catalog_provider_bindings <- function(records) {
  environment <- new.env(parent = emptyenv())
  for (record in records) {
    factory <- rho_catalog_model_factory(record)
    makeActiveBinding(
      record@id,
      rho_catalog_active_binding(factory, record@id),
      environment
    )
  }
  lockEnvironment(environment, bindings = FALSE)
  environment
}

S7::method(rho_catalog_bindings, ModelCatalog) <- function(catalog, ...) {
  environment <- new.env(parent = emptyenv())
  providers <- sort(unique(vapply(
    catalog@records,
    function(record) record@provider@id,
    character(1)
  )))
  for (provider in providers) {
    records <- rho_catalog_records_for(catalog, provider)
    factory <- rho_catalog_provider_factory(records)
    makeActiveBinding(
      provider,
      rho_catalog_active_binding(factory, provider),
      environment
    )
  }
  lockEnvironment(environment, bindings = FALSE)
  environment
}

rho_default_model_bindings <- function() {
  rho_catalog_bindings(rho_default_model_catalog())
}

S7::method(rho_catalog_models, ModelCatalog) <- function(
  catalog,
  provider = NULL,
  protocol = NULL,
  ...
) {
  records <- Filter(
    function(record) {
      (is.null(provider) || identical(record@provider@id, provider)) &&
        rho_catalog_protocol_matches(record, protocol)
    },
    catalog@records
  )
  lapply(records, rho_compile_catalog_model)
}

S7::method(rho_catalog_model, ModelCatalog) <- function(catalog, provider, model, ...) {
  records <- rho_catalog_records_for(catalog, provider, model)
  if (!length(records)) {
    return(ModelCatalogModelNotFound(
      kind = "model_catalog",
      message = sprintf("Model %s is not present for provider %s", model, provider),
      code = "model_not_found",
      retryable = FALSE,
      details = list(),
      provider = provider,
      model = model
    ))
  }
  rho_compile_catalog_model(records[[1L]])
}
