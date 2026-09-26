rho_thinking_level_name <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (
      length(value) != 1L ||
        is.na(value) ||
        !value %in% c("off", "minimal", "low", "medium", "high", "xhigh", "max")
    ) {
      "must be one canonical thinking level"
    }
  }
)

ThinkingRequest <- S7::new_class("ThinkingRequest", abstract = TRUE)
ThinkingUnspecified <- S7::new_class("ThinkingUnspecified", parent = ThinkingRequest)
ThinkingLevel <- S7::new_class(
  "ThinkingLevel",
  parent = ThinkingRequest,
  abstract = TRUE,
  properties = list(name = rho_thinking_level_name)
)
ThinkingOff <- S7::new_class("ThinkingOff", parent = ThinkingLevel)
ThinkingEnabled <- S7::new_class("ThinkingEnabled", parent = ThinkingLevel)

OpenAIWebSearchBinding <- S7::new_class(
  "OpenAIWebSearchBinding",
  parent = RhoProviderToolBinding
)

rho_openai_tool_fields <- S7::new_generic(
  "rho_openai_tool_fields",
  "tool",
  function(tool, defer_loading = FALSE, ...) S7::S7_dispatch()
)
rho_openai_web_search_domain_fields <- S7::new_generic(
  "rho_openai_web_search_domain_fields",
  "domains",
  function(domains, ...) S7::S7_dispatch()
)
rho_openai_web_search_location_fields <- S7::new_generic(
  "rho_openai_web_search_location_fields",
  "location",
  function(location, ...) S7::S7_dispatch()
)
rho_openai_web_search_binding <- S7::new_generic(
  "rho_openai_web_search_binding",
  "domains",
  function(domains, handler, model, operation, ...) S7::S7_dispatch()
)
rho_openai_content_input <- S7::new_generic(
  "rho_openai_content_input",
  "content",
  function(content, ...) S7::S7_dispatch()
)
rho_openai_input_content <- S7::new_generic(
  "rho_openai_input_content",
  c("content", "model"),
  function(content, model, ...) S7::S7_dispatch()
)
rho_openai_operation_status_value <- S7::new_generic(
  "rho_openai_operation_status_value",
  "status",
  function(status, ...) S7::S7_dispatch()
)
rho_openai_web_search_action_section <- S7::new_generic(
  "rho_openai_web_search_action_section",
  "action",
  function(action, ...) S7::S7_dispatch()
)

S7::method(
  rho_openai_web_search_binding,
  RhoWebSearchDomainPolicy
) <- function(domains, handler, model, operation, ...) {
  OpenAIWebSearchBinding(
    operation = operation,
    handler = handler,
    reason = paste(
      "The selected OpenAI Responses endpoint implements this search",
      "as a provider-hosted web_search tool"
    )
  )
}

S7::method(
  rho_openai_web_search_binding,
  RhoWebSearchBlockedDomains
) <- function(domains, handler, model, operation, ...) {
  rho_operation_unsupported(
    operation,
    handler,
    "OpenAI web search accepts an allow list, not a blocked-domain list",
    details = list(model = model@id, blocked_domains = domains@domains)
  )
}

rho_thinking_level <- function(value = NULL) {
  if (S7::S7_inherits(value, ThinkingRequest)) {
    return(value)
  }
  if (is.null(value)) {
    return(ThinkingUnspecified())
  }
  value <- as.character(value)
  if (identical(value, "off")) {
    ThinkingOff(name = value)
  } else {
    ThinkingEnabled(name = value)
  }
}

OpenAIRequestSection <- S7::new_class(
  "OpenAIRequestSection",
  parent = ProviderRequestSection,
  abstract = TRUE
)
OpenAIRequestPlan <- S7::new_class(
  "OpenAIRequestPlan",
  parent = ProviderRequestPlan,
  properties = list(sections = S7::class_list),
  validator = function(self) {
    invalid <- Filter(
      function(section) !S7::S7_inherits(section, OpenAIRequestSection),
      self@sections
    )
    if (length(invalid)) "@sections must contain only OpenAIRequestSection values"
  }
)
OpenAIOmittedRequestSection <- S7::new_class(
  "OpenAIOmittedRequestSection",
  parent = OpenAIRequestSection
)
OpenAICoreRequestSection <- S7::new_class(
  "OpenAICoreRequestSection",
  parent = OpenAIRequestSection,
  properties = list(model = rho_non_empty_string, input = S7::class_list)
)
OpenAIInstructionsRequestSection <- S7::new_class(
  "OpenAIInstructionsRequestSection",
  parent = OpenAIRequestSection,
  properties = list(instructions = rho_non_empty_string)
)

rho_openai_tool_choice_wire <- S7::new_property(
  S7::class_any,
  validator = function(value) {
    valid_name <- is.character(value) &&
      length(value) == 1L &&
      !is.na(value) &&
      value %in% c("auto", "none", "required")
    valid_function <- is.list(value) &&
      identical(value$type, "function") &&
      is.character(value$name) &&
      length(value$name) == 1L &&
      !is.na(value$name) &&
      nzchar(value$name)
    if (!valid_name && !valid_function) {
      "must be auto, none, required, or a named function choice"
    }
  }
)

OpenAIToolChoice <- S7::new_class(
  "OpenAIToolChoice",
  properties = list(wire = rho_openai_tool_choice_wire)
)
OpenAIToolsRequestSection <- S7::new_class(
  "OpenAIToolsRequestSection",
  parent = OpenAIRequestSection,
  properties = list(
    tools = S7::class_list,
    choice = OpenAIToolChoice,
    parallel = rho_scalar_logical
  )
)
OpenAIMaxOutputTokensRequestSection <- S7::new_class(
  "OpenAIMaxOutputTokensRequestSection",
  parent = OpenAIRequestSection,
  properties = list(value = rho_positive_integer)
)
OpenAITemperatureRequestSection <- S7::new_class(
  "OpenAITemperatureRequestSection",
  parent = OpenAIRequestSection,
  properties = list(value = rho_nonnegative_double),
  validator = function(self) {
    if (self@value > 2) "@value must not exceed two"
  }
)

rho_openai_service_tier_value <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (
      length(value) != 1L ||
        is.na(value) ||
        !value %in% c("auto", "default", "flex", "priority")
    ) {
      "must be auto, default, flex, or priority"
    }
  }
)

OpenAIServiceTierRequestSection <- S7::new_class(
  "OpenAIServiceTierRequestSection",
  parent = OpenAIRequestSection,
  properties = list(value = rho_openai_service_tier_value)
)

rho_openai_text_verbosity_value <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (
      length(value) != 1L ||
        is.na(value) ||
        !value %in% c("low", "medium", "high")
    ) {
      "must be low, medium, or high"
    }
  }
)

OpenAITextVerbosityRequestSection <- S7::new_class(
  "OpenAITextVerbosityRequestSection",
  parent = OpenAIRequestSection,
  properties = list(value = rho_openai_text_verbosity_value)
)
OpenAICacheKeyRequestSection <- S7::new_class(
  "OpenAICacheKeyRequestSection",
  parent = OpenAIRequestSection,
  properties = list(
    key = S7::new_property(
      S7::class_character,
      validator = function(value) {
        if (
          length(value) != 1L ||
            is.na(value) ||
            !nzchar(value) ||
            nchar(value, type = "chars") > 64L
        ) {
          "must be a non-empty string of at most 64 characters"
        }
      }
    )
  )
)
OpenAIReasoningDisabledRequestSection <- S7::new_class(
  "OpenAIReasoningDisabledRequestSection",
  parent = OpenAIRequestSection,
  properties = list(effort = rho_non_empty_string)
)
OpenAIReasoningEnabledRequestSection <- S7::new_class(
  "OpenAIReasoningEnabledRequestSection",
  parent = OpenAIRequestSection,
  properties = list(effort = rho_non_empty_string, summary = rho_non_empty_string)
)

rho_openai_instruction_section <- function(value, default = NULL) {
  candidates <- c(value, default)
  candidates <- candidates[nzchar(candidates)]
  if (!length(candidates)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAIInstructionsRequestSection(instructions = candidates[[1L]])
  }
}

rho_openai_tool_choice <- function(value = NULL) {
  OpenAIToolChoice(wire = value %||% "auto")
}

rho_openai_tool_section <- function(model, placement, operations, choice) {
  tools <- c(placement@immediate, operations@bindings)
  advertise <- model@capabilities@tools && length(tools) > 0L
  if (!advertise) {
    return(OpenAIOmittedRequestSection())
  }
  OpenAIToolsRequestSection(
    tools = tools,
    choice = choice,
    parallel = model@capabilities@parallel_tool_calls
  )
}

rho_openai_max_output_tokens_section <- function(value = NULL) {
  if (is.null(value)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAIMaxOutputTokensRequestSection(value = as.integer(value))
  }
}

rho_openai_temperature_section <- function(value = NULL) {
  if (is.null(value)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAITemperatureRequestSection(value = as.double(value))
  }
}

rho_openai_service_tier_section <- function(value = NULL) {
  if (is.null(value)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAIServiceTierRequestSection(value = as.character(value))
  }
}

rho_openai_text_verbosity_section <- function(value = NULL) {
  if (is.null(value)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAITextVerbosityRequestSection(value = as.character(value))
  }
}

rho_openai_cache_key_section <- function(value = NULL) {
  if (is.null(value)) {
    OpenAIOmittedRequestSection()
  } else {
    OpenAICacheKeyRequestSection(
      key = substr(as.character(value), 1L, 64L)
    )
  }
}

S7::method(
  rho_openai_reasoning_section,
  list(Model, ThinkingUnspecified)
) <- function(model, level, summary = "auto", ...) {
  OpenAIOmittedRequestSection()
}

S7::method(
  rho_openai_reasoning_section,
  list(Model, ThinkingOff)
) <- function(model, level, summary = "auto", ...) {
  OpenAIReasoningDisabledRequestSection(
    effort = rho_map_thinking_level(model, level@name)
  )
}

S7::method(
  rho_openai_reasoning_section,
  list(Model, ThinkingEnabled)
) <- function(model, level, summary = "auto", ...) {
  OpenAIReasoningEnabledRequestSection(
    effort = rho_map_thinking_level(model, level@name),
    summary = summary
  )
}

rho_openai_standard_request_sections <- function(
  model,
  context,
  placement,
  options,
  instruction_default = NULL,
  reasoning_default = NULL,
  verbosity_default = NULL
) {
  input_compatibility <- rho_validate_model_input(model, context)
  if (S7::S7_inherits(input_compatibility, ProviderErrorValue)) {
    return(list(input_compatibility))
  }
  operations <- rho_request_operation_plan(context, options)
  if (S7::S7_inherits(operations, ProviderErrorValue)) {
    return(list(operations))
  }
  input <- rho_openai_responses_input(context, placement, model)
  if (S7::S7_inherits(input, ProviderErrorValue)) {
    return(list(input))
  }
  list(
    OpenAICoreRequestSection(
      model = model@id,
      input = input
    ),
    rho_openai_instruction_section(context@system_prompt, instruction_default),
    rho_openai_tool_section(
      model,
      placement,
      operations,
      rho_openai_tool_choice(options$tool_choice)
    ),
    rho_openai_max_output_tokens_section(options$max_tokens),
    rho_openai_temperature_section(options$temperature),
    rho_openai_service_tier_section(options$service_tier),
    rho_openai_text_verbosity_section(options$text_verbosity %||% verbosity_default),
    rho_openai_cache_key_section(options$session_id),
    rho_openai_reasoning_section(
      model,
      rho_thinking_level(options$reasoning_effort %||% reasoning_default),
      summary = options$reasoning_summary %||% "auto"
    )
  )
}

S7::method(
  rho_openai_request_sections,
  list(OpenAIResponsesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  rho_openai_standard_request_sections(model, context, placement, options)
}

S7::method(
  rho_openai_request_sections,
  list(OpenAICodexResponsesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  rho_openai_standard_request_sections(
    model,
    context,
    placement,
    options,
    instruction_default = "You are a helpful assistant.",
    reasoning_default = "low",
    verbosity_default = "low"
  )
}

S7::method(
  rho_openai_request_plan,
  list(OpenAIResponsesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  sections <- rho_openai_request_sections(
    model,
    context,
    placement,
    options = options
  )
  error <- rho_first_provider_error(sections)
  if (!is.null(error)) {
    return(error)
  }
  OpenAIRequestPlan(sections = sections)
}

S7::method(rho_request_fields, OpenAIOmittedRequestSection) <- function(section, ...) {
  list()
}

S7::method(rho_request_fields, OpenAICoreRequestSection) <- function(section, ...) {
  list(
    model = section@model,
    input = section@input,
    store = FALSE,
    stream = TRUE
  )
}

S7::method(
  rho_request_fields,
  OpenAIInstructionsRequestSection
) <- function(section, ...) {
  list(instructions = section@instructions)
}

S7::method(rho_request_fields, OpenAIToolsRequestSection) <- function(section, ...) {
  list(
    tools = rho_openai_responses_tools(section@tools),
    tool_choice = section@choice@wire,
    parallel_tool_calls = section@parallel
  )
}

S7::method(rho_openai_tool_fields, ToolSpec) <- function(
  tool,
  defer_loading = FALSE,
  ...
) {
  definition <- list(
    type = "function",
    name = tool@name,
    description = tool@description,
    parameters = tool@parameters
  )
  if (isTRUE(defer_loading)) {
    definition$defer_loading <- TRUE
  }
  definition
}

S7::method(
  rho_openai_web_search_domain_fields,
  RhoWebSearchAllDomains
) <- function(domains, ...) {
  list()
}

S7::method(
  rho_openai_web_search_domain_fields,
  RhoWebSearchAllowedDomains
) <- function(domains, ...) {
  list(filters = list(allowed_domains = domains@domains))
}

S7::method(
  rho_openai_web_search_location_fields,
  RhoWebSearchLocationUnspecified
) <- function(location, ...) {
  list()
}

S7::method(
  rho_openai_web_search_location_fields,
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

S7::method(rho_openai_tool_fields, OpenAIWebSearchBinding) <- function(
  tool,
  defer_loading = FALSE,
  ...
) {
  operation <- tool@operation
  c(
    list(type = "web_search"),
    rho_openai_web_search_domain_fields(operation@domains),
    rho_openai_web_search_location_fields(operation@location)
  )
}

S7::method(rho_openai_content_input, Content) <- function(content, ...) {
  list()
}

S7::method(
  rho_openai_input_content,
  list(S7::class_character, OpenAIResponsesModel)
) <- function(content, model, ...) {
  list(list(type = "input_text", text = paste(content, collapse = "")))
}

S7::method(
  rho_openai_input_content,
  list(TextContent, OpenAIResponsesModel)
) <- function(content, model, ...) {
  list(list(type = "input_text", text = content@text))
}

S7::method(
  rho_openai_input_content,
  list(ImageContent, OpenAIResponsesModel)
) <- function(content, model, ...) {
  if (!rho_model_supports_input(model, "image")) {
    return(rho_provider_input_unsupported(model, "image"))
  }
  list(list(
    type = "input_image",
    detail = "auto",
    image_url = sprintf("data:%s;base64,%s", content@mime_type, content@data)
  ))
}

S7::method(
  rho_openai_input_content,
  list(S7::class_list, OpenAIResponsesModel)
) <- function(content, model, ...) {
  parts <- lapply(content, rho_openai_input_content, model = model)
  error <- rho_first_provider_error(parts)
  if (!is.null(error)) {
    return(error)
  }
  unlist(parts, recursive = FALSE, use.names = FALSE)
}

S7::method(
  rho_openai_input_content,
  list(S7::class_any, OpenAIResponsesModel)
) <- function(content, model, ...) {
  rho_provider_error(
    sprintf("OpenAI Responses cannot encode input content class %s", rho_class_label(content)),
    kind = "protocol",
    code = "unsupported_content",
    details = list(content_class = rho_class_label(content), model = model@id)
  )
}

rho_openai_responses_input <- function(context, placement, model) {
  input <- list()
  deferred <- placement@deferred
  deferred_names <- if (length(deferred)) {
    vapply(deferred, function(tool) tool@name, character(1))
  } else {
    character()
  }
  loaded_names <- character()
  for (message_index in seq_along(context@messages)) {
    message <- context@messages[[message_index]]
    if (S7::S7_inherits(message, UserMessage)) {
      content <- rho_openai_input_content(message@content, model)
      if (S7::S7_inherits(content, ProviderErrorValue)) {
        return(content)
      }
      input[[length(input) + 1L]] <- list(
        role = "user",
        content = content
      )
    } else if (S7::S7_inherits(message, AssistantMessage)) {
      text <- rho_content_text(message@content)
      if (nzchar(text)) {
        input[[length(input) + 1L]] <- list(
          role = "assistant",
          content = list(list(type = "output_text", text = text))
        )
      }
      content_items <- unlist(
        lapply(message@content, rho_openai_content_input),
        recursive = FALSE,
        use.names = FALSE
      )
      input <- c(input, content_items)
    } else if (S7::S7_inherits(message, ToolResultMessage)) {
      output_content <- rho_openai_input_content(message@content, model)
      if (S7::S7_inherits(output_content, ProviderErrorValue)) {
        return(output_content)
      }
      has_image <- "image" %in% rho_content_modalities(message@content)
      input[[length(input) + 1L]] <- list(
        type = "function_call_output",
        call_id = message@tool_call_id,
        output = if (has_image) output_content else rho_content_text(message@content)
      )
      names_to_load <- intersect(
        message@added_tool_names,
        setdiff(deferred_names, loaded_names)
      )
      if (length(names_to_load)) {
        loaded_names <- c(loaded_names, names_to_load)
        loaded_tools <- deferred[deferred_names %in% names_to_load]
        search_call_id <- sprintf("rho_tool_load_%d", message_index)
        input[[length(input) + 1L]] <- list(
          type = "tool_search_call",
          call_id = search_call_id,
          execution = "client",
          status = "completed",
          arguments = list(
            query = paste(names_to_load, collapse = " "),
            limit = length(names_to_load)
          )
        )
        input[[length(input) + 1L]] <- list(
          type = "tool_search_output",
          call_id = search_call_id,
          execution = "client",
          status = "completed",
          tools = rho_openai_responses_tools(loaded_tools, defer_loading = TRUE)
        )
      }
    }
  }
  input
}

rho_openai_responses_tools <- function(tools, defer_loading = FALSE) {
  unname(lapply(
    tools,
    rho_openai_tool_fields,
    defer_loading = defer_loading
  ))
}

S7::method(rho_openai_content_input, ToolCall) <- function(content, ...) {
  list(list(
    type = "function_call",
    call_id = content@id,
    name = content@name,
    arguments = yyjsonr::write_json_str(content@arguments, auto_unbox = TRUE)
  ))
}

S7::method(rho_openai_operation_status_value, OperationPending) <- function(status, ...) {
  "queued"
}
S7::method(rho_openai_operation_status_value, OperationInProgress) <- function(status, ...) {
  "in_progress"
}
S7::method(rho_openai_operation_status_value, OperationCompleted) <- function(status, ...) {
  "completed"
}
S7::method(rho_openai_operation_status_value, OperationFailed) <- function(status, ...) {
  "failed"
}

S7::method(
  rho_openai_web_search_action_section,
  WebSearchActionUnspecified
) <- function(action, ...) {
  list()
}

S7::method(
  rho_openai_web_search_action_section,
  WebSearchSearchAction
) <- function(action, ...) {
  list(
    action = list(
      type = "search",
      query = paste(action@queries, collapse = " "),
      sources = action@sources
    )
  )
}

S7::method(
  rho_openai_web_search_action_section,
  WebSearchOpenPageAction
) <- function(action, ...) {
  list(action = list(type = "open_page", url = action@url))
}

S7::method(
  rho_openai_web_search_action_section,
  WebSearchFindInPageAction
) <- function(action, ...) {
  list(
    action = list(
      type = "find_in_page",
      url = action@url,
      pattern = action@pattern
    )
  )
}

S7::method(
  rho_openai_web_search_action_section,
  WebSearchUnknownAction
) <- function(action, ...) {
  list(action = action@payload)
}

S7::method(rho_openai_content_input, WebSearchCallContent) <- function(content, ...) {
  list(c(
    list(
      type = "web_search_call",
      id = content@id,
      status = rho_openai_operation_status_value(content@status)
    ),
    rho_openai_web_search_action_section(content@action)
  ))
}

S7::method(
  rho_request_fields,
  OpenAIMaxOutputTokensRequestSection
) <- function(section, ...) {
  list(max_output_tokens = section@value)
}

S7::method(
  rho_request_fields,
  OpenAITemperatureRequestSection
) <- function(section, ...) {
  list(temperature = section@value)
}

S7::method(
  rho_request_fields,
  OpenAIServiceTierRequestSection
) <- function(section, ...) {
  list(service_tier = section@value)
}

S7::method(
  rho_request_fields,
  OpenAITextVerbosityRequestSection
) <- function(section, ...) {
  list(text = list(verbosity = section@value))
}

S7::method(rho_request_fields, OpenAICacheKeyRequestSection) <- function(section, ...) {
  list(prompt_cache_key = section@key)
}

S7::method(
  rho_request_fields,
  OpenAIReasoningDisabledRequestSection
) <- function(section, ...) {
  list(reasoning = list(effort = section@effort))
}

S7::method(
  rho_request_fields,
  OpenAIReasoningEnabledRequestSection
) <- function(section, ...) {
  list(
    reasoning = list(effort = section@effort, summary = section@summary),
    include = list("reasoning.encrypted_content")
  )
}

S7::method(
  rho_request_body,
  OpenAIRequestPlan
) <- function(plan, ...) {
  Reduce(
    utils::modifyList,
    lapply(plan@sections, rho_request_fields),
    init = list()
  )
}

S7::method(
  rho_openai_responses_body,
  list(OpenAIResponsesModel, Context, RhoToolPlacement)
) <- function(model, context, placement, options = list(), ...) {
  plan <- rho_openai_request_plan(
    model,
    context,
    placement,
    options = options
  )
  if (S7::S7_inherits(plan, ProviderErrorValue)) {
    return(plan)
  }
  rho_request_body(plan)
}
