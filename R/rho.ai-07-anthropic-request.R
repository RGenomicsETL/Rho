AnthropicMessageRole <- S7::new_class("AnthropicMessageRole", abstract = TRUE)
AnthropicUserRole <- S7::new_class("AnthropicUserRole", parent = AnthropicMessageRole)
AnthropicAssistantRole <- S7::new_class(
  "AnthropicAssistantRole",
  parent = AnthropicMessageRole
)

AnthropicWireBlock <- S7::new_class("AnthropicWireBlock", abstract = TRUE)
rho_anthropic_image_mime <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    allowed <- c("image/jpeg", "image/png", "image/gif", "image/webp")
    if (length(value) != 1L || is.na(value) || !value %in% allowed) {
      "must be a JPEG, PNG, GIF, or WebP media type"
    }
  }
)
AnthropicTextBlock <- S7::new_class(
  "AnthropicTextBlock",
  parent = AnthropicWireBlock,
  properties = list(
    text = S7::class_character,
    cache_control = S7::class_list,
    reason = S7::new_property(S7::class_character, default = "")
  )
)
AnthropicImageBlock <- S7::new_class(
  "AnthropicImageBlock",
  parent = AnthropicWireBlock,
  properties = list(
    data = S7::class_character,
    mime_type = rho_anthropic_image_mime,
    cache_control = S7::class_list
  )
)
AnthropicThinkingBlock <- S7::new_class(
  "AnthropicThinkingBlock",
  parent = AnthropicWireBlock,
  properties = list(thinking = S7::class_character, signature = S7::class_character)
)
AnthropicRedactedThinkingBlock <- S7::new_class(
  "AnthropicRedactedThinkingBlock",
  parent = AnthropicWireBlock,
  properties = list(data = rho_non_empty_string)
)
AnthropicToolUseBlock <- S7::new_class(
  "AnthropicToolUseBlock",
  parent = AnthropicWireBlock,
  properties = list(
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    input = S7::class_list
  )
)
AnthropicToolResultBlock <- S7::new_class(
  "AnthropicToolResultBlock",
  parent = AnthropicWireBlock,
  properties = list(
    tool_use_id = rho_non_empty_string,
    content = S7::class_list,
    is_error = rho_scalar_logical,
    cache_control = S7::class_list
  )
)
AnthropicServerToolUseBlock <- S7::new_class(
  "AnthropicServerToolUseBlock",
  parent = AnthropicWireBlock,
  properties = list(
    id = rho_non_empty_string,
    name = rho_non_empty_string,
    input = S7::class_list
  )
)
AnthropicWebSearchToolResultBlock <- S7::new_class(
  "AnthropicWebSearchToolResultBlock",
  parent = AnthropicWireBlock,
  properties = list(
    tool_use_id = rho_non_empty_string,
    content = S7::class_any
  )
)

AnthropicWebSearchBinding <- S7::new_class(
  "AnthropicWebSearchBinding",
  parent = RhoProviderToolBinding,
  properties = list(protocol = AnthropicWebSearchProtocol)
)

rho_anthropic_wire_blocks <- S7::new_property(
  S7::class_list,
  validator = function(value) {
    invalid <- Filter(
      function(block) !S7::S7_inherits(block, AnthropicWireBlock),
      value
    )
    if (length(invalid)) "must contain only AnthropicWireBlock values"
  }
)

AnthropicWireMessage <- S7::new_class(
  "AnthropicWireMessage",
  properties = list(role = AnthropicMessageRole, content = rho_anthropic_wire_blocks)
)

AnthropicCacheRetention <- S7::new_class(
  "AnthropicCacheRetention",
  abstract = TRUE
)
AnthropicNoCache <- S7::new_class("AnthropicNoCache", parent = AnthropicCacheRetention)
AnthropicShortCache <- S7::new_class(
  "AnthropicShortCache",
  parent = AnthropicCacheRetention
)
AnthropicLongCache <- S7::new_class(
  "AnthropicLongCache",
  parent = AnthropicCacheRetention
)
AnthropicCacheControl <- S7::new_class(
  "AnthropicCacheControl",
  properties = list(
    enabled = rho_scalar_logical,
    tools = rho_scalar_logical,
    fields = S7::class_list,
    reason = rho_non_empty_string
  )
)

AnthropicThinkingDisplay <- S7::new_class(
  "AnthropicThinkingDisplay",
  abstract = TRUE
)
AnthropicSummarizedThinking <- S7::new_class(
  "AnthropicSummarizedThinking",
  parent = AnthropicThinkingDisplay
)
AnthropicOmittedThinking <- S7::new_class(
  "AnthropicOmittedThinking",
  parent = AnthropicThinkingDisplay
)

AnthropicTemperatureRequest <- S7::new_class(
  "AnthropicTemperatureRequest",
  abstract = TRUE
)
AnthropicTemperatureUnspecified <- S7::new_class(
  "AnthropicTemperatureUnspecified",
  parent = AnthropicTemperatureRequest
)
AnthropicTemperatureValue <- S7::new_class(
  "AnthropicTemperatureValue",
  parent = AnthropicTemperatureRequest,
  properties = list(value = rho_nonnegative_double),
  validator = function(self) {
    if (self@value > 1) "@value must not exceed one"
  }
)

AnthropicToolChoice <- S7::new_class("AnthropicToolChoice", abstract = TRUE)
AnthropicToolChoiceUnspecified <- S7::new_class(
  "AnthropicToolChoiceUnspecified",
  parent = AnthropicToolChoice
)
AnthropicToolChoiceAuto <- S7::new_class(
  "AnthropicToolChoiceAuto",
  parent = AnthropicToolChoice
)
AnthropicToolChoiceAny <- S7::new_class(
  "AnthropicToolChoiceAny",
  parent = AnthropicToolChoice
)
AnthropicToolChoiceNone <- S7::new_class(
  "AnthropicToolChoiceNone",
  parent = AnthropicToolChoice
)
AnthropicToolChoiceNamed <- S7::new_class(
  "AnthropicToolChoiceNamed",
  parent = AnthropicToolChoice,
  properties = list(name = rho_non_empty_string)
)

AnthropicToolNamePolicy <- S7::new_class("AnthropicToolNamePolicy", abstract = TRUE)
AnthropicExactToolNames <- S7::new_class(
  "AnthropicExactToolNames",
  parent = AnthropicToolNamePolicy
)
AnthropicClaudeCodeToolNames <- S7::new_class(
  "AnthropicClaudeCodeToolNames",
  parent = AnthropicToolNamePolicy,
  properties = list(canonical = rho_unique_non_empty_strings)
)

AnthropicRequestSection <- S7::new_class(
  "AnthropicRequestSection",
  parent = ProviderRequestSection,
  abstract = TRUE
)
AnthropicOmittedRequestSection <- S7::new_class(
  "AnthropicOmittedRequestSection",
  parent = AnthropicRequestSection
)
AnthropicCoreRequestSection <- S7::new_class(
  "AnthropicCoreRequestSection",
  parent = AnthropicRequestSection,
  properties = list(model = rho_non_empty_string, messages = S7::class_list)
)
AnthropicSystemRequestSection <- S7::new_class(
  "AnthropicSystemRequestSection",
  parent = AnthropicRequestSection,
  properties = list(content = rho_anthropic_wire_blocks)
)
AnthropicToolsRequestSection <- S7::new_class(
  "AnthropicToolsRequestSection",
  parent = AnthropicRequestSection,
  properties = list(
    tools = S7::class_list,
    tool_input = AnthropicToolInputCapability,
    tool_names = AnthropicToolNamePolicy,
    cache_control = AnthropicCacheControl,
    choice = AnthropicToolChoice
  )
)

AnthropicThinkingRequestSection <- S7::new_class(
  "AnthropicThinkingRequestSection",
  parent = AnthropicRequestSection,
  abstract = TRUE,
  properties = list(max_tokens = rho_positive_integer)
)
AnthropicThinkingUnspecifiedRequestSection <- S7::new_class(
  "AnthropicThinkingUnspecifiedRequestSection",
  parent = AnthropicThinkingRequestSection
)
AnthropicThinkingDisabledRequestSection <- S7::new_class(
  "AnthropicThinkingDisabledRequestSection",
  parent = AnthropicThinkingRequestSection
)
AnthropicBudgetThinkingRequestSection <- S7::new_class(
  "AnthropicBudgetThinkingRequestSection",
  parent = AnthropicThinkingRequestSection,
  properties = list(
    budget_tokens = rho_positive_integer,
    display = AnthropicThinkingDisplay
  )
)
AnthropicAdaptiveThinkingRequestSection <- S7::new_class(
  "AnthropicAdaptiveThinkingRequestSection",
  parent = AnthropicThinkingRequestSection,
  properties = list(
    effort = rho_non_empty_string,
    display = AnthropicThinkingDisplay
  )
)
AnthropicTemperatureRequestSection <- S7::new_class(
  "AnthropicTemperatureRequestSection",
  parent = AnthropicRequestSection,
  properties = list(value = rho_nonnegative_double)
)
AnthropicMetadataRequestSection <- S7::new_class(
  "AnthropicMetadataRequestSection",
  parent = AnthropicRequestSection,
  properties = list(user_id = rho_non_empty_string)
)

AnthropicBetaFeature <- S7::new_class("AnthropicBetaFeature", abstract = TRUE)
AnthropicInterleavedThinkingBeta <- S7::new_class(
  "AnthropicInterleavedThinkingBeta",
  parent = AnthropicBetaFeature
)
AnthropicFineGrainedToolStreamingBeta <- S7::new_class(
  "AnthropicFineGrainedToolStreamingBeta",
  parent = AnthropicBetaFeature
)
AnthropicRequestPlan <- S7::new_class(
  "AnthropicRequestPlan",
  parent = ProviderRequestPlan,
  properties = list(
    sections = S7::class_list,
    beta_features = S7::class_list
  ),
  validator = function(self) {
    invalid_sections <- Filter(
      function(section) !S7::S7_inherits(section, AnthropicRequestSection),
      self@sections
    )
    if (length(invalid_sections)) {
      return("@sections must contain only AnthropicRequestSection values")
    }
    invalid_features <- Filter(
      function(feature) !S7::S7_inherits(feature, AnthropicBetaFeature),
      self@beta_features
    )
    if (length(invalid_features)) {
      "@beta_features must contain only AnthropicBetaFeature values"
    }
  }
)

rho_anthropic_content_blocks <- S7::new_generic(
  "rho_anthropic_content_blocks",
  c("content", "compatibility"),
  function(content, compatibility, ...) S7::S7_dispatch()
)
rho_anthropic_message <- S7::new_generic(
  "rho_anthropic_message",
  c("message", "compatibility"),
  function(message, compatibility, ...) S7::S7_dispatch()
)
rho_anthropic_block_fields <- S7::new_generic(
  "rho_anthropic_block_fields",
  "block",
  function(block, ...) S7::S7_dispatch()
)
rho_anthropic_message_fields <- S7::new_generic(
  "rho_anthropic_message_fields",
  "message",
  function(message, ...) S7::S7_dispatch()
)
rho_anthropic_role_value <- S7::new_generic(
  "rho_anthropic_role_value",
  "role",
  function(role, ...) S7::S7_dispatch()
)
rho_anthropic_block_accepts_cache <- S7::new_generic(
  "rho_anthropic_block_accepts_cache",
  "block",
  function(block, ...) S7::S7_dispatch()
)
rho_anthropic_block_present <- S7::new_generic(
  "rho_anthropic_block_present",
  "block",
  function(block, ...) S7::S7_dispatch()
)
rho_anthropic_roles_match <- S7::new_generic(
  "rho_anthropic_roles_match",
  c("left", "right"),
  function(left, right, ...) S7::S7_dispatch()
)
rho_anthropic_cache_block <- S7::new_generic(
  "rho_anthropic_cache_block",
  "block",
  function(block, cache_control, ...) S7::S7_dispatch()
)
rho_anthropic_cache_control <- S7::new_generic(
  "rho_anthropic_cache_control",
  c("capability", "retention"),
  function(capability, retention, ...) S7::S7_dispatch()
)
rho_anthropic_thinking_section <- S7::new_generic(
  "rho_anthropic_thinking_section",
  c("capability", "level"),
  function(capability, level, model, options = list(), ...) S7::S7_dispatch()
)
rho_anthropic_temperature_section <- S7::new_generic(
  "rho_anthropic_temperature_section",
  c("capability", "request", "thinking"),
  function(capability, request, thinking, ...) S7::S7_dispatch()
)
rho_anthropic_tool_fields <- S7::new_generic(
  "rho_anthropic_tool_fields",
  c("tool", "capability"),
  function(tool, capability, ...) S7::S7_dispatch()
)
rho_anthropic_web_search_type <- S7::new_generic(
  "rho_anthropic_web_search_type",
  "protocol",
  function(protocol, ...) S7::S7_dispatch()
)
rho_anthropic_web_search_domain_fields <- S7::new_generic(
  "rho_anthropic_web_search_domain_fields",
  "domains",
  function(domains, ...) S7::S7_dispatch()
)
rho_anthropic_web_search_location_fields <- S7::new_generic(
  "rho_anthropic_web_search_location_fields",
  "location",
  function(location, ...) S7::S7_dispatch()
)
rho_anthropic_web_search_input <- S7::new_generic(
  "rho_anthropic_web_search_input",
  "action",
  function(action, ...) S7::S7_dispatch()
)
rho_anthropic_tool_choice_fields <- S7::new_generic(
  "rho_anthropic_tool_choice_fields",
  "choice",
  function(choice, ...) S7::S7_dispatch()
)
rho_anthropic_tool_choice_requires_tools <- S7::new_generic(
  "rho_anthropic_tool_choice_requires_tools",
  "choice",
  function(choice, ...) S7::S7_dispatch()
)
rho_anthropic_tool_name <- S7::new_generic(
  "rho_anthropic_tool_name",
  "policy",
  function(policy, name, ...) S7::S7_dispatch()
)
rho_anthropic_local_tool_name <- S7::new_generic(
  "rho_anthropic_local_tool_name",
  "policy",
  function(policy, name, local_names, ...) S7::S7_dispatch()
)
rho_anthropic_tool_name_policy <- S7::new_generic(
  "rho_anthropic_tool_name_policy",
  "auth",
  function(auth, ...) S7::S7_dispatch()
)
rho_anthropic_request_sections <- S7::new_generic(
  "rho_anthropic_request_sections",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_anthropic_request_plan <- S7::new_generic(
  "rho_anthropic_request_plan",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_anthropic_messages_body <- S7::new_generic(
  "rho_anthropic_messages_body",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_anthropic_thinking_display_value <- S7::new_generic(
  "rho_anthropic_thinking_display_value",
  "display",
  function(display, ...) S7::S7_dispatch()
)
rho_anthropic_beta_name <- S7::new_generic(
  "rho_anthropic_beta_name",
  "feature",
  function(feature, ...) S7::S7_dispatch()
)
rho_anthropic_tool_beta_features <- S7::new_generic(
  "rho_anthropic_tool_beta_features",
  "capability",
  function(capability, tools, ...) S7::S7_dispatch()
)
rho_anthropic_thinking_beta_features <- S7::new_generic(
  "rho_anthropic_thinking_beta_features",
  "section",
  function(section, interleaved = TRUE, ...) S7::S7_dispatch()
)

rho_anthropic_no_cache <- function() AnthropicNoCache()
rho_anthropic_short_cache <- function() AnthropicShortCache()
rho_anthropic_long_cache <- function() AnthropicLongCache()

rho_anthropic_exact_tool_names <- function() AnthropicExactToolNames()

rho_anthropic_claude_code_tool_names <- function() {
  # Compatibility data from earendil-works/pi at dcfe36c, which cites the
  # Claude Code 2.1.11 prompt archive in github.com/badlogic/cchistory.
  AnthropicClaudeCodeToolNames(
    canonical = c(
      "Read",
      "Write",
      "Edit",
      "Bash",
      "Grep",
      "Glob",
      "AskUserQuestion",
      "EnterPlanMode",
      "ExitPlanMode",
      "KillShell",
      "NotebookEdit",
      "Skill",
      "Task",
      "TaskOutput",
      "TodoWrite",
      "WebFetch",
      "WebSearch"
    )
  )
}

S7::method(rho_anthropic_tool_name, AnthropicExactToolNames) <- function(
  policy,
  name,
  ...
) {
  name
}

S7::method(rho_anthropic_local_tool_name, AnthropicExactToolNames) <- function(
  policy,
  name,
  local_names,
  ...
) {
  name
}

S7::method(rho_anthropic_tool_name, AnthropicClaudeCodeToolNames) <- function(
  policy,
  name,
  ...
) {
  index <- match(tolower(name), tolower(policy@canonical))
  if (is.na(index)) name else policy@canonical[[index]]
}

S7::method(rho_anthropic_local_tool_name, AnthropicClaudeCodeToolNames) <- function(
  policy,
  name,
  local_names,
  ...
) {
  index <- match(tolower(name), tolower(local_names))
  if (is.na(index)) name else local_names[[index]]
}

rho_anthropic_temperature <- function(value = NULL) {
  if (S7::S7_inherits(value, AnthropicTemperatureRequest)) {
    return(value)
  }
  if (is.null(value)) {
    return(AnthropicTemperatureUnspecified())
  }
  AnthropicTemperatureValue(value = as.double(value))
}

rho_anthropic_tool_choice <- function(value = NULL) {
  if (is.null(value)) {
    return(AnthropicToolChoiceUnspecified())
  }
  if (!S7::S7_inherits(value, AnthropicToolChoice)) {
    rho_signal_contract_violation(
      "`tool_choice` must be an AnthropicToolChoice value"
    )
  }
  value
}

rho_anthropic_thinking_display <- function(value = NULL) {
  if (is.null(value)) {
    return(AnthropicSummarizedThinking())
  }
  if (!S7::S7_inherits(value, AnthropicThinkingDisplay)) {
    rho_signal_contract_violation(
      "`thinking_display` must be an AnthropicThinkingDisplay value"
    )
  }
  value
}

S7::method(
  rho_anthropic_cache_control,
  list(AnthropicCacheCapability, AnthropicNoCache)
) <- function(capability, retention, ...) {
  AnthropicCacheControl(
    enabled = FALSE,
    tools = FALSE,
    fields = list(),
    reason = "Prompt caching was explicitly disabled"
  )
}

S7::method(
  rho_anthropic_cache_control,
  list(AnthropicCacheCapability, AnthropicShortCache)
) <- function(capability, retention, ...) {
  AnthropicCacheControl(
    enabled = TRUE,
    tools = capability@tools,
    fields = list(type = "ephemeral"),
    reason = "The request selected Anthropic's short cache retention"
  )
}

S7::method(
  rho_anthropic_cache_control,
  list(AnthropicCacheCapability, AnthropicLongCache)
) <- function(capability, retention, ...) {
  if (!capability@long_retention) {
    return(rho_unsupported_provider_operation(
      "anthropic_long_cache_retention",
      "This model endpoint does not declare support for one-hour Anthropic cache retention"
    ))
  }
  AnthropicCacheControl(
    enabled = TRUE,
    tools = capability@tools,
    fields = list(type = "ephemeral", ttl = "1h"),
    reason = "The request selected Anthropic's one-hour cache retention"
  )
}

S7::method(
  rho_anthropic_thinking_display_value,
  AnthropicSummarizedThinking
) <- function(display, ...) {
  "summarized"
}

S7::method(
  rho_anthropic_thinking_display_value,
  AnthropicOmittedThinking
) <- function(display, ...) {
  "omitted"
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureCapability,
    AnthropicTemperatureUnspecified,
    AnthropicThinkingRequestSection
  )
) <- function(capability, request, thinking, ...) {
  AnthropicOmittedRequestSection()
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureAccepted,
    AnthropicTemperatureValue,
    AnthropicThinkingUnspecifiedRequestSection
  )
) <- function(capability, request, thinking, ...) {
  AnthropicTemperatureRequestSection(value = request@value)
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureAccepted,
    AnthropicTemperatureValue,
    AnthropicThinkingDisabledRequestSection
  )
) <- function(capability, request, thinking, ...) {
  AnthropicTemperatureRequestSection(value = request@value)
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureAccepted,
    AnthropicTemperatureValue,
    AnthropicBudgetThinkingRequestSection
  )
) <- function(capability, request, thinking, ...) {
  rho_unsupported_provider_operation(
    "anthropic_temperature_with_thinking",
    "Anthropic temperature cannot be combined with budget-based thinking"
  )
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureAccepted,
    AnthropicTemperatureValue,
    AnthropicAdaptiveThinkingRequestSection
  )
) <- function(capability, request, thinking, ...) {
  rho_unsupported_provider_operation(
    "anthropic_temperature_with_thinking",
    "Anthropic temperature cannot be combined with adaptive thinking"
  )
}

S7::method(
  rho_anthropic_temperature_section,
  list(
    AnthropicTemperatureOmitted,
    AnthropicTemperatureValue,
    AnthropicThinkingRequestSection
  )
) <- function(capability, request, thinking, ...) {
  rho_unsupported_provider_operation(
    "anthropic_temperature",
    "This Anthropic model declares that temperature must be omitted"
  )
}

S7::method(rho_anthropic_tool_choice_fields, AnthropicToolChoiceUnspecified) <- function(
  choice,
  ...
) {
  list()
}

S7::method(rho_anthropic_tool_choice_fields, AnthropicToolChoiceAuto) <- function(choice, ...) {
  list(tool_choice = list(type = "auto"))
}

S7::method(rho_anthropic_tool_choice_fields, AnthropicToolChoiceAny) <- function(choice, ...) {
  list(tool_choice = list(type = "any"))
}

S7::method(rho_anthropic_tool_choice_fields, AnthropicToolChoiceNone) <- function(choice, ...) {
  list(tool_choice = list(type = "none"))
}

S7::method(rho_anthropic_tool_choice_fields, AnthropicToolChoiceNamed) <- function(choice, ...) {
  dots <- list(...)
  tool_names <- dots$tool_names %||% rho_anthropic_exact_tool_names()
  list(
    tool_choice = list(
      type = "tool",
      name = rho_anthropic_tool_name(tool_names, choice@name)
    )
  )
}

S7::method(
  rho_anthropic_tool_choice_requires_tools,
  AnthropicToolChoice
) <- function(choice, ...) {
  FALSE
}

S7::method(
  rho_anthropic_tool_choice_requires_tools,
  AnthropicToolChoiceAny
) <- function(choice, ...) {
  TRUE
}

S7::method(
  rho_anthropic_tool_choice_requires_tools,
  AnthropicToolChoiceNamed
) <- function(choice, ...) {
  TRUE
}

S7::method(rho_anthropic_beta_name, AnthropicInterleavedThinkingBeta) <- function(
  feature,
  ...
) {
  "interleaved-thinking-2025-05-14"
}

S7::method(
  rho_anthropic_beta_name,
  AnthropicFineGrainedToolStreamingBeta
) <- function(feature, ...) {
  "fine-grained-tool-streaming-2025-05-14"
}

S7::method(
  rho_anthropic_tool_beta_features,
  AnthropicEagerToolInput
) <- function(capability, tools, ...) {
  list()
}

S7::method(
  rho_anthropic_tool_beta_features,
  AnthropicFineGrainedToolInput
) <- function(capability, tools, ...) {
  if (length(tools)) list(AnthropicFineGrainedToolStreamingBeta()) else list()
}

S7::method(
  rho_anthropic_thinking_beta_features,
  AnthropicBudgetThinkingRequestSection
) <- function(section, interleaved = TRUE, ...) {
  if (isTRUE(interleaved)) list(AnthropicInterleavedThinkingBeta()) else list()
}

S7::method(
  rho_anthropic_thinking_beta_features,
  AnthropicThinkingRequestSection
) <- function(section, interleaved = TRUE, ...) {
  list()
}

rho_anthropic_tool_call_id <- function(id) {
  normalized <- gsub("[^a-zA-Z0-9_-]", "_", id)
  substr(normalized, 1L, 64L)
}

S7::method(rho_anthropic_block_fields, AnthropicTextBlock) <- function(block, ...) {
  c(list(type = "text", text = block@text), block@cache_control)
}

S7::method(rho_anthropic_block_fields, AnthropicImageBlock) <- function(block, ...) {
  c(
    list(
      type = "image",
      source = list(
        type = "base64",
        media_type = block@mime_type,
        data = block@data
      )
    ),
    block@cache_control
  )
}

S7::method(rho_anthropic_block_fields, AnthropicThinkingBlock) <- function(block, ...) {
  list(type = "thinking", thinking = block@thinking, signature = block@signature)
}

S7::method(
  rho_anthropic_block_fields,
  AnthropicRedactedThinkingBlock
) <- function(block, ...) {
  list(type = "redacted_thinking", data = block@data)
}

S7::method(rho_anthropic_block_fields, AnthropicToolUseBlock) <- function(block, ...) {
  list(type = "tool_use", id = block@id, name = block@name, input = block@input)
}

S7::method(rho_anthropic_block_fields, AnthropicToolResultBlock) <- function(block, ...) {
  c(
    list(
      type = "tool_result",
      tool_use_id = block@tool_use_id,
      content = unname(lapply(block@content, rho_anthropic_block_fields)),
      is_error = block@is_error
    ),
    block@cache_control
  )
}

S7::method(
  rho_anthropic_block_fields,
  AnthropicServerToolUseBlock
) <- function(block, ...) {
  list(
    type = "server_tool_use",
    id = block@id,
    name = block@name,
    input = block@input
  )
}

S7::method(
  rho_anthropic_block_fields,
  AnthropicWebSearchToolResultBlock
) <- function(block, ...) {
  list(
    type = "web_search_tool_result",
    tool_use_id = block@tool_use_id,
    content = block@content
  )
}

S7::method(rho_anthropic_message_fields, AnthropicWireMessage) <- function(message, ...) {
  list(
    role = rho_anthropic_role_value(message@role),
    content = unname(lapply(message@content, rho_anthropic_block_fields))
  )
}

S7::method(rho_anthropic_role_value, AnthropicUserRole) <- function(role, ...) "user"
S7::method(rho_anthropic_role_value, AnthropicAssistantRole) <- function(role, ...) {
  "assistant"
}

rho_anthropic_first_error <- function(values) {
  errors <- Filter(function(value) S7::S7_inherits(value, ProviderErrorValue), values)
  if (length(errors)) errors[[1L]] else NULL
}

S7::method(
  rho_anthropic_content_blocks,
  list(S7::class_character, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  list(AnthropicTextBlock(
    text = paste(content, collapse = "\n"),
    cache_control = list()
  ))
}

S7::method(
  rho_anthropic_web_search_input,
  WebSearchActionUnspecified
) <- function(action, ...) {
  list()
}

S7::method(
  rho_anthropic_web_search_input,
  WebSearchSearchAction
) <- function(action, ...) {
  list(query = paste(action@queries, collapse = " "))
}

S7::method(
  rho_anthropic_web_search_input,
  WebSearchOpenPageAction
) <- function(action, ...) {
  list(url = action@url)
}

S7::method(
  rho_anthropic_web_search_input,
  WebSearchFindInPageAction
) <- function(action, ...) {
  list(url = action@url, pattern = action@pattern)
}

S7::method(
  rho_anthropic_web_search_input,
  WebSearchUnknownAction
) <- function(action, ...) {
  action@payload
}

S7::method(
  rho_anthropic_content_blocks,
  list(WebSearchCallContent, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  list(AnthropicServerToolUseBlock(
    id = content@id,
    name = "web_search",
    input = rho_anthropic_web_search_input(content@action)
  ))
}

rho_anthropic_web_search_result_value <- function(result) {
  fields <- list(
    type = "web_search_result",
    url = result@url,
    title = result@title,
    age = result@age,
    encrypted_content = result@encrypted_content
  )
  Filter(nzchar, fields)
}

S7::method(
  rho_anthropic_content_blocks,
  list(WebSearchResultContent, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  value <- if (is.null(content@error)) {
    unname(lapply(content@results, rho_anthropic_web_search_result_value))
  } else {
    list(
      type = "web_search_tool_result_error",
      error_code = content@error@code
    )
  }
  list(AnthropicWebSearchToolResultBlock(
    tool_use_id = content@call_id,
    content = value
  ))
}

S7::method(
  rho_anthropic_content_blocks,
  list(S7::class_list, AnthropicMessagesCompatibility)
) <- function(
  content,
  compatibility,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  unlist(
    lapply(
      content,
      function(value) {
        rho_anthropic_content_blocks(
          value,
          compatibility,
          tool_names = tool_names
        )
      }
    ),
    recursive = FALSE,
    use.names = FALSE
  )
}

S7::method(
  rho_anthropic_content_blocks,
  list(TextContent, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  list(AnthropicTextBlock(text = content@text, cache_control = list()))
}

S7::method(
  rho_anthropic_content_blocks,
  list(ImageContent, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  list(AnthropicImageBlock(
    data = content@data,
    mime_type = content@mime_type,
    cache_control = list()
  ))
}

S7::method(
  rho_anthropic_content_blocks,
  list(ThinkingContent, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  if (content@redacted) {
    if (!nzchar(content@signature)) {
      return(list(rho_provider_error(
        "Redacted Anthropic thinking content requires its opaque signature",
        kind = "protocol",
        code = "missing_thinking_signature"
      )))
    }
    return(list(AnthropicRedactedThinkingBlock(data = content@signature)))
  }
  if (!nzchar(content@signature) && !compatibility@allow_empty_signature) {
    return(list(AnthropicTextBlock(
      text = content@text,
      cache_control = list(),
      reason = paste(
        "Unsigned thinking was represented as text because this endpoint",
        "does not accept empty Anthropic thinking signatures"
      )
    )))
  }
  list(AnthropicThinkingBlock(
    thinking = content@text,
    signature = content@signature
  ))
}

S7::method(
  rho_anthropic_content_blocks,
  list(ToolCall, AnthropicMessagesCompatibility)
) <- function(
  content,
  compatibility,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  list(AnthropicToolUseBlock(
    id = rho_anthropic_tool_call_id(content@id),
    name = rho_anthropic_tool_name(tool_names, content@name),
    input = content@arguments
  ))
}

S7::method(
  rho_anthropic_content_blocks,
  list(S7::class_any, AnthropicMessagesCompatibility)
) <- function(content, compatibility, ...) {
  list(rho_provider_error(
    sprintf("Anthropic Messages cannot encode content class %s", rho_class_label(content)),
    kind = "protocol",
    code = "unsupported_content",
    details = list(content_class = rho_class_label(content))
  ))
}

S7::method(rho_anthropic_block_present, AnthropicTextBlock) <- function(block, ...) {
  nzchar(trimws(block@text))
}

S7::method(rho_anthropic_block_present, AnthropicWireBlock) <- function(block, ...) TRUE

rho_anthropic_present_blocks <- function(blocks) {
  Filter(rho_anthropic_block_present, blocks)
}

S7::method(
  rho_anthropic_message,
  list(UserMessage, AnthropicMessagesCompatibility)
) <- function(
  message,
  compatibility,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  blocks <- rho_anthropic_content_blocks(
    message@content,
    compatibility,
    tool_names = tool_names
  )
  error <- rho_anthropic_first_error(blocks)
  if (!is.null(error)) {
    return(error)
  }
  AnthropicWireMessage(
    role = AnthropicUserRole(),
    content = rho_anthropic_present_blocks(blocks)
  )
}

S7::method(
  rho_anthropic_message,
  list(AssistantMessage, AnthropicMessagesCompatibility)
) <- function(
  message,
  compatibility,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  blocks <- rho_anthropic_content_blocks(
    message@content,
    compatibility,
    tool_names = tool_names
  )
  error <- rho_anthropic_first_error(blocks)
  if (!is.null(error)) {
    return(error)
  }
  AnthropicWireMessage(
    role = AnthropicAssistantRole(),
    content = rho_anthropic_present_blocks(blocks)
  )
}

S7::method(
  rho_anthropic_message,
  list(ToolResultMessage, AnthropicMessagesCompatibility)
) <- function(
  message,
  compatibility,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  blocks <- rho_anthropic_content_blocks(
    message@content,
    compatibility,
    tool_names = tool_names
  )
  error <- rho_anthropic_first_error(blocks)
  if (!is.null(error)) {
    return(error)
  }
  blocks <- rho_anthropic_present_blocks(blocks)
  if (!length(blocks)) {
    blocks <- list(AnthropicTextBlock(text = "(no output)", cache_control = list()))
  }
  has_text <- any(vapply(
    blocks,
    function(block) S7::S7_inherits(block, AnthropicTextBlock),
    logical(1)
  ))
  if (!has_text) {
    blocks <- c(
      list(AnthropicTextBlock(text = "(see attached image)", cache_control = list())),
      blocks
    )
  }
  AnthropicWireMessage(
    role = AnthropicUserRole(),
    content = list(AnthropicToolResultBlock(
      tool_use_id = rho_anthropic_tool_call_id(message@tool_call_id),
      content = blocks,
      is_error = message@is_error,
      cache_control = list()
    ))
  )
}

S7::method(
  rho_anthropic_message,
  list(S7::class_any, AnthropicMessagesCompatibility)
) <- function(message, compatibility, ...) {
  rho_provider_error(
    sprintf("Anthropic Messages cannot encode message class %s", rho_class_label(message)),
    kind = "protocol",
    code = "unsupported_message",
    details = list(message_class = rho_class_label(message))
  )
}

S7::method(
  rho_anthropic_roles_match,
  list(AnthropicUserRole, AnthropicUserRole)
) <- function(left, right, ...) TRUE

S7::method(
  rho_anthropic_roles_match,
  list(AnthropicAssistantRole, AnthropicAssistantRole)
) <- function(left, right, ...) TRUE

S7::method(
  rho_anthropic_roles_match,
  list(AnthropicMessageRole, AnthropicMessageRole)
) <- function(left, right, ...) FALSE

S7::method(rho_anthropic_block_accepts_cache, AnthropicTextBlock) <- function(block, ...) TRUE
S7::method(rho_anthropic_block_accepts_cache, AnthropicImageBlock) <- function(block, ...) TRUE
S7::method(
  rho_anthropic_block_accepts_cache,
  AnthropicToolResultBlock
) <- function(block, ...) TRUE
S7::method(rho_anthropic_block_accepts_cache, AnthropicWireBlock) <- function(block, ...) {
  FALSE
}

S7::method(rho_anthropic_cache_block, AnthropicTextBlock) <- function(
  block,
  cache_control,
  ...
) {
  AnthropicTextBlock(
    text = block@text,
    cache_control = list(cache_control = cache_control@fields),
    reason = block@reason
  )
}

S7::method(rho_anthropic_cache_block, AnthropicImageBlock) <- function(
  block,
  cache_control,
  ...
) {
  AnthropicImageBlock(
    data = block@data,
    mime_type = block@mime_type,
    cache_control = list(cache_control = cache_control@fields)
  )
}

S7::method(rho_anthropic_cache_block, AnthropicToolResultBlock) <- function(
  block,
  cache_control,
  ...
) {
  AnthropicToolResultBlock(
    tool_use_id = block@tool_use_id,
    content = block@content,
    is_error = block@is_error,
    cache_control = list(cache_control = cache_control@fields)
  )
}

S7::method(rho_anthropic_cache_block, AnthropicWireBlock) <- function(
  block,
  cache_control,
  ...
) {
  block
}

rho_anthropic_cache_message <- function(message, cache_control) {
  if (!cache_control@enabled || !length(message@content)) {
    return(message)
  }
  indexes <- rev(seq_along(message@content))
  cacheable <- Filter(
    function(index) rho_anthropic_block_accepts_cache(message@content[[index]]),
    indexes
  )
  if (!length(cacheable)) {
    return(message)
  }
  index <- cacheable[[1L]]
  content <- message@content
  content[[index]] <- rho_anthropic_cache_block(content[[index]], cache_control)
  AnthropicWireMessage(role = message@role, content = content)
}

rho_anthropic_coalesce_messages <- function(messages) {
  output <- list()
  for (message in messages) {
    if (!length(message@content)) {
      next
    }
    previous <- if (length(output)) output[[length(output)]] else NULL
    if (!is.null(previous) && rho_anthropic_roles_match(previous@role, message@role)) {
      output[[length(output)]] <- AnthropicWireMessage(
        role = previous@role,
        content = c(previous@content, message@content)
      )
    } else {
      output[[length(output) + 1L]] <- message
    }
  }
  output
}

rho_anthropic_messages <- function(
  context,
  compatibility,
  cache_control,
  tool_names = rho_anthropic_exact_tool_names()
) {
  messages <- lapply(
    context@messages,
    function(message) {
      rho_anthropic_message(message, compatibility, tool_names = tool_names)
    }
  )
  error <- rho_anthropic_first_error(messages)
  if (!is.null(error)) {
    return(error)
  }
  messages <- rho_anthropic_coalesce_messages(messages)
  user_indexes <- which(vapply(
    messages,
    function(message) S7::S7_inherits(message@role, AnthropicUserRole),
    logical(1)
  ))
  if (length(user_indexes)) {
    index <- user_indexes[[length(user_indexes)]]
    messages[[index]] <- rho_anthropic_cache_message(messages[[index]], cache_control)
  }
  messages
}

rho_anthropic_requested_max_tokens <- function(model, options) {
  as.integer(options$max_tokens %||% model@limits@max_tokens)
}

rho_anthropic_default_thinking_budgets <- function() {
  c(minimal = 1024L, low = 2048L, medium = 8192L, high = 16384L)
}

rho_anthropic_budget_for_level <- function(model, level, options) {
  if (!is.null(options$thinking_budget_tokens)) {
    return(as.integer(options$thinking_budget_tokens))
  }
  budgets <- utils::modifyList(
    as.list(rho_anthropic_default_thinking_budgets()),
    options$thinking_budgets %||% list()
  )
  clamped <- rho_clamp_thinking_level(model, level@name)
  budget_level <- if (clamped %in% names(budgets)) clamped else "high"
  as.integer(budgets[[budget_level]])
}

rho_anthropic_adjust_budget <- function(model, level, options) {
  budget <- rho_anthropic_budget_for_level(model, level, options)
  requested <- options$max_tokens
  max_tokens <- if (is.null(requested)) {
    model@limits@max_tokens
  } else {
    min(as.integer(requested) + budget, model@limits@max_tokens)
  }
  if (max_tokens <= budget) {
    budget <- max_tokens - 1024L
  }
  if (budget < 1024L) {
    return(rho_unsupported_provider_operation(
      "anthropic_thinking_budget",
      "Anthropic thinking requires at least 1024 thinking tokens and 1024 output tokens"
    ))
  }
  list(max_tokens = as.integer(max_tokens), budget_tokens = as.integer(budget))
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicThinkingCapability, ThinkingUnspecified)
) <- function(capability, level, model, options = list(), ...) {
  AnthropicThinkingUnspecifiedRequestSection(
    max_tokens = rho_anthropic_requested_max_tokens(model, options)
  )
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicNoThinkingCapability, ThinkingOff)
) <- function(capability, level, model, options = list(), ...) {
  AnthropicThinkingUnspecifiedRequestSection(
    max_tokens = rho_anthropic_requested_max_tokens(model, options)
  )
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicThinkingCapability, ThinkingOff)
) <- function(capability, level, model, options = list(), ...) {
  AnthropicThinkingDisabledRequestSection(
    max_tokens = rho_anthropic_requested_max_tokens(model, options)
  )
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicNoThinkingCapability, ThinkingEnabled)
) <- function(capability, level, model, options = list(), ...) {
  rho_unsupported_provider_operation(
    "anthropic_thinking",
    sprintf("Anthropic model %s does not declare thinking support", model@id)
  )
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicBudgetThinkingCapability, ThinkingEnabled)
) <- function(capability, level, model, options = list(), ...) {
  adjusted <- rho_anthropic_adjust_budget(model, level, options)
  if (S7::S7_inherits(adjusted, ProviderErrorValue)) {
    return(adjusted)
  }
  AnthropicBudgetThinkingRequestSection(
    max_tokens = adjusted$max_tokens,
    budget_tokens = adjusted$budget_tokens,
    display = rho_anthropic_thinking_display(options$thinking_display)
  )
}

S7::method(
  rho_anthropic_thinking_section,
  list(AnthropicAdaptiveThinkingCapability, ThinkingEnabled)
) <- function(capability, level, model, options = list(), ...) {
  AnthropicAdaptiveThinkingRequestSection(
    max_tokens = rho_anthropic_requested_max_tokens(model, options),
    effort = rho_map_thinking_level(model, level@name),
    display = rho_anthropic_thinking_display(options$thinking_display)
  )
}

rho_anthropic_tool_base_fields <- function(tool, tool_names) {
  list(
    name = rho_anthropic_tool_name(tool_names, tool@name),
    description = tool@description,
    input_schema = tool@parameters
  )
}

S7::method(
  rho_anthropic_tool_fields,
  list(ToolSpec, AnthropicEagerToolInput)
) <- function(
  tool,
  capability,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  c(
    rho_anthropic_tool_base_fields(tool, tool_names),
    list(eager_input_streaming = TRUE)
  )
}

S7::method(
  rho_anthropic_web_search_type,
  AnthropicWebSearch20250305
) <- function(protocol, ...) {
  "web_search_20250305"
}

S7::method(
  rho_anthropic_web_search_type,
  AnthropicWebSearch20260209
) <- function(protocol, ...) {
  "web_search_20260209"
}

S7::method(
  rho_anthropic_web_search_type,
  AnthropicWebSearch20260318
) <- function(protocol, ...) {
  "web_search_20260318"
}

S7::method(
  rho_anthropic_web_search_domain_fields,
  RhoWebSearchAllDomains
) <- function(domains, ...) {
  list()
}

S7::method(
  rho_anthropic_web_search_domain_fields,
  RhoWebSearchAllowedDomains
) <- function(domains, ...) {
  list(allowed_domains = domains@domains)
}

S7::method(
  rho_anthropic_web_search_domain_fields,
  RhoWebSearchBlockedDomains
) <- function(domains, ...) {
  list(blocked_domains = domains@domains)
}

S7::method(
  rho_anthropic_web_search_location_fields,
  RhoWebSearchLocationUnspecified
) <- function(location, ...) {
  list()
}

S7::method(
  rho_anthropic_web_search_location_fields,
  RhoApproximateLocation
) <- function(location, ...) {
  fields <- list(
    type = "approximate",
    country = location@country,
    city = location@city,
    region = location@region,
    timezone = location@timezone
  )
  list(user_location = Filter(nzchar, fields))
}

S7::method(
  rho_anthropic_tool_fields,
  list(AnthropicWebSearchBinding, AnthropicToolInputCapability)
) <- function(
  tool,
  capability,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  operation <- tool@operation
  c(
    list(
      type = rho_anthropic_web_search_type(tool@protocol),
      name = "web_search"
    ),
    rho_anthropic_web_search_domain_fields(operation@domains),
    rho_anthropic_web_search_location_fields(operation@location)
  )
}

S7::method(
  rho_anthropic_tool_fields,
  list(ToolSpec, AnthropicFineGrainedToolInput)
) <- function(
  tool,
  capability,
  tool_names = rho_anthropic_exact_tool_names(),
  ...
) {
  rho_anthropic_tool_base_fields(tool, tool_names)
}

rho_anthropic_tools_section <- function(
  model,
  placement,
  compatibility,
  cache_control,
  choice,
  tool_names,
  operations = rho_operation_plan()
) {
  tools <- c(placement@immediate, operations@bindings)
  if (!length(tools)) {
    if (rho_anthropic_tool_choice_requires_tools(choice)) {
      return(rho_unsupported_provider_operation(
        "anthropic_tool_choice",
        "Anthropic cannot require a tool when no tool definitions are advertised"
      ))
    }
    return(AnthropicOmittedRequestSection())
  }
  if (!model@capabilities@tools) {
    return(rho_unsupported_provider_operation(
      "anthropic_tools",
      sprintf("Anthropic model %s does not declare tool support", model@id)
    ))
  }
  AnthropicToolsRequestSection(
    tools = tools,
    tool_input = compatibility@tool_input,
    tool_names = tool_names,
    cache_control = cache_control,
    choice = choice
  )
}

rho_anthropic_system_section <- function(context, cache_control, identity = character()) {
  text <- c(identity, if (nzchar(context@system_prompt)) context@system_prompt else character())
  if (!length(text)) {
    return(AnthropicOmittedRequestSection())
  }
  blocks <- lapply(text, function(value) {
    AnthropicTextBlock(text = value, cache_control = list())
  })
  if (cache_control@enabled) {
    blocks <- lapply(blocks, rho_anthropic_cache_block, cache_control = cache_control)
  }
  AnthropicSystemRequestSection(content = blocks)
}

rho_anthropic_metadata_section <- function(metadata = NULL) {
  user_id <- metadata$user_id %||% NULL
  if (is.null(user_id)) {
    return(AnthropicOmittedRequestSection())
  }
  AnthropicMetadataRequestSection(user_id = as.character(user_id))
}

S7::method(
  rho_anthropic_request_sections,
  list(AnthropicMessagesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  input_compatibility <- rho_validate_model_input(model, context)
  if (S7::S7_inherits(input_compatibility, ProviderErrorValue)) {
    return(list(input_compatibility))
  }
  compatibility <- model@compatibility
  if (!S7::S7_inherits(compatibility, AnthropicMessagesCompatibility)) {
    return(list(rho_provider_error(
      sprintf("Anthropic model %s has no Anthropic Messages capability profile", model@id),
      kind = "configuration",
      code = "anthropic_capability_profile"
    )))
  }
  retention <- options$cache_retention %||% rho_anthropic_short_cache()
  if (!S7::S7_inherits(retention, AnthropicCacheRetention)) {
    return(list(rho_provider_error(
      "Anthropic cache retention must be an AnthropicCacheRetention value",
      kind = "configuration",
      code = "anthropic_cache_retention"
    )))
  }
  cache_control <- rho_anthropic_cache_control(compatibility@cache, retention)
  if (S7::S7_inherits(cache_control, ProviderErrorValue)) {
    return(list(cache_control))
  }
  tool_names <- rho_anthropic_tool_name_policy(options$auth)
  messages <- rho_anthropic_messages(
    context,
    compatibility,
    cache_control,
    tool_names = tool_names
  )
  if (S7::S7_inherits(messages, ProviderErrorValue)) {
    return(list(messages))
  }
  if (!length(messages)) {
    return(list(rho_provider_error(
      "Anthropic Messages requires at least one user or assistant message",
      kind = "protocol",
      code = "anthropic_empty_messages"
    )))
  }
  thinking <- rho_anthropic_thinking_section(
    compatibility@thinking,
    rho_thinking_level(options$reasoning_effort),
    model,
    options
  )
  if (S7::S7_inherits(thinking, ProviderErrorValue)) {
    return(list(thinking))
  }
  temperature <- rho_anthropic_temperature_section(
    compatibility@temperature,
    rho_anthropic_temperature(options$temperature),
    thinking
  )
  if (S7::S7_inherits(temperature, ProviderErrorValue)) {
    return(list(temperature))
  }
  operations <- rho_request_operation_plan(context, options)
  if (S7::S7_inherits(operations, ProviderErrorValue)) {
    return(list(operations))
  }
  tools <- rho_anthropic_tools_section(
    model,
    placement,
    compatibility,
    cache_control,
    rho_anthropic_tool_choice(options$tool_choice),
    tool_names,
    operations
  )
  if (S7::S7_inherits(tools, ProviderErrorValue)) {
    return(list(tools))
  }
  list(
    AnthropicCoreRequestSection(model = model@id, messages = messages),
    rho_anthropic_system_section(
      context,
      cache_control,
      rho_anthropic_system_identity(options$auth)
    ),
    tools,
    thinking,
    temperature,
    rho_anthropic_metadata_section(options$metadata)
  )
}

S7::method(rho_request_fields, AnthropicOmittedRequestSection) <- function(section, ...) {
  list()
}

S7::method(rho_request_fields, AnthropicCoreRequestSection) <- function(section, ...) {
  list(
    model = section@model,
    messages = unname(lapply(section@messages, rho_anthropic_message_fields)),
    stream = TRUE
  )
}

S7::method(rho_request_fields, AnthropicSystemRequestSection) <- function(section, ...) {
  list(system = unname(lapply(section@content, rho_anthropic_block_fields)))
}

S7::method(rho_request_fields, AnthropicToolsRequestSection) <- function(section, ...) {
  tools <- unname(lapply(
    section@tools,
    rho_anthropic_tool_fields,
    capability = section@tool_input,
    tool_names = section@tool_names
  ))
  if (length(tools) && section@cache_control@enabled && section@cache_control@tools) {
    last <- length(tools)
    tools[[last]]$cache_control <- section@cache_control@fields
  }
  c(
    list(tools = tools),
    rho_anthropic_tool_choice_fields(
      section@choice,
      tool_names = section@tool_names
    )
  )
}

S7::method(
  rho_request_fields,
  AnthropicThinkingUnspecifiedRequestSection
) <- function(section, ...) {
  list(max_tokens = section@max_tokens)
}

S7::method(
  rho_request_fields,
  AnthropicThinkingDisabledRequestSection
) <- function(section, ...) {
  list(
    max_tokens = section@max_tokens,
    thinking = list(type = "disabled")
  )
}

S7::method(
  rho_request_fields,
  AnthropicBudgetThinkingRequestSection
) <- function(section, ...) {
  list(
    max_tokens = section@max_tokens,
    thinking = list(
      type = "enabled",
      budget_tokens = section@budget_tokens,
      display = rho_anthropic_thinking_display_value(section@display)
    )
  )
}

S7::method(
  rho_request_fields,
  AnthropicAdaptiveThinkingRequestSection
) <- function(section, ...) {
  list(
    max_tokens = section@max_tokens,
    thinking = list(
      type = "adaptive",
      display = rho_anthropic_thinking_display_value(section@display)
    ),
    output_config = list(effort = section@effort)
  )
}

S7::method(rho_request_fields, AnthropicTemperatureRequestSection) <- function(section, ...) {
  list(temperature = section@value)
}

S7::method(rho_request_fields, AnthropicMetadataRequestSection) <- function(section, ...) {
  list(metadata = list(user_id = section@user_id))
}

S7::method(
  rho_request_body,
  AnthropicRequestPlan
) <- function(plan, ...) {
  Reduce(
    utils::modifyList,
    lapply(plan@sections, rho_request_fields),
    init = list()
  )
}

rho_anthropic_plan_beta_features <- function(model, placement, sections, options) {
  compatibility <- model@compatibility
  thinking <- Filter(
    function(section) S7::S7_inherits(section, AnthropicThinkingRequestSection),
    sections
  )[[1L]]
  c(
    rho_anthropic_tool_beta_features(
      compatibility@tool_input,
      placement@immediate
    ),
    rho_anthropic_thinking_beta_features(
      thinking,
      interleaved = options$interleaved_thinking %||% TRUE
    )
  )
}

S7::method(
  rho_anthropic_request_plan,
  list(AnthropicMessagesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  sections <- rho_anthropic_request_sections(
    model,
    context,
    placement,
    options = options
  )
  error <- rho_anthropic_first_error(sections)
  if (!is.null(error)) {
    return(error)
  }
  AnthropicRequestPlan(
    sections = sections,
    beta_features = rho_anthropic_plan_beta_features(
      model,
      placement,
      sections,
      options
    )
  )
}

S7::method(
  rho_anthropic_messages_body,
  list(AnthropicMessagesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  plan <- rho_anthropic_request_plan(model, context, placement, options)
  if (S7::S7_inherits(plan, ProviderErrorValue)) {
    return(plan)
  }
  rho_request_body(plan)
}

rho_anthropic_beta_features <- function(model, context, placement, options = list()) {
  plan <- rho_anthropic_request_plan(model, context, placement, options)
  if (S7::S7_inherits(plan, ProviderErrorValue)) plan else plan@beta_features
}
