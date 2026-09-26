rho_unique_tools <- function(tools) {
  if (!length(tools)) {
    return(list())
  }
  names <- vapply(tools, function(tool) tool@name, character(1))
  tools[!duplicated(names, fromLast = TRUE)]
}

rho_request_operation_plan <- function(context, options) {
  plan <- options$operation_plan
  if (!is.null(plan)) {
    if (S7::S7_inherits(plan, RhoOperationPlan)) {
      planned <- lapply(plan@bindings, function(binding) binding@operation)
      requested <- lapply(context@operations, function(operation) {
        if (S7::S7_inherits(operation, RhoOperationBinding)) {
          operation@operation
        } else {
          operation
        }
      })
      unbound <- Filter(
        function(operation) {
          !any(vapply(
            planned,
            function(candidate) identical(candidate, operation),
            logical(1)
          ))
        },
        requested
      )
      if (length(unbound)) {
        return(rho_provider_error(
          "`operation_plan` must bind every operation in the request context",
          kind = "configuration",
          code = "operation_plan_incomplete",
          details = list(
            operations = vapply(unbound, rho_class_label, character(1))
          )
        ))
      }
      return(plan)
    }
    return(rho_provider_error(
      "`operation_plan` must inherit from RhoOperationPlan",
      kind = "configuration",
      code = "operation_plan_type"
    ))
  }
  unbound <- Filter(
    function(operation) !S7::S7_inherits(operation, RhoOperationBinding),
    context@operations
  )
  if (length(unbound)) {
    return(rho_provider_error(
      "A context with semantic operations must be bound by rho_plan_operations() before request translation",
      kind = "configuration",
      code = "operation_plan_required",
      details = list(operations = vapply(unbound, rho_class_label, character(1)))
    ))
  }
  rho_operation_plan(context@operations)
}

rho_bound_operation_plan <- function(handler, model, context, options) {
  if (is.null(options$operation_plan)) {
    return(rho_plan_operations(handler, model, context))
  }
  rho_request_operation_plan(context, options)
}

rho_first_provider_error <- function(values) {
  errors <- Filter(
    function(value) S7::S7_inherits(value, ProviderErrorValue),
    values
  )
  if (length(errors)) errors[[1L]] else NULL
}

rho_class_label <- function(value) {
  s7_class <- S7::S7_class(value)
  if (is.null(s7_class)) {
    return(class(value)[[1L]])
  }
  s7_class@name
}

rho_deferred_tool_names <- function(context) {
  used <- character()
  deferred <- character()
  for (message in context@messages) {
    if (S7::S7_inherits(message, AssistantMessage)) {
      calls <- Filter(function(content) S7::S7_inherits(content, ToolCall), message@content)
      used <- unique(c(used, vapply(calls, function(call) call@name, character(1))))
    } else if (S7::S7_inherits(message, ToolResultMessage)) {
      newly_deferred <- setdiff(message@added_tool_names, used)
      deferred <- unique(c(deferred, newly_deferred))
    }
  }
  deferred
}

rho_split_deferred_tools <- function(context) {
  tools <- rho_unique_tools(context@tools)
  if (!length(tools)) {
    return(list(immediate = list(), deferred = list()))
  }
  deferred_names <- rho_deferred_tool_names(context)
  tool_names <- vapply(tools, function(tool) tool@name, character(1))
  is_deferred <- tool_names %in% deferred_names
  list(immediate = tools[!is_deferred], deferred = tools[is_deferred])
}

rho_full_tool_placement <- function(tools, reason, cache_expectation = "replace-prefix") {
  RhoFullToolPlacement(
    immediate = rho_unique_tools(tools),
    deferred = list(),
    cache_expectation = cache_expectation,
    reason = reason
  )
}

rho_openai_tool_search_placement <- function(immediate, deferred) {
  RhoOpenAIToolSearchPlacement(
    immediate = immediate,
    deferred = deferred,
    cache_expectation = if (length(deferred)) "preserve-prefix" else "unchanged",
    reason = "OpenAI tool-search placement is verified for this endpoint and model"
  )
}

rho_anthropic_tool_reference_placement <- function(immediate, deferred) {
  RhoAnthropicToolReferencePlacement(
    immediate = immediate,
    deferred = deferred,
    cache_expectation = if (length(deferred)) "preserve-prefix" else "unchanged",
    reason = "Anthropic deferred tool references are verified for this endpoint and model"
  )
}

rho_http_error_details <- function(error) {
  list(
    url = error@url,
    status = error@status,
    headers = error@headers,
    body = error@body,
    body_truncated = error@body_truncated
  )
}

rho_http_error_document <- function(error) {
  if (!length(error@body)) {
    return(NULL)
  }
  document <- tryCatch(
    yyjsonr::read_json_str(
      rawToChar(error@body),
      arr_of_objs_to_df = FALSE,
      obj_of_arrs_to_df = FALSE
    ),
    error = function(error) NULL
  )
  if (is.list(document)) document else NULL
}

S7::method(
  rho_provider_http_error,
  list(Model, RhoHttpTransportError)
) <- function(model, error, ...) {
  rho_provider_error(
    message = error@message,
    kind = "transport",
    code = "http_transport",
    retryable = TRUE,
    details = list(url = error@url, parent = error@parent)
  )
}

rho_http_status_retryable <- function(error) {
  status <- error@status
  status %in% c(408L, 409L, 425L, 429L) || status >= 500L
}

rho_http_status_provider_error <- function(error) {
  status <- error@status
  rho_provider_error(
    message = error@message,
    kind = "http_status",
    code = as.character(status),
    retryable = rho_http_status_retryable(error),
    details = rho_http_error_details(error)
  )
}

S7::method(
  rho_provider_http_error,
  list(Model, RhoHttpStatusError)
) <- function(model, error, ...) {
  rho_http_status_provider_error(error)
}

S7::method(
  rho_provider_support,
  list(S7::class_any, Model, RhoOperation)
) <- function(provider, model, operation, ...) {
  rho_provider_support_value(
    supported = FALSE,
    source = "default",
    details = list(
      provider_class = rho_class_label(provider),
      operation_class = rho_class_label(operation)
    )
  )
}

S7::method(
  rho_bind_operation,
  list(S7::class_any, Model, RhoOperation)
) <- function(handler, model, operation, context, ...) {
  rho_operation_unsupported(
    operation,
    handler,
    sprintf(
      "%s does not implement %s for model %s",
      rho_class_label(handler),
      rho_class_label(operation),
      model@id
    ),
    details = list(model = model@id)
  )
}

S7::method(
  rho_bind_web_search,
  RhoWebSearchUnavailable
) <- function(capability, handler, model, operation, context, ...) {
  rho_operation_unsupported(
    operation,
    handler,
    capability@reason,
    details = list(model = model@id)
  )
}

S7::method(
  rho_bind_operation,
  list(S7::class_any, Model, RhoNativeCompactionOperation)
) <- function(handler, model, operation, context, ...) {
  support <- rho_provider_support(handler, model, operation)
  if (!support@supported) {
    return(rho_operation_unsupported(
      operation,
      handler,
      sprintf(
        "%s does not declare native compaction for model %s",
        rho_class_label(handler),
        model@id
      ),
      details = support@details
    ))
  }
  RhoProviderCompactionBinding(
    operation = operation,
    handler = handler,
    reason = sprintf(
      "%s declares a provider-native compaction primitive for model %s",
      support@source,
      model@id
    ),
    model = model
  )
}

S7::method(
  rho_plan_operations,
  list(S7::class_any, Model, Context)
) <- function(handler, model, context, ...) {
  bindings <- list()
  for (operation in context@operations) {
    binding <- if (S7::S7_inherits(operation, RhoOperationBinding)) {
      operation
    } else {
      rho_bind_operation(handler, model, operation, context, ...)
    }
    if (S7::S7_inherits(binding, ProviderErrorValue)) {
      return(binding)
    }
    bindings[[length(bindings) + 1L]] <- binding
  }
  rho_operation_plan(bindings)
}

S7::method(
  rho_execute_operation,
  RhoOperationBinding
) <- function(binding, context, ...) {
  rho_task(rho_operation_unsupported(
    binding@operation,
    binding@handler,
    sprintf(
      "%s binds %s for translation, not local execution",
      rho_class_label(binding),
      rho_class_label(binding@operation)
    )
  ))
}

S7::method(
  rho_execute_operation,
  RhoProviderCompactionBinding
) <- function(binding, context, ...) {
  rho_compact_provider_input(
    binding@handler,
    binding@model,
    context,
    ...
  )
}

S7::method(
  rho_provider_dialect,
  list(S7::class_any, Model)
) <- function(provider, model, ...) {
  provider
}

S7::method(
  rho_plan_tools,
  list(S7::class_any, Model, Context)
) <- function(provider, model, context, ...) {
  rho_full_tool_placement(
    context@tools,
    reason = "The provider has no verified native deferred-tool protocol"
  )
}

S7::method(
  rho_build_provider_request,
  list(S7::class_any, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_unsupported_provider_operation(
    operation = "build_request",
    message = sprintf("No request translator is registered for %s", rho_class_label(provider))
  )
}

S7::method(
  rho_provider_headers,
  list(S7::class_any, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  model@headers
}

S7::method(
  rho_compact_provider_input,
  list(S7::class_any, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  rho_task(rho_unsupported_provider_operation(
    operation = "compact_provider_input",
    message = sprintf(
      "No provider-native input compactor is registered for %s",
      rho_class_label(provider)
    )
  ))
}

S7::method(
  rho_provider_support,
  list(RhoProvider, Model, RhoOperation)
) <- function(provider, model, operation, ...) {
  dialect <- rho_provider_dialect(provider@implementation, model)
  rho_provider_support(dialect, model, operation, ...)
}

S7::method(
  rho_bind_operation,
  list(RhoProvider, Model, RhoOperation)
) <- function(handler, model, operation, context, ...) {
  rho_bind_operation(
    handler@implementation,
    model,
    operation,
    context,
    ...
  )
}

S7::method(
  rho_bind_operation,
  list(RhoProvider, Model, RhoNativeCompactionOperation)
) <- function(handler, model, operation, context, ...) {
  rho_bind_operation(
    handler@implementation,
    model,
    operation,
    context,
    ...
  )
}

S7::method(
  rho_plan_tools,
  list(RhoProvider, Model, Context)
) <- function(provider, model, context, ...) {
  dialect <- rho_provider_dialect(provider@implementation, model)
  rho_plan_tools(dialect, model, context, ...)
}

S7::method(
  rho_build_provider_request,
  list(RhoProvider, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  dialect <- rho_provider_dialect(provider@implementation, model)
  rho_build_provider_request(dialect, model, context, options = options, ...)
}

S7::method(
  rho_provider_headers,
  list(RhoProvider, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  dialect <- rho_provider_dialect(provider@implementation, model)
  rho_provider_headers(dialect, model, context, options = options, ...)
}

S7::method(
  rho_compact_provider_input,
  list(RhoProvider, Model, Context)
) <- function(provider, model, context, options = list(), ...) {
  dialect <- rho_provider_dialect(provider@implementation, model)
  rho_compact_provider_input(dialect, model, context, options = options, ...)
}
