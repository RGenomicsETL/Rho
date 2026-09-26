rho_stream <- S7::new_generic(
  "rho_stream",
  c("provider", "model", "context"),
  function(provider, model, context, options = list(), ...) S7::S7_dispatch()
)
rho_complete <- S7::new_generic(
  "rho_complete",
  c("provider", "model", "context"),
  function(provider, model, context, options = list(), ...) S7::S7_dispatch()
)
rho_validate_tool_args <- S7::new_generic(
  "rho_validate_tool_args",
  c("tool", "args"),
  function(tool, args, ...) S7::S7_dispatch()
)
rho_execute_tool <- S7::new_generic(
  "rho_execute_tool",
  c("tool", "call", "context"),
  function(tool, call, context, signal = NULL, on_update = NULL, ...) {
    S7::S7_dispatch()
  }
)
rho_tool_overlap <- S7::new_generic(
  "rho_tool_overlap",
  c("tool", "call", "context"),
  function(tool, call, context, ...) S7::S7_dispatch()
)
rho_decode_provider_event <- S7::new_generic(
  "rho_decode_provider_event",
  c("decoder", "event"),
  function(decoder, event, ...) S7::S7_dispatch()
)
rho_provider_http_error <- S7::new_generic(
  "rho_provider_http_error",
  c("model", "error"),
  function(model, error, ...) S7::S7_dispatch()
)
rho_reduce_provider_event <- S7::new_generic(
  "rho_reduce_provider_event",
  "event",
  function(event, decoder, ...) S7::S7_dispatch()
)
rho_start_response_item <- S7::new_generic(
  "rho_start_response_item",
  "item",
  function(item, decoder, output_index, ...) S7::S7_dispatch()
)
rho_finish_response_item <- S7::new_generic(
  "rho_finish_response_item",
  "item",
  function(item, decoder, output_index, ...) S7::S7_dispatch()
)
rho_supported_thinking_levels <- S7::new_generic(
  "rho_supported_thinking_levels",
  "model",
  function(model, ...) S7::S7_dispatch()
)
rho_clamp_thinking_level <- S7::new_generic(
  "rho_clamp_thinking_level",
  "model",
  function(model, level, ...) S7::S7_dispatch()
)
rho_map_thinking_level <- S7::new_generic(
  "rho_map_thinking_level",
  "model",
  function(model, level, ...) S7::S7_dispatch()
)
rho_model_supports_input <- S7::new_generic(
  "rho_model_supports_input",
  "model",
  function(model, input, ...) S7::S7_dispatch()
)
rho_content_modalities <- S7::new_generic(
  "rho_content_modalities",
  "x",
  function(x, ...) S7::S7_dispatch()
)
rho_content_text <- S7::new_generic(
  "rho_content_text",
  "x",
  function(x, ...) S7::S7_dispatch()
)
rho_context_signature <- S7::new_generic(
  "rho_context_signature",
  "x",
  function(x, ...) S7::S7_dispatch()
)
rho_context_revision <- S7::new_generic(
  "rho_context_revision",
  c("context", "model"),
  function(context, model, ...) S7::S7_dispatch()
)
rho_usage_observations <- S7::new_generic(
  "rho_usage_observations",
  "x",
  function(x, ...) S7::S7_dispatch()
)
rho_summarize_usage <- S7::new_generic(
  "rho_summarize_usage",
  "x",
  function(x, ...) S7::S7_dispatch()
)
rho_validate_model_input <- S7::new_generic(
  "rho_validate_model_input",
  c("model", "context"),
  function(model, context, ...) S7::S7_dispatch()
)
rho_model_supports_transport <- S7::new_generic(
  "rho_model_supports_transport",
  c("model", "transport"),
  function(model, transport, ...) S7::S7_dispatch()
)
rho_transport_id <- S7::new_generic(
  "rho_transport_id",
  "transport",
  function(transport, ...) S7::S7_dispatch()
)
rho_provider_transports <- S7::new_generic(
  "rho_provider_transports",
  c("provider", "model"),
  function(provider, model, ...) S7::S7_dispatch()
)
rho_select_provider_transport <- S7::new_generic(
  "rho_select_provider_transport",
  c("provider", "model", "requested"),
  function(provider, model, requested = AutomaticTransport(), ...) {
    S7::S7_dispatch()
  }
)
rho_open_provider_transport <- S7::new_generic(
  "rho_open_provider_transport",
  c("transport", "provider", "model", "context"),
  function(transport, provider, model, context, options = list(), ...) {
    S7::S7_dispatch()
  }
)
rho_embedded_stream <- S7::new_generic(
  "rho_embedded_stream",
  c("executor", "provider", "model", "context"),
  function(executor, provider, model, context, options = list(), ...) {
    S7::S7_dispatch()
  }
)
rho_price_usage <- S7::new_generic(
  "rho_price_usage",
  c("model", "usage"),
  function(model, usage, ...) S7::S7_dispatch()
)
rho_usage_with_cost <- S7::new_generic(
  "rho_usage_with_cost",
  "usage",
  function(usage, cost, ...) S7::S7_dispatch()
)
rho_credential_read <- S7::new_generic(
  "rho_credential_read",
  "store",
  function(store, provider_id, ...) S7::S7_dispatch()
)
rho_credential_modify <- S7::new_generic(
  "rho_credential_modify",
  "store",
  function(store, provider_id, update, ...) S7::S7_dispatch()
)
rho_credential_delete <- S7::new_generic(
  "rho_credential_delete",
  "store",
  function(store, provider_id, ...) S7::S7_dispatch()
)
rho_credential_encode <- S7::new_generic(
  "rho_credential_encode",
  "credential",
  function(credential, ...) S7::S7_dispatch()
)
rho_credential_decode <- S7::new_generic(
  "rho_credential_decode",
  "auth",
  function(auth, document, provider_id, source = "", ...) S7::S7_dispatch()
)
rho_auth_login <- S7::new_generic("rho_auth_login", "auth", function(auth, provider_id, io, ...) {
  S7::S7_dispatch()
})
rho_auth_refresh <- S7::new_generic("rho_auth_refresh", "auth", function(auth, credential, ...) {
  S7::S7_dispatch()
})
rho_auth_to_request <- S7::new_generic(
  "rho_auth_to_request",
  "auth",
  function(auth, credential, ...) S7::S7_dispatch()
)
rho_login_strategy <- S7::new_generic(
  "rho_login_strategy",
  c("method", "provider"),
  function(method, provider, ...) S7::S7_dispatch()
)
rho_auth_prompt <- S7::new_generic("rho_auth_prompt", "io", function(io, prompt, ...) {
  S7::S7_dispatch()
})
rho_auth_notify <- S7::new_generic("rho_auth_notify", "io", function(io, event, ...) {
  S7::S7_dispatch()
})
rho_resolve_model_auth <- S7::new_generic(
  "rho_resolve_model_auth",
  "models",
  function(models, model, ...) S7::S7_dispatch()
)
rho_provider_models <- S7::new_generic(
  "rho_provider_models",
  c("provider", "credential"),
  function(provider, credential, ...) S7::S7_dispatch()
)
rho_available_models <- S7::new_generic(
  "rho_available_models",
  "models",
  function(models, provider_id, ...) S7::S7_dispatch()
)
rho_provider_support <- S7::new_generic(
  "rho_provider_support",
  c("provider", "model", "operation"),
  function(provider, model, operation, ...) S7::S7_dispatch()
)
rho_bind_operation <- S7::new_generic(
  "rho_bind_operation",
  c("handler", "model", "operation"),
  function(handler, model, operation, context, ...) S7::S7_dispatch()
)
rho_bind_web_search <- S7::new_generic(
  "rho_bind_web_search",
  "capability",
  function(capability, handler, model, operation, context, ...) S7::S7_dispatch()
)
rho_plan_operations <- S7::new_generic(
  "rho_plan_operations",
  c("handler", "model", "context"),
  function(handler, model, context, ...) S7::S7_dispatch()
)
rho_execute_operation <- S7::new_generic(
  "rho_execute_operation",
  "binding",
  function(binding, context, ...) S7::S7_dispatch()
)
rho_provider_dialect <- S7::new_generic(
  "rho_provider_dialect",
  c("provider", "model"),
  function(provider, model, ...) S7::S7_dispatch()
)
rho_plan_tools <- S7::new_generic(
  "rho_plan_tools",
  c("provider", "model", "context"),
  function(provider, model, context, ...) S7::S7_dispatch()
)
rho_build_provider_request <- S7::new_generic(
  "rho_build_provider_request",
  c("provider", "model", "context"),
  function(provider, model, context, options = list(), ...) S7::S7_dispatch()
)
rho_openai_responses_body <- S7::new_generic(
  "rho_openai_responses_body",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_openai_chat_request_body <- S7::new_generic(
  "rho_openai_chat_request_body",
  c("model", "context"),
  function(model, context, options = list(), ...) S7::S7_dispatch()
)
rho_openai_chat_content <- S7::new_generic(
  "rho_openai_chat_content",
  "content",
  function(content, ...) S7::S7_dispatch()
)
rho_openai_request_sections <- S7::new_generic(
  "rho_openai_request_sections",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_openai_request_plan <- S7::new_generic(
  "rho_openai_request_plan",
  c("model", "context", "placement"),
  function(model, context, placement, options = list(), ...) S7::S7_dispatch()
)
rho_request_fields <- S7::new_generic(
  "rho_request_fields",
  "section",
  function(section, ...) S7::S7_dispatch()
)
rho_request_body <- S7::new_generic(
  "rho_request_body",
  "plan",
  function(plan, ...) S7::S7_dispatch()
)
rho_openai_reasoning_section <- S7::new_generic(
  "rho_openai_reasoning_section",
  c("model", "level"),
  function(model, level, summary = "auto", ...) S7::S7_dispatch()
)
rho_provider_headers <- S7::new_generic(
  "rho_provider_headers",
  c("provider", "model", "context"),
  function(provider, model, context, options = list(), ...) S7::S7_dispatch()
)
rho_compact_provider_input <- S7::new_generic(
  "rho_compact_provider_input",
  c("provider", "model", "context"),
  function(provider, model, context, options = list(), ...) S7::S7_dispatch()
)
rho_assistant_event_type <- S7::new_generic(
  "rho_assistant_event_type",
  "event",
  function(event, ...) S7::S7_dispatch()
)

rho_nominal_usage_cost_for <- function(model, usage) {
  input_tokens <- usage@input + usage@cache_read + usage@cache_write
  rates <- model@pricing
  tiers <- Filter(
    function(tier) input_tokens > tier@input_tokens_above,
    model@pricing@tiers
  )
  if (length(tiers)) {
    thresholds <- vapply(tiers, function(tier) tier@input_tokens_above, double(1))
    rates <- tiers[[which.max(thresholds)]]
  }

  long_write <- usage@cache_write_1h %||% 0
  short_write <- usage@cache_write - long_write
  rho_nominal_usage_cost(
    input = rates@input * usage@input / 1e6,
    output = rates@output * usage@output / 1e6,
    cache_read = rates@cache_read * usage@cache_read / 1e6,
    cache_write = (rates@cache_write * short_write + rates@input * 2 * long_write) / 1e6
  )
}

S7::method(rho_usage_with_cost, ProviderUsage) <- function(usage, cost, ...) {
  rho_provider_usage(
    provider = usage@provider,
    input = usage@input,
    output = usage@output,
    cache_read = usage@cache_read,
    cache_write = usage@cache_write,
    cache_write_1h = usage@cache_write_1h,
    reasoning = usage@reasoning,
    cost = cost
  )
}

S7::method(rho_usage_with_cost, EstimatedUsage) <- function(usage, cost, ...) {
  rho_estimated_usage(
    estimator = usage@estimator,
    method = usage@method,
    input = usage@input,
    output = usage@output,
    cache_read = usage@cache_read,
    cache_write = usage@cache_write,
    cache_write_1h = usage@cache_write_1h,
    reasoning = usage@reasoning,
    cost = cost
  )
}

S7::method(rho_price_usage, list(Model, ProviderUsage)) <- function(model, usage, ...) {
  rho_usage_with_cost(usage, rho_nominal_usage_cost_for(model, usage))
}

S7::method(rho_price_usage, list(Model, EstimatedUsage)) <- function(model, usage, ...) {
  rho_usage_with_cost(usage, rho_nominal_usage_cost_for(model, usage))
}

S7::method(rho_price_usage, list(Model, UsageUnavailable)) <- function(model, usage, ...) {
  usage
}

S7::method(rho_assistant_event_type, AssistantStartEvent) <- function(event, ...) "start"
S7::method(rho_assistant_event_type, AssistantTextStartEvent) <- function(event, ...) "text_start"
S7::method(rho_assistant_event_type, AssistantTextDeltaEvent) <- function(event, ...) "text_delta"
S7::method(rho_assistant_event_type, AssistantTextEndEvent) <- function(event, ...) "text_end"
S7::method(rho_assistant_event_type, AssistantThinkingStartEvent) <- function(event, ...) {
  "thinking_start"
}
S7::method(rho_assistant_event_type, AssistantThinkingDeltaEvent) <- function(event, ...) {
  "thinking_delta"
}
S7::method(rho_assistant_event_type, AssistantThinkingEndEvent) <- function(event, ...) {
  "thinking_end"
}
S7::method(rho_assistant_event_type, AssistantToolCallStartEvent) <- function(event, ...) {
  "toolcall_start"
}
S7::method(rho_assistant_event_type, AssistantToolCallDeltaEvent) <- function(event, ...) {
  "toolcall_delta"
}
S7::method(rho_assistant_event_type, AssistantToolCallEndEvent) <- function(event, ...) {
  "toolcall_end"
}
S7::method(rho_assistant_event_type, AssistantOperationStartEvent) <- function(event, ...) {
  "operation_start"
}
S7::method(rho_assistant_event_type, AssistantOperationEndEvent) <- function(event, ...) {
  "operation_end"
}
S7::method(rho_assistant_event_type, AssistantDoneEvent) <- function(event, ...) "done"
S7::method(rho_assistant_event_type, AssistantErrorEvent) <- function(event, ...) "error"

rho_complete_terminal <- function(event) {
  if (is.null(event)) {
    return(rho_provider_error(
      "Provider stream ended without a terminal event",
      kind = "protocol",
      code = "missing_terminal_event"
    ))
  }
  if (S7::S7_inherits(event, AssistantErrorEvent)) {
    return(event@error)
  }
  event@message
}

rho_complete_stream <- function(stream, terminal = NULL) {
  rho_then(rho_stream_next(stream), function(item) {
    if (S7::S7_inherits(item, RhoAsyncError)) {
      rho_stream_close(stream)
      return(item)
    }
    if (S7::S7_inherits(item, RhoStreamEnd)) {
      rho_stream_close(stream)
      return(rho_complete_terminal(terminal))
    }
    if (!S7::S7_inherits(item, RhoStreamValue)) {
      rho_stream_close(stream)
      return(rho_provider_error(
        "Provider stream yielded a value outside the stream item protocol",
        kind = "protocol",
        code = "invalid_stream_item"
      ))
    }
    event <- item@value
    if (!S7::S7_inherits(event, AssistantEvent)) {
      rho_stream_close(stream)
      return(rho_provider_error(
        "Provider stream yielded a value outside the assistant event protocol",
        kind = "protocol",
        code = "invalid_assistant_event"
      ))
    }
    if (S7::S7_inherits(event, AssistantTerminalEvent)) {
      terminal <- event
    }
    rho_complete_stream(stream, terminal)
  })
}

S7::method(rho_complete, list(S7::class_any, Model, Context)) <- function(
  provider,
  model,
  context,
  options = list(),
  ...
) {
  stream <- tryCatch(
    rho_stream(provider, model, context, options = options),
    error = identity
  )
  if (inherits(stream, "error")) {
    return(rho_rejected(stream))
  }
  if (!rho_is_stream(stream)) {
    return(rho_task(rho_provider_error(
      "Provider did not return a RhoStream",
      kind = "protocol",
      code = "invalid_provider_stream"
    )))
  }
  completion <- rho_catch(
    rho_complete_stream(stream),
    function(error) {
      rho_stream_close(stream)
      rho_rejected(error)
    }
  )
  rho_task_from_promise(
    rho_as_promise(completion),
    cancel = function(reason) {
      rho_cancel(completion, reason)
      rho_stream_close(stream)
    },
    label = "complete"
  )
}

S7::method(rho_validate_tool_args, list(ToolSpec, S7::class_list)) <- function(tool, args, ...) {
  required <- tool@parameters$required %||% character()
  missing <- setdiff(required, names(args))
  if (length(missing)) {
    message <- sprintf(
      "Tool `%s` missing required parameter(s): %s",
      tool@name,
      paste(missing, collapse = ", ")
    )
    return(rho_tool_error_result(
      content = list(rho_text(message)),
      details = list(
        kind = "arguments",
        tool_name = tool@name,
        missing = missing
      )
    ))
  }
  if (!is.null(tool@prepare_arguments)) {
    prepared <- tryCatch(tool@prepare_arguments(args), error = identity)
    if (inherits(prepared, "error")) {
      return(rho_tool_error_result(
        content = list(rho_text(conditionMessage(prepared))),
        details = list(
          kind = "arguments",
          tool_name = tool@name,
          source = prepared
        )
      ))
    }
    args <- prepared
  }
  args
}

S7::method(rho_execute_tool, list(ToolSpec, ToolCall, S7::class_any)) <- function(
  tool,
  call,
  context,
  signal = NULL,
  on_update = NULL,
  ...
) {
  args <- call@arguments
  if (!call@arguments_prepared) {
    args <- rho_validate_tool_args(tool, args)
  }
  if (S7::S7_inherits(args, ToolErrorResult)) {
    return(rho_task(args))
  }
  out <- tool@execute(call@id, args, signal, on_update, context)
  rho_as_task(out)
}

S7::method(
  rho_tool_overlap,
  list(ToolSpec, ToolCall, S7::class_any)
) <- function(tool, call, context, ...) {
  tool@overlap
}
