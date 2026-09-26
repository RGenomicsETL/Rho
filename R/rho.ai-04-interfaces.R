Provider <- s7contract::new_interface(
  "Provider",
  generics = list(
    rho_stream = s7contract::interface_requirement(
      rho_stream,
      args = list(model = Model, context = Context),
      returns = RhoStream
    )
  )
)
EmbeddedExecutor <- s7contract::new_interface(
  "EmbeddedExecutor",
  generics = list(
    rho_embedded_stream = s7contract::interface_requirement(
      rho_embedded_stream,
      args = list(provider = RhoEmbeddedProvider, model = Model, context = Context),
      returns = RhoStream
    )
  )
)
Tool <- s7contract::new_interface(
  "Tool",
  generics = list(
    rho_validate_tool_args = s7contract::interface_requirement(
      rho_validate_tool_args,
      args = list(args = S7::class_list)
    ),
    rho_execute_tool = s7contract::interface_requirement(
      rho_execute_tool,
      args = list(call = ToolCall, context = S7::class_any),
      returns = RhoTask
    ),
    rho_tool_overlap = s7contract::interface_requirement(
      rho_tool_overlap,
      args = list(call = ToolCall, context = S7::class_any),
      returns = ToolOverlap
    )
  )
)
ProviderEventDecoder <- s7contract::new_interface(
  "ProviderEventDecoder",
  generics = list(
    rho_decode_provider_event = s7contract::interface_requirement(
      rho_decode_provider_event,
      args = list(event = S7::class_any)
    )
  )
)
ProviderWireEvent <- s7contract::new_interface(
  "ProviderWireEvent",
  generics = list(rho_reduce_provider_event = rho_reduce_provider_event)
)
ResponseItemProtocol <- s7contract::new_interface(
  "ResponseItemProtocol",
  generics = list(
    rho_start_response_item = rho_start_response_item,
    rho_finish_response_item = rho_finish_response_item
  )
)
ProviderRequestSectionProtocol <- s7contract::new_interface(
  "ProviderRequestSectionProtocol",
  generics = list(
    rho_request_fields = s7contract::interface_requirement(
      rho_request_fields,
      returns = S7::class_list
    )
  )
)
ProviderRequestPlanProtocol <- s7contract::new_interface(
  "ProviderRequestPlanProtocol",
  generics = list(
    rho_request_body = s7contract::interface_requirement(
      rho_request_body,
      returns = S7::class_list
    )
  )
)
CredentialStore <- s7contract::new_interface(
  "CredentialStore",
  generics = list(
    rho_credential_read = rho_credential_read,
    rho_credential_modify = rho_credential_modify,
    rho_credential_delete = rho_credential_delete
  )
)
OAuthAuth <- s7contract::new_interface(
  "OAuthAuth",
  generics = list(
    rho_auth_login = rho_auth_login,
    rho_auth_refresh = rho_auth_refresh,
    rho_auth_to_request = rho_auth_to_request
  )
)
LoginIO <- s7contract::new_interface(
  "LoginIO",
  generics = list(
    rho_auth_prompt = rho_auth_prompt,
    rho_auth_notify = rho_auth_notify
  )
)
ProviderCapabilityResolver <- s7contract::new_interface(
  "ProviderCapabilityResolver",
  generics = list(
    rho_provider_support = s7contract::interface_requirement(
      rho_provider_support,
      args = list(model = Model, operation = RhoOperation),
      returns = RhoProviderSupport
    )
  )
)
OperationHandler <- s7contract::new_interface(
  "OperationHandler",
  generics = list(
    rho_bind_operation = s7contract::interface_requirement(
      rho_bind_operation,
      args = list(model = Model, operation = RhoOperation, context = Context)
    )
  )
)
OperationPlanner <- s7contract::new_interface(
  "OperationPlanner",
  generics = list(
    rho_plan_operations = s7contract::interface_requirement(
      rho_plan_operations,
      args = list(model = Model, context = Context)
    )
  )
)
OperationExecutor <- s7contract::new_interface(
  "OperationExecutor",
  generics = list(
    rho_execute_operation = s7contract::interface_requirement(
      rho_execute_operation,
      args = list(context = S7::class_any),
      returns = RhoTask
    )
  )
)
ProviderRequestTranslator <- s7contract::new_interface(
  "ProviderRequestTranslator",
  generics = list(
    rho_plan_tools = s7contract::interface_requirement(
      rho_plan_tools,
      args = list(model = Model, context = Context),
      returns = RhoToolPlacement
    ),
    rho_build_provider_request = s7contract::interface_requirement(
      rho_build_provider_request,
      args = list(model = Model, context = Context)
    ),
    rho_provider_headers = s7contract::interface_requirement(
      rho_provider_headers,
      args = list(model = Model, context = Context),
      returns = S7::class_list
    )
  )
)
ProviderInputCompactor <- s7contract::new_interface(
  "ProviderInputCompactor",
  generics = list(
    rho_compact_provider_input = s7contract::interface_requirement(
      rho_compact_provider_input,
      args = list(model = Model, context = Context),
      returns = RhoTask
    )
  )
)
