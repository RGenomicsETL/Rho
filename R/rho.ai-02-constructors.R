rho_text <- function(text, signature = "", annotations = list()) {
  TextContent(
    text = as.character(text),
    signature = signature,
    annotations = annotations
  )
}
rho_thinking <- function(text, signature = "", redacted = FALSE) {
  ThinkingContent(text = as.character(text), signature = signature, redacted = isTRUE(redacted))
}

rho_nominal_usage_cost <- function(
  input = 0,
  output = 0,
  cache_read = 0,
  cache_write = 0
) {
  input <- as.double(input)
  output <- as.double(output)
  cache_read <- as.double(cache_read)
  cache_write <- as.double(cache_write)
  NominalUsageCost(
    input = input,
    output = output,
    cache_read = cache_read,
    cache_write = cache_write,
    total = input + output + cache_read + cache_write
  )
}

rho_provider_usage <- function(
  provider,
  input = 0,
  output = 0,
  cache_read = 0,
  cache_write = 0,
  cache_write_1h = NULL,
  reasoning = NULL,
  cost = NULL
) {
  input <- as.double(input)
  output <- as.double(output)
  cache_read <- as.double(cache_read)
  cache_write <- as.double(cache_write)
  ProviderUsage(
    provider = provider,
    input = input,
    output = output,
    cache_read = cache_read,
    cache_write = cache_write,
    cache_write_1h = if (is.null(cache_write_1h)) NULL else as.double(cache_write_1h),
    reasoning = if (is.null(reasoning)) NULL else as.double(reasoning),
    total = input + output + cache_read + cache_write,
    cost = cost
  )
}

rho_estimated_usage <- function(
  estimator,
  method,
  input = 0,
  output = 0,
  cache_read = 0,
  cache_write = 0,
  cache_write_1h = NULL,
  reasoning = NULL,
  cost = NULL
) {
  input <- as.double(input)
  output <- as.double(output)
  cache_read <- as.double(cache_read)
  cache_write <- as.double(cache_write)
  EstimatedUsage(
    estimator = estimator,
    method = method,
    input = input,
    output = output,
    cache_read = cache_read,
    cache_write = cache_write,
    cache_write_1h = if (is.null(cache_write_1h)) NULL else as.double(cache_write_1h),
    reasoning = if (is.null(reasoning)) NULL else as.double(reasoning),
    total = input + output + cache_read + cache_write,
    cost = cost
  )
}

rho_usage_unavailable <- function(provider, reason) {
  UsageUnavailable(provider = provider, reason = reason)
}

rho_user_message <- function(content, timestamp = as.numeric(Sys.time())) {
  UserMessage(content = content, timestamp = timestamp)
}
rho_tool_result_message <- function(
  tool_call_id,
  tool_name,
  content = list(),
  details = list(),
  is_error = FALSE,
  terminate = FALSE,
  added_tool_names = character(),
  timestamp = as.numeric(Sys.time())
) {
  ToolResultMessage(
    tool_call_id = tool_call_id,
    tool_name = tool_name,
    content = content,
    details = details,
    is_error = isTRUE(is_error),
    terminate = isTRUE(terminate),
    timestamp = timestamp,
    added_tool_names = unique(added_tool_names)
  )
}
rho_assistant_message <- function(
  content = list(),
  provider = "faux",
  model = "faux",
  stop_reason = "stop",
  usage = NULL,
  context_revision = NULL,
  response_id = "",
  timestamp = as.numeric(Sys.time())
) {
  AssistantMessage(
    content = content,
    provider = provider,
    model = model,
    stop_reason = stop_reason,
    usage = usage %||%
      rho_usage_unavailable(
        provider,
        "No usage observation was supplied"
      ),
    context_revision = context_revision,
    response_id = response_id,
    timestamp = timestamp
  )
}
rho_provider_error <- function(
  message,
  kind = "provider",
  code = "",
  retryable = FALSE,
  details = list()
) {
  ProviderErrorValue(
    kind = kind,
    message = message,
    code = code,
    retryable = isTRUE(retryable),
    details = details
  )
}
rho_provider_input_unsupported <- function(model, requested) {
  requested <- unique(as.character(requested))
  unsupported <- setdiff(requested, model@capabilities@input)
  ProviderInputUnsupported(
    kind = "unsupported_input",
    message = sprintf(
      "%s does not accept %s input",
      model@id,
      paste(unsupported, collapse = " and ")
    ),
    code = "unsupported_input_modality",
    retryable = FALSE,
    details = list(
      model = model@id,
      provider = model@provider,
      requested = requested,
      supported = model@capabilities@input,
      unsupported = unsupported
    )
  )
}
rho_provider_context_overflow <- function(
  message,
  code = "context_overflow",
  details = list()
) {
  ProviderContextOverflowError(
    kind = "context_overflow",
    message = message,
    code = code,
    retryable = FALSE,
    details = details
  )
}
rho_provider_request_too_large <- function(
  message,
  code = "request_too_large",
  details = list()
) {
  ProviderRequestTooLargeError(
    kind = "request_too_large",
    message = message,
    code = code,
    retryable = FALSE,
    details = details
  )
}
rho_provider_error_stream <- function(model, error) {
  partial <- rho_assistant_message(
    provider = model@provider,
    model = model@id,
    stop_reason = "error"
  )
  rho_list_stream(list(rho_assistant_error_event(error, partial)))
}
rho_auth_error <- function(message, code = "auth", retryable = FALSE, details = list()) {
  AuthErrorValue(
    kind = "auth",
    message = message,
    code = code,
    retryable = isTRUE(retryable),
    details = details
  )
}
rho_operation_unsupported <- function(operation, handler, message, details = list()) {
  OperationUnsupported(
    kind = "operation_unsupported",
    message = message,
    code = "unsupported",
    retryable = FALSE,
    details = details,
    operation = operation,
    handler_class = rho_class_label(handler)
  )
}
rho_unsupported_provider_operation <- function(operation, message, details = list()) {
  ProviderOperationUnsupported(
    kind = "unsupported_provider_operation",
    message = message,
    code = "unsupported",
    retryable = FALSE,
    details = details,
    operation = operation
  )
}
rho_provider_support_value <- function(supported, source, details = list()) {
  RhoProviderSupport(supported = isTRUE(supported), source = source, details = details)
}
rho_openai_responses_compatibility <- function(
  supports_tool_search = FALSE,
  supports_native_compaction = FALSE,
  web_search = RhoWebSearchUnavailable(
    reason = "Hosted web search is not declared for this model and endpoint"
  )
) {
  OpenAIResponsesCompatibility(
    supports_tool_search = isTRUE(supports_tool_search),
    supports_native_compaction = isTRUE(supports_native_compaction),
    web_search = web_search
  )
}
rho_anthropic_messages_compatibility <- function(
  thinking = AnthropicBudgetThinkingCapability(),
  temperature = AnthropicTemperatureAccepted(),
  cache = AnthropicCacheCapability(long_retention = TRUE, tools = TRUE),
  tool_input = AnthropicEagerToolInput(),
  allow_empty_signature = FALSE,
  supports_tool_references = FALSE,
  web_search = RhoWebSearchUnavailable(
    reason = "Hosted web search is not declared for this model and endpoint"
  )
) {
  AnthropicMessagesCompatibility(
    thinking = thinking,
    temperature = temperature,
    cache = cache,
    tool_input = tool_input,
    allow_empty_signature = isTRUE(allow_empty_signature),
    supports_tool_references = isTRUE(supports_tool_references),
    web_search = web_search
  )
}
rho_tool_result <- function(
  content = list(),
  details = list(),
  terminate = FALSE,
  added_tool_names = character()
) {
  ToolResult(
    content = content,
    details = details,
    terminate = isTRUE(terminate),
    added_tool_names = unique(added_tool_names)
  )
}

rho_tool_error_result <- function(
  content = list(),
  details = list(),
  terminate = FALSE,
  added_tool_names = character()
) {
  ToolErrorResult(
    content = content,
    details = details,
    terminate = isTRUE(terminate),
    added_tool_names = unique(added_tool_names)
  )
}

rho_assistant_start_event <- function(partial) {
  AssistantStartEvent(partial = partial)
}

rho_assistant_text_start_event <- function(partial, content_index) {
  AssistantTextStartEvent(partial = partial, content_index = as.integer(content_index))
}

rho_assistant_text_delta_event <- function(partial, content_index, delta) {
  AssistantTextDeltaEvent(
    partial = partial,
    content_index = as.integer(content_index),
    delta = as.character(delta)
  )
}

rho_assistant_text_end_event <- function(partial, content_index, content) {
  AssistantTextEndEvent(
    partial = partial,
    content_index = as.integer(content_index),
    content = content
  )
}

rho_assistant_thinking_start_event <- function(partial, content_index) {
  AssistantThinkingStartEvent(partial = partial, content_index = as.integer(content_index))
}

rho_assistant_thinking_delta_event <- function(partial, content_index, delta) {
  AssistantThinkingDeltaEvent(
    partial = partial,
    content_index = as.integer(content_index),
    delta = as.character(delta)
  )
}

rho_assistant_thinking_end_event <- function(partial, content_index, content) {
  AssistantThinkingEndEvent(
    partial = partial,
    content_index = as.integer(content_index),
    content = content
  )
}

rho_assistant_tool_call_start_event <- function(partial, content_index, id, name) {
  AssistantToolCallStartEvent(
    partial = partial,
    content_index = as.integer(content_index),
    id = id,
    name = name
  )
}

rho_assistant_tool_call_delta_event <- function(partial, content_index, delta) {
  AssistantToolCallDeltaEvent(
    partial = partial,
    content_index = as.integer(content_index),
    delta = as.character(delta)
  )
}

rho_assistant_tool_call_end_event <- function(partial, content_index, tool_call) {
  AssistantToolCallEndEvent(
    partial = partial,
    content_index = as.integer(content_index),
    tool_call = tool_call
  )
}

rho_assistant_operation_start_event <- function(partial, content_index, content) {
  AssistantOperationStartEvent(
    partial = partial,
    content_index = as.integer(content_index),
    content = content
  )
}

rho_assistant_operation_end_event <- function(partial, content_index, content) {
  AssistantOperationEndEvent(
    partial = partial,
    content_index = as.integer(content_index),
    content = content
  )
}

rho_assistant_done_event <- function(message, reason = message@stop_reason) {
  AssistantDoneEvent(message = message, reason = reason)
}

rho_assistant_error_event <- function(error, message) {
  AssistantErrorEvent(message = message, reason = "error", error = error)
}

rho_context <- function(
  system_prompt = "",
  messages = list(),
  tools = list(),
  operations = list()
) {
  Context(
    system_prompt = system_prompt,
    messages = messages,
    tools = tools,
    operations = operations
  )
}

rho_approximate_location <- function(
  country = "",
  city = "",
  region = "",
  timezone = ""
) {
  RhoApproximateLocation(
    country = country,
    city = city,
    region = region,
    timezone = timezone
  )
}

rho_web_search <- function(
  domains = RhoWebSearchAllDomains(),
  location = RhoWebSearchLocationUnspecified()
) {
  RhoWebSearchOperation(domains = domains, location = location)
}

rho_web_search_allowed_domains <- function(domains) {
  RhoWebSearchAllowedDomains(domains = unique(domains))
}

rho_web_search_blocked_domains <- function(domains) {
  RhoWebSearchBlockedDomains(domains = unique(domains))
}

rho_operation_plan <- function(bindings = list()) {
  RhoOperationPlan(bindings = bindings)
}
rho_model_capabilities <- function(
  input = "text",
  reasoning = FALSE,
  thinking_level_map = list(),
  tools = TRUE,
  parallel_tool_calls = TRUE,
  transports = list(EmbeddedTransport())
) {
  ModelCapabilities(
    input = input,
    reasoning = isTRUE(reasoning),
    thinking_level_map = thinking_level_map,
    tools = isTRUE(tools),
    parallel_tool_calls = isTRUE(parallel_tool_calls),
    transports = transports
  )
}

rho_model_limits <- function(context_window = 128000L, max_tokens = 4096L) {
  ModelLimits(
    context_window = as.integer(context_window),
    max_tokens = as.integer(max_tokens)
  )
}

rho_model_pricing_tier <- function(
  input_tokens_above,
  input,
  output,
  cache_read = 0,
  cache_write = 0
) {
  ModelPricingTier(
    input_tokens_above = as.double(input_tokens_above),
    input = as.double(input),
    output = as.double(output),
    cache_read = as.double(cache_read),
    cache_write = as.double(cache_write)
  )
}

rho_model_pricing <- function(
  input = 0,
  output = 0,
  cache_read = 0,
  cache_write = 0,
  tiers = list()
) {
  ModelPricing(
    input = as.double(input),
    output = as.double(output),
    cache_read = as.double(cache_read),
    cache_write = as.double(cache_write),
    tiers = tiers
  )
}

rho_new_model <- function(
  class,
  provider,
  id,
  name = id,
  api = "custom",
  base_url = "",
  context_window = 128000L,
  max_tokens = 4096L,
  input = "text",
  reasoning = FALSE,
  thinking_level_map = list(),
  tools = TRUE,
  parallel_tool_calls = TRUE,
  transports = list(EmbeddedTransport()),
  pricing = rho_model_pricing(),
  headers = list(),
  compatibility = list(),
  extra = list()
) {
  fields <- list(
    provider = provider,
    id = id,
    name = name,
    api = api,
    base_url = base_url,
    capabilities = rho_model_capabilities(
      input = input,
      reasoning = reasoning,
      thinking_level_map = thinking_level_map,
      tools = tools,
      parallel_tool_calls = parallel_tool_calls,
      transports = transports
    ),
    limits = rho_model_limits(context_window, max_tokens),
    pricing = pricing,
    headers = headers,
    compatibility = compatibility
  )
  if (length(extra) && (is.null(names(extra)) || any(!nzchar(names(extra))))) {
    rho_signal_contract_violation("`extra` must be a named list")
  }
  duplicated <- intersect(names(fields), names(extra))
  if (length(duplicated)) {
    rho_signal_contract_violation(
      "`extra` duplicates model field(s): %s",
      paste(duplicated, collapse = ", ")
    )
  }
  do.call(class, c(fields, extra))
}

rho_model <- function(
  provider,
  id,
  name = id,
  api = "custom",
  base_url = "",
  context_window = 128000L,
  max_tokens = 4096L,
  input = "text",
  reasoning = FALSE,
  thinking_level_map = list(),
  tools = TRUE,
  parallel_tool_calls = TRUE,
  transports = list(EmbeddedTransport()),
  pricing = rho_model_pricing(),
  headers = list(),
  compatibility = list()
) {
  rho_new_model(
    Model,
    provider = provider,
    id = id,
    name = name,
    api = api,
    base_url = base_url,
    context_window = context_window,
    max_tokens = max_tokens,
    input = input,
    reasoning = reasoning,
    thinking_level_map = thinking_level_map,
    tools = tools,
    parallel_tool_calls = parallel_tool_calls,
    transports = transports,
    pricing = pricing,
    headers = headers,
    compatibility = compatibility
  )
}
rho_tool_spec <- function(
  name,
  label = name,
  description,
  parameters = list(),
  execute,
  prepare_arguments = NULL,
  overlap = ToolMayOverlap()
) {
  ToolSpec(
    name = name,
    label = label,
    description = description,
    parameters = parameters,
    execute = execute,
    prepare_arguments = prepare_arguments,
    overlap = overlap
  )
}
