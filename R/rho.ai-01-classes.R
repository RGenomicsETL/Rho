Content <- S7::new_class("Content", abstract = TRUE)

TextContent <- S7::new_class(
  "TextContent",
  parent = Content,
  properties = list(
    text = S7::class_character,
    signature = S7::new_property(S7::class_character, default = ""),
    annotations = S7::new_property(S7::class_list, default = list())
  )
)
ThinkingContent <- S7::new_class(
  "ThinkingContent",
  parent = Content,
  properties = list(
    text = S7::class_character,
    signature = S7::class_character,
    redacted = S7::class_logical
  )
)
ImageContent <- S7::new_class(
  "ImageContent",
  parent = Content,
  properties = list(data = rho_non_empty_string, mime_type = rho_non_empty_string),
  validator = function(self) {
    if (!grepl("^image/[A-Za-z0-9.+-]+$", self@mime_type)) {
      "@mime_type must be an image media type"
    }
  }
)
ArtifactRefContent <- S7::new_class(
  "ArtifactRefContent",
  parent = Content,
  properties = list(artifact_id = S7::class_character, media_type = S7::class_character)
)

ToolCall <- S7::new_class(
  "ToolCall",
  parent = Content,
  properties = list(
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    arguments = S7::class_list,
    arguments_prepared = S7::new_property(S7::class_logical, default = FALSE)
  )
)

OperationStatus <- S7::new_class("OperationStatus", abstract = TRUE)
OperationPending <- S7::new_class("OperationPending", parent = OperationStatus)
OperationInProgress <- S7::new_class("OperationInProgress", parent = OperationStatus)
OperationCompleted <- S7::new_class("OperationCompleted", parent = OperationStatus)
OperationFailed <- S7::new_class("OperationFailed", parent = OperationStatus)

WebSearchAction <- S7::new_class("WebSearchAction", abstract = TRUE)
WebSearchActionUnspecified <- S7::new_class(
  "WebSearchActionUnspecified",
  parent = WebSearchAction
)
WebSearchSearchAction <- S7::new_class(
  "WebSearchSearchAction",
  parent = WebSearchAction,
  properties = list(
    queries = S7::class_character,
    sources = S7::class_list
  )
)
WebSearchOpenPageAction <- S7::new_class(
  "WebSearchOpenPageAction",
  parent = WebSearchAction,
  properties = list(url = S7::class_character)
)
WebSearchFindInPageAction <- S7::new_class(
  "WebSearchFindInPageAction",
  parent = WebSearchAction,
  properties = list(url = S7::class_character, pattern = S7::class_character)
)
WebSearchUnknownAction <- S7::new_class(
  "WebSearchUnknownAction",
  parent = WebSearchAction,
  properties = list(payload = S7::class_list)
)

WebSearchResult <- S7::new_class(
  "WebSearchResult",
  properties = list(
    url = S7::class_character,
    title = S7::class_character,
    age = S7::class_character,
    encrypted_content = S7::class_character
  )
)

WebSearchCallContent <- S7::new_class(
  "WebSearchCallContent",
  parent = Content,
  properties = list(
    id = rho_non_empty_string,
    status = OperationStatus,
    action = WebSearchAction
  )
)

WebSearchResultContent <- S7::new_class(
  "WebSearchResultContent",
  parent = Content,
  properties = list(
    call_id = rho_non_empty_string,
    results = S7::class_list,
    error = S7::new_property(S7::class_any, default = NULL)
  ),
  validator = function(self) {
    invalid <- Filter(
      function(result) !S7::S7_inherits(result, WebSearchResult),
      self@results
    )
    if (length(invalid)) "@results must contain only WebSearchResult values"
  }
)

rho_nonnegative_double <- S7::new_property(
  S7::class_double,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value < 0) "must be one non-negative number"
  }
)

rho_optional_nonnegative_double <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (
      !is.null(value) &&
        (!is.double(value) || length(value) != 1L || is.na(value) || value < 0)
    ) {
      "must be NULL or one non-negative double"
    }
  }
)

UsageObservation <- S7::new_class("UsageObservation", abstract = TRUE)

UsageCost <- S7::new_class(
  "UsageCost",
  abstract = TRUE,
  properties = list(
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double,
    total = rho_nonnegative_double
  ),
  validator = function(self) {
    components <- self@input + self@output + self@cache_read + self@cache_write
    if (!isTRUE(all.equal(self@total, components))) {
      "@total must equal the sum of the component costs"
    }
  }
)

NominalUsageCost <- S7::new_class("NominalUsageCost", parent = UsageCost)

rho_optional_usage_cost <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, UsageCost)) {
      "must be NULL or a UsageCost value"
    }
  }
)

Usage <- S7::new_class(
  "Usage",
  parent = UsageObservation,
  abstract = TRUE,
  properties = list(
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double,
    cache_write_1h = rho_optional_nonnegative_double,
    reasoning = rho_optional_nonnegative_double,
    total = rho_nonnegative_double,
    cost = rho_optional_usage_cost
  ),
  validator = function(self) {
    components <- self@input + self@output + self@cache_read + self@cache_write
    if (!isTRUE(all.equal(self@total, components))) {
      return("@total must equal input + output + cache_read + cache_write")
    }
    if (!is.null(self@reasoning) && self@reasoning > self@output) {
      return("@reasoning is a subset of @output and must not exceed it")
    }
    if (!is.null(self@cache_write_1h) && self@cache_write_1h > self@cache_write) {
      "@cache_write_1h is a subset of @cache_write and must not exceed it"
    }
  }
)

ProviderUsage <- S7::new_class(
  "ProviderUsage",
  parent = Usage,
  properties = list(provider = rho_non_empty_string)
)

EstimatedUsage <- S7::new_class(
  "EstimatedUsage",
  parent = Usage,
  properties = list(
    estimator = rho_non_empty_string,
    method = rho_non_empty_string
  )
)

UsageUnavailable <- S7::new_class(
  "UsageUnavailable",
  parent = UsageObservation,
  properties = list(
    provider = rho_non_empty_string,
    reason = rho_non_empty_string
  )
)

rho_usage_observation_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    valid <- vapply(
      value,
      S7::S7_inherits,
      logical(1),
      class = UsageObservation
    )
    if (!all(valid)) "must contain only UsageObservation values"
  }
)

rho_provider_usage_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    valid <- vapply(value, S7::S7_inherits, logical(1), class = ProviderUsage)
    if (!all(valid)) "must contain only ProviderUsage values"
  }
)

rho_estimated_usage_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    valid <- vapply(value, S7::S7_inherits, logical(1), class = EstimatedUsage)
    if (!all(valid)) "must contain only EstimatedUsage values"
  }
)

rho_unavailable_usage_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    valid <- vapply(value, S7::S7_inherits, logical(1), class = UsageUnavailable)
    if (!all(valid)) "must contain only UsageUnavailable values"
  }
)

rho_counted_usage_list <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    valid <- vapply(value, S7::S7_inherits, logical(1), class = Usage)
    if (!all(valid)) "must contain only Usage values"
  }
)

rho_optional_usage_rate <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (
      !is.null(value) &&
        (!is.double(value) ||
          length(value) != 1L ||
          is.na(value) ||
          value < 0 ||
          value > 1)
    ) {
      "must be NULL or one proportion between zero and one"
    }
  }
)

rho_usage_complete <- S7::new_property(
  S7::class_logical,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing logical value"
    }
  }
)

UsageSummary <- S7::new_class(
  "UsageSummary",
  properties = list(
    observations = rho_usage_observation_list,
    reported = rho_provider_usage_list,
    estimated = rho_estimated_usage_list,
    unavailable = rho_unavailable_usage_list,
    unpriced = rho_counted_usage_list,
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double,
    total = rho_nonnegative_double,
    nominal_cost = NominalUsageCost,
    complete = rho_usage_complete,
    cost_complete = rho_usage_complete,
    latest_cache_hit_rate = rho_optional_usage_rate
  ),
  validator = function(self) {
    tokens <- self@input + self@output + self@cache_read + self@cache_write
    if (!isTRUE(all.equal(self@total, tokens))) {
      return("@total must equal the sum of the token components")
    }
    if (self@complete && length(self@unavailable)) {
      return("@complete cannot be true when usage is unavailable")
    }
    if (self@cost_complete && (!self@complete || length(self@unpriced))) {
      "@cost_complete requires complete and priced observations"
    }
  }
)

RhoContextRevision <- S7::new_class(
  "RhoContextRevision",
  properties = list(digest = rho_non_empty_string)
)

rho_optional_context_revision <- S7::new_property(
  S7::class_any,
  default = NULL,
  validator = function(value) {
    if (!is.null(value) && !S7::S7_inherits(value, RhoContextRevision)) {
      "must be NULL or a RhoContextRevision value"
    }
  }
)

UserMessage <- S7::new_class(
  "UserMessage",
  properties = list(content = S7::class_any, timestamp = S7::class_double)
)
AssistantMessage <- S7::new_class(
  "AssistantMessage",
  properties = list(
    content = S7::class_list,
    provider = S7::class_character,
    model = S7::class_character,
    stop_reason = S7::class_character,
    usage = UsageObservation,
    context_revision = rho_optional_context_revision,
    response_id = S7::new_property(S7::class_character, default = ""),
    timestamp = S7::class_double
  )
)
ToolResultMessage <- S7::new_class(
  "ToolResultMessage",
  properties = list(
    tool_call_id = S7::class_character,
    tool_name = S7::class_character,
    content = S7::class_list,
    details = S7::class_any,
    is_error = S7::class_logical,
    terminate = S7::new_property(S7::class_logical, default = FALSE),
    timestamp = S7::class_double,
    added_tool_names = S7::new_property(S7::class_character, default = character())
  )
)

rho_scalar_logical <- S7::new_property(
  S7::class_logical,
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) "must be one non-missing logical value"
  }
)

rho_positive_integer <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) "must be one positive integer"
  }
)

rho_input_modalities <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    invalid <- setdiff(value, c("text", "image"))
    if (!length(value) || length(invalid)) {
      "must contain one or more of 'text' and 'image'"
    } else if (anyDuplicated(value)) {
      "must not contain duplicates"
    }
  }
)

ProviderTransport <- S7::new_class("ProviderTransport", abstract = TRUE)
SseTransport <- S7::new_class("SseTransport", parent = ProviderTransport)
WebSocketTransport <- S7::new_class(
  "WebSocketTransport",
  parent = ProviderTransport
)
CachedWebSocketTransport <- S7::new_class(
  "CachedWebSocketTransport",
  parent = WebSocketTransport
)
EmbeddedTransport <- S7::new_class(
  "EmbeddedTransport",
  parent = ProviderTransport
)
AutomaticTransport <- S7::new_class("AutomaticTransport")

RhoEmbeddedExecutor <- S7::new_class("RhoEmbeddedExecutor", abstract = TRUE)
RhoFunctionEmbeddedExecutor <- S7::new_class(
  "RhoFunctionEmbeddedExecutor",
  parent = RhoEmbeddedExecutor,
  properties = list(execute = S7::class_function)
)
RhoEmbeddedProvider <- S7::new_class(
  "RhoEmbeddedProvider",
  properties = list(
    provider_id = rho_non_empty_string,
    executor = RhoEmbeddedExecutor
  )
)

OpenAICodexWebSocketRequest <- S7::new_class(
  "OpenAICodexWebSocketRequest",
  properties = list(
    request = RhoWebSocketRequest,
    message = rho_non_empty_string
  )
)

rho_model_transport_ids <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    invalid <- setdiff(value, c("sse", "websocket", "websocket-cached", "embedded"))
    if (!length(value) || length(invalid)) {
      "must contain one or more supported transports"
    } else if (anyDuplicated(value)) {
      "must not contain duplicates"
    }
  }
)

rho_model_transports <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    invalid <- Filter(
      function(transport) !S7::S7_inherits(transport, ProviderTransport),
      value
    )
    if (!length(value) || length(invalid)) {
      return("must contain one or more ProviderTransport values")
    }
    transport_classes <- vapply(
      value,
      function(transport) S7::S7_class(transport)@name,
      character(1)
    )
    if (anyDuplicated(transport_classes)) {
      "must not contain duplicate transport classes"
    }
  }
)

ProviderTransportSelection <- S7::new_class(
  "ProviderTransportSelection",
  properties = list(
    transport = ProviderTransport,
    reason = rho_non_empty_string
  )
)

rho_thinking_level_map <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    supported <- c("off", "minimal", "low", "medium", "high", "xhigh", "max")
    if (is.null(names(value)) && length(value)) {
      return("must be a named list")
    }
    invalid_names <- setdiff(names(value), supported)
    if (length(invalid_names) || anyDuplicated(names(value))) {
      return("must use unique canonical thinking-level names")
    }
    valid_values <- vapply(
      value,
      function(mapped) {
        is.null(mapped) ||
          (is.character(mapped) && length(mapped) == 1L && !is.na(mapped) && nzchar(mapped))
      },
      logical(1)
    )
    if (length(valid_values) && !all(valid_values)) {
      "values must be NULL or one non-empty provider level"
    }
  }
)

ModelCapabilities <- S7::new_class(
  "ModelCapabilities",
  properties = list(
    input = rho_input_modalities,
    reasoning = rho_scalar_logical,
    thinking_level_map = rho_thinking_level_map,
    tools = rho_scalar_logical,
    parallel_tool_calls = rho_scalar_logical,
    transports = rho_model_transports
  )
)

ModelLimits <- S7::new_class(
  "ModelLimits",
  properties = list(
    context_window = rho_positive_integer,
    max_tokens = rho_positive_integer
  )
)

ModelPricingTier <- S7::new_class(
  "ModelPricingTier",
  properties = list(
    input_tokens_above = rho_nonnegative_double,
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double
  )
)

rho_model_pricing_tiers <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    invalid <- Filter(function(tier) !S7::S7_inherits(tier, ModelPricingTier), value)
    if (length(invalid)) "must contain only ModelPricingTier values"
  }
)

ModelPricing <- S7::new_class(
  "ModelPricing",
  properties = list(
    input = rho_nonnegative_double,
    output = rho_nonnegative_double,
    cache_read = rho_nonnegative_double,
    cache_write = rho_nonnegative_double,
    tiers = rho_model_pricing_tiers
  )
)

Model <- S7::new_class(
  "Model",
  properties = list(
    provider = rho_non_empty_string,
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    api = rho_non_empty_string,
    base_url = S7::class_character,
    capabilities = ModelCapabilities,
    limits = ModelLimits,
    pricing = ModelPricing,
    headers = S7::class_list,
    compatibility = S7::class_any
  )
)

OpenAIResponsesModel <- S7::new_class("OpenAIResponsesModel", parent = Model)
OpenAICodexResponsesModel <- S7::new_class(
  "OpenAICodexResponsesModel",
  parent = OpenAIResponsesModel
)
GitHubCopilotResponsesModel <- S7::new_class(
  "GitHubCopilotResponsesModel",
  parent = OpenAIResponsesModel
)
OpenAIChatCompletionsModel <- S7::new_class("OpenAIChatCompletionsModel", parent = Model)
AnthropicMessagesModel <- S7::new_class("AnthropicMessagesModel", parent = Model)

RhoOperation <- S7::new_class("RhoOperation", abstract = TRUE)

RhoWebSearchLocation <- S7::new_class(
  "RhoWebSearchLocation",
  abstract = TRUE
)
RhoWebSearchLocationUnspecified <- S7::new_class(
  "RhoWebSearchLocationUnspecified",
  parent = RhoWebSearchLocation
)
RhoApproximateLocation <- S7::new_class(
  "RhoApproximateLocation",
  parent = RhoWebSearchLocation,
  properties = list(
    country = rho_optional_string,
    city = rho_optional_string,
    region = rho_optional_string,
    timezone = rho_optional_string
  ),
  validator = function(self) {
    values <- c(self@country, self@city, self@region, self@timezone)
    if (!any(nzchar(values))) {
      return("at least one location field must be non-empty")
    }
    if (nzchar(self@country) && nchar(self@country) != 2L) {
      "@country must be a two-letter ISO country code"
    }
  }
)

RhoWebSearchDomainPolicy <- S7::new_class(
  "RhoWebSearchDomainPolicy",
  abstract = TRUE
)
RhoWebSearchAllDomains <- S7::new_class(
  "RhoWebSearchAllDomains",
  parent = RhoWebSearchDomainPolicy
)
RhoWebSearchAllowedDomains <- S7::new_class(
  "RhoWebSearchAllowedDomains",
  parent = RhoWebSearchDomainPolicy,
  properties = list(domains = rho_unique_non_empty_strings),
  validator = function(self) {
    if (!length(self@domains)) "@domains must contain at least one domain"
  }
)
RhoWebSearchBlockedDomains <- S7::new_class(
  "RhoWebSearchBlockedDomains",
  parent = RhoWebSearchDomainPolicy,
  properties = list(domains = rho_unique_non_empty_strings),
  validator = function(self) {
    if (!length(self@domains)) "@domains must contain at least one domain"
  }
)

RhoWebSearchOperation <- S7::new_class(
  "RhoWebSearchOperation",
  parent = RhoOperation,
  properties = list(
    domains = RhoWebSearchDomainPolicy,
    location = RhoWebSearchLocation
  )
)

RhoWebSearchCapability <- S7::new_class(
  "RhoWebSearchCapability",
  abstract = TRUE
)
RhoWebSearchUnavailable <- S7::new_class(
  "RhoWebSearchUnavailable",
  parent = RhoWebSearchCapability,
  properties = list(reason = rho_non_empty_string)
)
OpenAIWebSearchCapability <- S7::new_class(
  "OpenAIWebSearchCapability",
  parent = RhoWebSearchCapability,
  abstract = TRUE
)
OpenAIWebSearchText <- S7::new_class(
  "OpenAIWebSearchText",
  parent = OpenAIWebSearchCapability
)
OpenAIWebSearchTextAndImage <- S7::new_class(
  "OpenAIWebSearchTextAndImage",
  parent = OpenAIWebSearchCapability
)
AnthropicWebSearchProtocol <- S7::new_class(
  "AnthropicWebSearchProtocol",
  parent = RhoWebSearchCapability,
  abstract = TRUE
)
AnthropicWebSearch20250305 <- S7::new_class(
  "AnthropicWebSearch20250305",
  parent = AnthropicWebSearchProtocol
)
AnthropicWebSearch20260209 <- S7::new_class(
  "AnthropicWebSearch20260209",
  parent = AnthropicWebSearchProtocol
)
AnthropicWebSearch20260318 <- S7::new_class(
  "AnthropicWebSearch20260318",
  parent = AnthropicWebSearchProtocol
)

RhoOperationBinding <- S7::new_class(
  "RhoOperationBinding",
  abstract = TRUE,
  properties = list(
    operation = RhoOperation,
    handler = S7::class_any,
    reason = rho_non_empty_string
  )
)
RhoProviderToolBinding <- S7::new_class(
  "RhoProviderToolBinding",
  parent = RhoOperationBinding,
  abstract = TRUE
)

rho_operation_bindings <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    invalid <- Filter(
      function(binding) !S7::S7_inherits(binding, RhoOperationBinding),
      value
    )
    if (length(invalid)) "must contain only RhoOperationBinding values"
  }
)

RhoOperationPlan <- S7::new_class(
  "RhoOperationPlan",
  properties = list(bindings = rho_operation_bindings)
)

rho_context_operations <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    invalid <- Filter(
      function(operation) {
        !S7::S7_inherits(operation, RhoOperation) &&
          !S7::S7_inherits(operation, RhoOperationBinding)
      },
      value
    )
    if (length(invalid)) {
      "must contain only RhoOperation or RhoOperationBinding values"
    }
  }
)

Context <- S7::new_class(
  "Context",
  properties = list(
    system_prompt = S7::class_character,
    messages = S7::class_list,
    tools = S7::class_list,
    operations = rho_context_operations
  )
)

ToolOverlap <- S7::new_class("ToolOverlap", abstract = TRUE)
ToolMayOverlap <- S7::new_class("ToolMayOverlap", parent = ToolOverlap)
ToolRequiresExclusiveExecution <- S7::new_class(
  "ToolRequiresExclusiveExecution",
  parent = ToolOverlap
)

ToolSpec <- S7::new_class(
  "ToolSpec",
  properties = list(
    name = rho_non_empty_string,
    label = S7::class_character,
    description = S7::class_character,
    parameters = S7::class_list,
    execute = S7::class_function,
    prepare_arguments = S7::class_any,
    overlap = ToolOverlap
  )
)

ToolResult <- S7::new_class(
  "ToolResult",
  properties = list(
    content = S7::class_list,
    details = S7::class_any,
    terminate = S7::class_logical,
    added_tool_names = S7::new_property(S7::class_character, default = character())
  )
)
ToolErrorResult <- S7::new_class("ToolErrorResult", parent = ToolResult)

ProviderErrorValue <- S7::new_class(
  "ProviderErrorValue",
  properties = list(
    kind = rho_non_empty_string,
    message = rho_non_empty_string,
    code = S7::class_character,
    retryable = S7::class_logical,
    details = S7::class_list
  )
)

ProviderInputUnsupported <- S7::new_class(
  "ProviderInputUnsupported",
  parent = ProviderErrorValue
)
ProviderTransportUnsupported <- S7::new_class(
  "ProviderTransportUnsupported",
  parent = ProviderErrorValue
)
ModelInputAccepted <- S7::new_class(
  "ModelInputAccepted",
  properties = list(
    model = Model,
    modalities = S7::class_character
  ),
  validator = function(self) {
    invalid <- setdiff(self@modalities, c("text", "image"))
    if (length(invalid)) "@modalities must contain only text and image"
  }
)

AuthErrorValue <- S7::new_class("AuthErrorValue", parent = ProviderErrorValue)
ProviderInputLimitError <- S7::new_class(
  "ProviderInputLimitError",
  parent = ProviderErrorValue
)
ProviderContextOverflowError <- S7::new_class(
  "ProviderContextOverflowError",
  parent = ProviderInputLimitError
)
ProviderRequestTooLargeError <- S7::new_class(
  "ProviderRequestTooLargeError",
  parent = ProviderInputLimitError
)

OperationUnsupported <- S7::new_class(
  "OperationUnsupported",
  parent = ProviderErrorValue,
  properties = list(
    operation = RhoOperation,
    handler_class = rho_non_empty_string
  )
)

AssistantEvent <- S7::new_class("AssistantEvent", abstract = TRUE)

AssistantPartialEvent <- S7::new_class(
  "AssistantPartialEvent",
  parent = AssistantEvent,
  abstract = TRUE,
  properties = list(partial = AssistantMessage)
)

AssistantStartEvent <- S7::new_class(
  "AssistantStartEvent",
  parent = AssistantPartialEvent
)

AssistantUpdateEvent <- S7::new_class(
  "AssistantUpdateEvent",
  parent = AssistantPartialEvent,
  abstract = TRUE,
  properties = list(content_index = rho_positive_integer)
)

AssistantTextStartEvent <- S7::new_class(
  "AssistantTextStartEvent",
  parent = AssistantUpdateEvent
)
AssistantTextDeltaEvent <- S7::new_class(
  "AssistantTextDeltaEvent",
  parent = AssistantUpdateEvent,
  properties = list(delta = S7::class_character)
)
AssistantTextEndEvent <- S7::new_class(
  "AssistantTextEndEvent",
  parent = AssistantUpdateEvent,
  properties = list(content = TextContent)
)

AssistantThinkingStartEvent <- S7::new_class(
  "AssistantThinkingStartEvent",
  parent = AssistantUpdateEvent
)
AssistantThinkingDeltaEvent <- S7::new_class(
  "AssistantThinkingDeltaEvent",
  parent = AssistantUpdateEvent,
  properties = list(delta = S7::class_character)
)
AssistantThinkingEndEvent <- S7::new_class(
  "AssistantThinkingEndEvent",
  parent = AssistantUpdateEvent,
  properties = list(content = ThinkingContent)
)

AssistantToolCallStartEvent <- S7::new_class(
  "AssistantToolCallStartEvent",
  parent = AssistantUpdateEvent,
  properties = list(id = rho_non_empty_string, name = rho_non_empty_string)
)
AssistantToolCallDeltaEvent <- S7::new_class(
  "AssistantToolCallDeltaEvent",
  parent = AssistantUpdateEvent,
  properties = list(delta = S7::class_character)
)
AssistantToolCallEndEvent <- S7::new_class(
  "AssistantToolCallEndEvent",
  parent = AssistantUpdateEvent,
  properties = list(tool_call = ToolCall)
)

AssistantOperationStartEvent <- S7::new_class(
  "AssistantOperationStartEvent",
  parent = AssistantUpdateEvent,
  properties = list(content = Content)
)
AssistantOperationEndEvent <- S7::new_class(
  "AssistantOperationEndEvent",
  parent = AssistantUpdateEvent,
  properties = list(content = Content)
)

AssistantTerminalEvent <- S7::new_class(
  "AssistantTerminalEvent",
  parent = AssistantEvent,
  abstract = TRUE,
  properties = list(message = AssistantMessage, reason = S7::class_character)
)
AssistantDoneEvent <- S7::new_class(
  "AssistantDoneEvent",
  parent = AssistantTerminalEvent
)
AssistantErrorEvent <- S7::new_class(
  "AssistantErrorEvent",
  parent = AssistantTerminalEvent,
  properties = list(error = ProviderErrorValue)
)

ProviderOperationUnsupported <- S7::new_class(
  "ProviderOperationUnsupported",
  parent = ProviderErrorValue,
  properties = list(operation = rho_non_empty_string)
)

ProviderRequestSection <- S7::new_class(
  "ProviderRequestSection",
  abstract = TRUE
)
ProviderRequestPlan <- S7::new_class(
  "ProviderRequestPlan",
  abstract = TRUE
)

RhoProviderOperation <- S7::new_class(
  "RhoProviderOperation",
  parent = RhoOperation,
  abstract = TRUE
)
RhoToolSearchOperation <- S7::new_class("RhoToolSearchOperation", parent = RhoProviderOperation)
RhoToolReferencesOperation <- S7::new_class(
  "RhoToolReferencesOperation",
  parent = RhoProviderOperation
)
RhoCompactionOperation <- S7::new_class(
  "RhoCompactionOperation",
  parent = RhoProviderOperation
)
RhoNativeCompactionOperation <- S7::new_class(
  "RhoNativeCompactionOperation",
  parent = RhoCompactionOperation
)
RhoCacheRetentionOperation <- S7::new_class(
  "RhoCacheRetentionOperation",
  parent = RhoProviderOperation
)

RhoProviderCompactionBinding <- S7::new_class(
  "RhoProviderCompactionBinding",
  parent = RhoOperationBinding,
  properties = list(model = Model)
)

RhoProviderSupport <- S7::new_class(
  "RhoProviderSupport",
  properties = list(
    supported = rho_scalar_logical,
    source = rho_non_empty_string,
    details = S7::class_list
  )
)

OpenAIResponsesCompatibility <- S7::new_class(
  "OpenAIResponsesCompatibility",
  properties = list(
    supports_tool_search = rho_scalar_logical,
    supports_native_compaction = rho_scalar_logical,
    web_search = RhoWebSearchCapability
  )
)

AnthropicThinkingCapability <- S7::new_class(
  "AnthropicThinkingCapability",
  abstract = TRUE
)
AnthropicNoThinkingCapability <- S7::new_class(
  "AnthropicNoThinkingCapability",
  parent = AnthropicThinkingCapability
)
AnthropicBudgetThinkingCapability <- S7::new_class(
  "AnthropicBudgetThinkingCapability",
  parent = AnthropicThinkingCapability
)
AnthropicAdaptiveThinkingCapability <- S7::new_class(
  "AnthropicAdaptiveThinkingCapability",
  parent = AnthropicThinkingCapability
)

AnthropicTemperatureCapability <- S7::new_class(
  "AnthropicTemperatureCapability",
  abstract = TRUE
)
AnthropicTemperatureAccepted <- S7::new_class(
  "AnthropicTemperatureAccepted",
  parent = AnthropicTemperatureCapability
)
AnthropicTemperatureOmitted <- S7::new_class(
  "AnthropicTemperatureOmitted",
  parent = AnthropicTemperatureCapability
)

AnthropicCacheCapability <- S7::new_class(
  "AnthropicCacheCapability",
  properties = list(
    long_retention = rho_scalar_logical,
    tools = rho_scalar_logical
  )
)

AnthropicToolInputCapability <- S7::new_class(
  "AnthropicToolInputCapability",
  abstract = TRUE
)
AnthropicEagerToolInput <- S7::new_class(
  "AnthropicEagerToolInput",
  parent = AnthropicToolInputCapability
)
AnthropicFineGrainedToolInput <- S7::new_class(
  "AnthropicFineGrainedToolInput",
  parent = AnthropicToolInputCapability
)

AnthropicMessagesCompatibility <- S7::new_class(
  "AnthropicMessagesCompatibility",
  properties = list(
    thinking = AnthropicThinkingCapability,
    temperature = AnthropicTemperatureCapability,
    cache = AnthropicCacheCapability,
    tool_input = AnthropicToolInputCapability,
    allow_empty_signature = rho_scalar_logical,
    supports_tool_references = rho_scalar_logical,
    web_search = RhoWebSearchCapability
  )
)

rho_cache_expectation <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    allowed <- c("unchanged", "preserve-prefix", "replace-prefix", "unknown")
    if (length(value) != 1L || is.na(value) || !value %in% allowed) {
      sprintf("must be one of %s", paste(allowed, collapse = ", "))
    }
  }
)

RhoToolPlacement <- S7::new_class(
  "RhoToolPlacement",
  abstract = TRUE,
  properties = list(
    immediate = S7::class_list,
    deferred = S7::class_list,
    cache_expectation = rho_cache_expectation,
    reason = rho_non_empty_string
  ),
  validator = function(self) {
    tools <- c(self@immediate, self@deferred)
    invalid <- Filter(function(tool) !S7::S7_inherits(tool, ToolSpec), tools)
    if (length(invalid)) "@immediate and @deferred must contain only ToolSpec values"
  }
)

RhoFullToolPlacement <- S7::new_class("RhoFullToolPlacement", parent = RhoToolPlacement)
RhoOpenAIToolSearchPlacement <- S7::new_class(
  "RhoOpenAIToolSearchPlacement",
  parent = RhoToolPlacement
)
RhoAnthropicToolReferencePlacement <- S7::new_class(
  "RhoAnthropicToolReferencePlacement",
  parent = RhoToolPlacement
)
