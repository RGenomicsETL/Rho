ThinkingControl <- S7::new_class("ThinkingControl", abstract = TRUE)

ZaiThinkingControl <- S7::new_class(
  "ZaiThinkingControl",
  parent = ThinkingControl,
  properties = list(preserve_previous = rho_scalar_logical)
)

ToolCallStreamingPolicy <- S7::new_class("ToolCallStreamingPolicy", abstract = TRUE)
BufferedToolCallStreaming <- S7::new_class(
  "BufferedToolCallStreaming",
  parent = ToolCallStreamingPolicy
)
ZaiToolCallStreaming <- S7::new_class(
  "ZaiToolCallStreaming",
  parent = ToolCallStreamingPolicy
)

ZaiChatCompletionsModel <- S7::new_class(
  "ZaiChatCompletionsModel",
  parent = OpenAIChatCompletionsModel,
  properties = list(
    thinking_control = ThinkingControl,
    tool_call_streaming = ToolCallStreamingPolicy
  )
)

ZaiEndpoint <- S7::new_class(
  "ZaiEndpoint",
  abstract = TRUE,
  properties = list(
    provider_id = rho_non_empty_string,
    name = rho_non_empty_string,
    base_url = rho_non_empty_string
  )
)
ZaiCodingEndpoint <- S7::new_class("ZaiCodingEndpoint", parent = ZaiEndpoint)
ZaiGeneralEndpoint <- S7::new_class("ZaiGeneralEndpoint", parent = ZaiEndpoint)

ZaiApi <- S7::new_class(
  "ZaiApi",
  properties = list(endpoint = ZaiEndpoint, http = RhoHttpClient)
)

ZaiApiKeyAuth <- S7::new_class(
  "ZaiApiKeyAuth",
  properties = list(name = rho_non_empty_string, provider_id = rho_non_empty_string)
)

S7::method(
  rho_model_expression,
  list(ZaiModelCatalogProvider, OpenAIChatCompletionsProtocol, ModelCatalogRecord)
) <- function(provider, protocol, record, ...) {
  extra <- substitute(
    list(
      thinking_control = ZaiThinkingControl(preserve_previous = preserve),
      tool_call_streaming = ZaiToolCallStreaming()
    ),
    list(preserve = provider@preserve_thinking)
  )
  rho_catalog_model_call(
    "ZaiChatCompletionsModel",
    record,
    api = "openai-chat-completions",
    extra = extra
  )
}

rho_zai_coding_endpoint <- function() {
  ZaiCodingEndpoint(
    provider_id = "zai",
    name = "Z.ai Coding Plan",
    base_url = "https://api.z.ai/api/coding/paas/v4"
  )
}

rho_zai_china_coding_endpoint <- function() {
  ZaiCodingEndpoint(
    provider_id = "zai-coding-cn",
    name = "Z.ai Coding Plan China",
    base_url = "https://open.bigmodel.cn/api/coding/paas/v4"
  )
}

rho_zai_general_endpoint <- function() {
  ZaiGeneralEndpoint(
    provider_id = "zai-api",
    name = "Z.ai API",
    base_url = "https://api.z.ai/api/paas/v4"
  )
}

rho_apply_thinking_control <- S7::new_generic(
  "rho_apply_thinking_control",
  "control",
  function(control, request, model, options = list(), ...) S7::S7_dispatch()
)

S7::method(rho_apply_thinking_control, ThinkingControl) <- function(
  control,
  request,
  model,
  options = list(),
  ...
) {
  request
}

S7::method(rho_apply_thinking_control, ZaiThinkingControl) <- function(
  control,
  request,
  model,
  options = list(),
  ...
) {
  level <- options$reasoning_effort %||% "max"
  mapped <- rho_map_thinking_level(model, level)
  enabled <- !identical(level, "off") && !mapped %in% c("none", "minimal")
  request$thinking <- list(
    type = if (enabled) "enabled" else "disabled",
    clear_thinking = !control@preserve_previous
  )
  if (enabled) {
    request$reasoning_effort <- mapped
  }
  request
}

rho_apply_tool_call_streaming <- S7::new_generic(
  "rho_apply_tool_call_streaming",
  "policy",
  function(policy, request, has_tools, ...) S7::S7_dispatch()
)

S7::method(rho_apply_tool_call_streaming, BufferedToolCallStreaming) <- function(
  policy,
  request,
  has_tools,
  ...
) {
  request
}

S7::method(rho_apply_tool_call_streaming, ZaiToolCallStreaming) <- function(
  policy,
  request,
  has_tools,
  ...
) {
  if (isTRUE(has_tools)) {
    request$tool_stream <- TRUE
  }
  request
}

rho_openai_chat_message <- S7::new_generic(
  "rho_openai_chat_message",
  "message",
  function(message, ...) S7::S7_dispatch()
)

S7::method(rho_openai_chat_content, TextContent) <- function(content, ...) {
  list(type = "text", text = content@text)
}

S7::method(rho_openai_chat_content, S7::class_character) <- function(content, ...) {
  list(type = "text", text = paste(content, collapse = ""))
}

S7::method(rho_openai_chat_content, ImageContent) <- function(content, ...) {
  list(
    type = "image_url",
    image_url = list(
      url = sprintf("data:%s;base64,%s", content@mime_type, content@data)
    )
  )
}

S7::method(rho_openai_chat_content, Content) <- function(content, ...) {
  rho_provider_error(
    sprintf("OpenAI Chat cannot encode %s content", rho_class_label(content)),
    kind = "input",
    code = "unsupported_content"
  )
}

rho_openai_chat_content_fields <- function(content) {
  if (is.character(content)) {
    return(paste(content, collapse = ""))
  }
  values <- if (S7::S7_inherits(content, Content)) list(content) else content
  parts <- lapply(values, rho_openai_chat_content)
  error <- rho_first_provider_error(parts)
  if (!is.null(error)) {
    return(error)
  }
  if (
    length(values) == 1L &&
      S7::S7_inherits(values[[1L]], TextContent)
  ) {
    return(values[[1L]]@text)
  }
  unname(parts)
}

S7::method(rho_openai_chat_message, UserMessage) <- function(message, ...) {
  content <- rho_openai_chat_content_fields(message@content)
  if (S7::S7_inherits(content, ProviderErrorValue)) {
    return(content)
  }
  list(role = "user", content = content)
}

S7::method(rho_openai_chat_message, AssistantMessage) <- function(message, ...) {
  text <- paste(
    vapply(
      Filter(function(content) S7::S7_inherits(content, TextContent), message@content),
      function(content) content@text,
      character(1)
    ),
    collapse = ""
  )
  thinking <- paste(
    vapply(
      Filter(function(content) S7::S7_inherits(content, ThinkingContent), message@content),
      function(content) content@text,
      character(1)
    ),
    collapse = ""
  )
  calls <- Filter(function(content) S7::S7_inherits(content, ToolCall), message@content)
  value <- list(role = "assistant", content = text)
  if (nzchar(thinking)) {
    value$reasoning_content <- thinking
  }
  if (length(calls)) {
    value$tool_calls <- unname(lapply(calls, function(call) {
      list(
        id = call@id,
        type = "function",
        `function` = list(
          name = call@name,
          arguments = yyjsonr::write_json_str(call@arguments, auto_unbox = TRUE)
        )
      )
    }))
  }
  value
}

S7::method(rho_openai_chat_message, ToolResultMessage) <- function(message, ...) {
  content <- rho_openai_chat_content_fields(message@content)
  if (S7::S7_inherits(content, ProviderErrorValue)) {
    return(content)
  }
  list(
    role = "tool",
    tool_call_id = message@tool_call_id,
    content = content
  )
}

S7::method(rho_openai_chat_message, S7::class_any) <- function(message, ...) {
  rho_provider_error(
    sprintf("OpenAI Chat cannot encode %s messages", rho_class_label(message)),
    kind = "input",
    code = "unsupported_message"
  )
}

rho_openai_chat_messages <- function(context) {
  messages <- lapply(context@messages, rho_openai_chat_message)
  error <- rho_first_provider_error(messages)
  if (!is.null(error)) {
    return(error)
  }
  if (nzchar(context@system_prompt)) {
    messages <- c(list(list(role = "system", content = context@system_prompt)), messages)
  }
  messages
}

rho_openai_chat_tools <- function(tools) {
  unname(lapply(tools, function(tool) {
    list(
      type = "function",
      `function` = list(
        name = tool@name,
        description = tool@description,
        parameters = tool@parameters
      )
    )
  }))
}

rho_openai_chat_core_request_body <- function(model, context, options) {
  input_compatibility <- rho_validate_model_input(model, context)
  if (S7::S7_inherits(input_compatibility, ProviderErrorValue)) {
    return(input_compatibility)
  }
  messages <- rho_openai_chat_messages(context)
  if (S7::S7_inherits(messages, ProviderErrorValue)) {
    return(messages)
  }
  request <- list(
    model = model@id,
    messages = messages,
    stream = TRUE,
    stream_options = list(include_usage = TRUE)
  )
  has_tools <- model@capabilities@tools && length(context@tools) > 0L
  if (has_tools) {
    request$tools <- rho_openai_chat_tools(context@tools)
    request$tool_choice <- "auto"
  }
  if (!is.null(options$max_tokens)) {
    request$max_tokens <- as.integer(options$max_tokens)
  }
  if (!is.null(options$temperature)) {
    request$temperature <- as.double(options$temperature)
  }
  if (!is.null(options$top_p)) {
    request$top_p <- as.double(options$top_p)
  }
  request
}

S7::method(
  rho_openai_chat_request_body,
  list(OpenAIChatCompletionsModel, Context)
) <- function(model, context, options = list(), ...) {
  rho_openai_chat_core_request_body(model, context, options)
}

S7::method(
  rho_openai_chat_request_body,
  list(ZaiChatCompletionsModel, Context)
) <- function(model, context, options = list(), ...) {
  request <- rho_openai_chat_core_request_body(model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(request)
  }
  has_tools <- model@capabilities@tools && length(context@tools) > 0L
  request <- rho_apply_thinking_control(
    model@thinking_control,
    request,
    model,
    options
  )
  rho_apply_tool_call_streaming(model@tool_call_streaming, request, has_tools)
}

rho_zai_request_body <- function(model, context, options = list()) {
  rho_openai_chat_request_body(model, context, options = options)
}

S7::method(rho_auth_login, ZaiApiKeyAuth) <- function(auth, provider_id, io, ...) {
  rho_then(
    rho_auth_prompt(
      io,
      RhoSecretAuthPrompt(
        message = sprintf("Enter the API key for %s:", auth@name),
        placeholder = ""
      )
    ),
    function(key) {
      if (!is.character(key) || length(key) != 1L || !nzchar(key)) {
        return(rho_auth_error("Z.ai API key was not supplied", code = "missing"))
      }
      rho_api_key_credential(auth@provider_id, key, source = "login")
    }
  )
}

S7::method(rho_auth_to_request, ZaiApiKeyAuth) <- function(auth, credential, ...) {
  valid <- S7::S7_inherits(credential, RhoApiKeyCredential) &&
    identical(credential@provider, auth@provider_id) &&
    nzchar(credential@state$key)
  if (!valid) {
    return(rho_task(rho_auth_error(
      "Z.ai request auth requires a matching API-key credential",
      code = "credential_type"
    )))
  }
  rho_task(rho_model_auth(
    api_key = credential@state$key,
    metadata = list(provider = credential@provider, source = credential@source)
  ))
}

S7::method(rho_credential_decode, ZaiApiKeyAuth) <- function(
  auth,
  document,
  provider_id,
  source = "",
  ...
) {
  rho_decode_api_key_credential(document, provider_id, source)
}

rho_zai_catalog_provider <- function(endpoint, catalog) {
  direct <- rho_catalog_records_for(catalog, endpoint@provider_id)
  if (length(direct)) endpoint@provider_id else "zai"
}

rho_zai_compile_model <- function(record, endpoint) {
  provider <- ZaiModelCatalogProvider(
    id = endpoint@provider_id,
    name = endpoint@name,
    base_url = endpoint@base_url,
    preserve_thinking = S7::S7_inherits(endpoint, ZaiCodingEndpoint)
  )
  rho_compile_catalog_model(rho_catalog_record_with_provider(record, provider))
}

rho_zai_model <- function(
  id,
  endpoint = rho_zai_coding_endpoint(),
  catalog = rho_default_model_catalog()
) {
  source_provider <- rho_zai_catalog_provider(endpoint, catalog)
  records <- rho_catalog_records_for(catalog, source_provider, id)
  if (!length(records)) {
    return(rho_catalog_model(catalog, source_provider, id))
  }
  rho_zai_compile_model(records[[1L]], endpoint)
}

rho_zai_provider <- function(
  endpoint = rho_zai_coding_endpoint(),
  http = rho_http_client(timeout_ms = 120000L),
  catalog = rho_default_model_catalog()
) {
  api <- ZaiApi(endpoint = endpoint, http = http)
  source_provider <- rho_zai_catalog_provider(endpoint, catalog)
  models <- lapply(
    rho_catalog_records_for(catalog, source_provider),
    rho_zai_compile_model,
    endpoint = endpoint
  )
  rho_provider(
    id = endpoint@provider_id,
    name = endpoint@name,
    implementation = api,
    auth = rho_provider_auth(
      api_key = ZaiApiKeyAuth(
        name = endpoint@name,
        provider_id = endpoint@provider_id
      )
    ),
    models = models
  )
}

rho_zai_request <- function(provider, model, context, options = list()) {
  rho_build_provider_request(provider, model, context, options = options)
}

S7::method(
  rho_build_provider_request,
  list(ZaiApi, ZaiChatCompletionsModel, Context)
) <- function(provider, model, context, options = list(), ...) {
  auth <- options$auth
  if (!S7::S7_inherits(auth, RhoModelAuth) || !nzchar(auth@api_key)) {
    return(rho_provider_error(
      "Z.ai requests require explicit resolved auth in `options$auth`",
      kind = "auth",
      code = "missing_request_auth"
    ))
  }
  operation_plan <- rho_bound_operation_plan(
    provider,
    model,
    context,
    options
  )
  if (S7::S7_inherits(operation_plan, ProviderErrorValue)) {
    return(operation_plan)
  }
  options$operation_plan <- operation_plan
  body <- rho_zai_request_body(model, context, options)
  if (S7::S7_inherits(body, ProviderErrorValue)) {
    return(body)
  }
  base_url <- if (nzchar(auth@base_url)) auth@base_url else provider@endpoint@base_url
  headers <- utils::modifyList(
    list(
      Authorization = paste("Bearer", auth@api_key),
      Accept = "text/event-stream",
      `Content-Type` = "application/json"
    ),
    rho_provider_headers(provider, model, context, options = options)
  )
  headers <- utils::modifyList(headers, auth@headers)
  rho_http_request(
    method = "POST",
    url = paste0(sub("/+$", "", base_url), "/chat/completions"),
    headers = headers,
    body = body,
    timeout_ms = as.integer(options$timeout_ms %||% 120000L),
    response_headers = c("content-type", "retry-after"),
    convert = TRUE
  )
}

S7::method(
  rho_open_provider_transport,
  list(SseTransport, ZaiApi, ZaiChatCompletionsModel, Context)
) <- function(transport, provider, model, context, options = list(), ...) {
  request <- rho_zai_request(provider, model, context, options)
  if (S7::S7_inherits(request, ProviderErrorValue)) {
    return(rho_provider_error_stream(model, request))
  }
  stream <- rho_sse_connect(provider@http, request)
  decoder <- rho_openai_chat_decoder(model)
  rho_stream_flat_map(
    stream,
    function(event) rho_decode_provider_event(decoder, event)
  )
}
