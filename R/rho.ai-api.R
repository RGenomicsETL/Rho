#' Message content and tool contracts
#'
#' Messages contain typed content objects rather than discriminator strings.
#' Tool execution is asynchronous, and overlap is represented by an S7 value
#' that the agent can dispatch on.
#'
#' @name rho_ai_messages
#' @aliases Content TextContent ThinkingContent ImageContent ArtifactRefContent ToolCall
#' @aliases UserMessage AssistantMessage ToolResultMessage RhoContextRevision ToolOverlap
#' @aliases ToolMayOverlap ToolRequiresExclusiveExecution ToolSpec ToolResult
#' @aliases ToolErrorResult Tool ProviderInputLimitError
#' @aliases ProviderContextOverflowError ProviderRequestTooLargeError
#' @aliases rho_text rho_thinking rho_user_message
#' @aliases rho_assistant_message rho_tool_result_message rho_tool_spec
#' @aliases rho_tool_result rho_tool_error_result rho_validate_tool_args
#' @aliases rho_execute_tool rho_tool_overlap rho_context_signature
#' @aliases rho_context_revision
#' @export Content
#' @export TextContent
#' @export ThinkingContent
#' @export ImageContent
#' @export ArtifactRefContent
#' @export ToolCall
#' @export UserMessage
#' @export AssistantMessage
#' @export ToolResultMessage
#' @export RhoContextRevision
#' @export ToolOverlap
#' @export ToolMayOverlap
#' @export ToolRequiresExclusiveExecution
#' @export ToolSpec
#' @export ToolResult
#' @export ToolErrorResult
#' @export ProviderInputLimitError
#' @export ProviderContextOverflowError
#' @export ProviderRequestTooLargeError
#' @export Tool
#' @export rho_text
#' @export rho_thinking
#' @export rho_user_message
#' @export rho_assistant_message
#' @export rho_tool_result_message
#' @export rho_tool_spec
#' @export rho_tool_result
#' @export rho_tool_error_result
#' @export rho_validate_tool_args
#' @export rho_execute_tool
#' @export rho_tool_overlap
#' @export rho_context_signature
#' @export rho_context_revision
NULL

#' Semantic operations, handlers, and provider activity
#'
#' A `RhoOperation` states what a conversation may do. A handler binds that
#' semantic request to a concrete implementation for the selected model.
#' Bindings record both the handler and the reason it was selected; request
#' translators turn bindings into provider wire values while encoding a request.
#'
#' Provider-hosted activity is normalized as `Content`, never as a local
#' `ToolCall`. The agent can therefore retain and report a web search without
#' placing it in its executable tool registry.
#'
#' @name rho_ai_operations
#' @aliases RhoOperation RhoWebSearchOperation RhoWebSearchDomainPolicy
#' @aliases RhoCompactionOperation RhoNativeCompactionOperation
#' @aliases RhoProviderCompactionBinding
#' @aliases RhoWebSearchAllDomains RhoWebSearchAllowedDomains
#' @aliases RhoWebSearchBlockedDomains RhoWebSearchLocation
#' @aliases RhoWebSearchLocationUnspecified RhoApproximateLocation
#' @aliases RhoWebSearchCapability RhoWebSearchUnavailable
#' @aliases RhoOperationBinding RhoProviderToolBinding RhoOperationPlan
#' @aliases OperationHandler OperationPlanner OperationExecutor
#' @aliases OperationUnsupported
#' @aliases OperationStatus OperationPending OperationInProgress
#' @aliases OperationCompleted OperationFailed WebSearchAction
#' @aliases WebSearchActionUnspecified WebSearchSearchAction
#' @aliases WebSearchOpenPageAction WebSearchFindInPageAction
#' @aliases WebSearchUnknownAction WebSearchResult WebSearchCallContent
#' @aliases WebSearchResultContent AssistantOperationStartEvent
#' @aliases AssistantOperationEndEvent rho_web_search
#' @aliases rho_web_search_allowed_domains rho_web_search_blocked_domains
#' @aliases rho_approximate_location rho_operation_plan
#' @aliases rho_bind_operation rho_bind_web_search rho_plan_operations
#' @aliases rho_execute_operation
#' @aliases rho_operation_unsupported
#' @export RhoOperation
#' @export RhoWebSearchOperation
#' @export RhoCompactionOperation
#' @export RhoNativeCompactionOperation
#' @export RhoProviderCompactionBinding
#' @export RhoWebSearchDomainPolicy
#' @export RhoWebSearchAllDomains
#' @export RhoWebSearchAllowedDomains
#' @export RhoWebSearchBlockedDomains
#' @export RhoWebSearchLocation
#' @export RhoWebSearchLocationUnspecified
#' @export RhoApproximateLocation
#' @export RhoWebSearchCapability
#' @export RhoWebSearchUnavailable
#' @export RhoOperationBinding
#' @export RhoProviderToolBinding
#' @export RhoOperationPlan
#' @export OperationHandler
#' @export OperationPlanner
#' @export OperationExecutor
#' @export OperationUnsupported
#' @export OperationStatus
#' @export OperationPending
#' @export OperationInProgress
#' @export OperationCompleted
#' @export OperationFailed
#' @export WebSearchAction
#' @export WebSearchActionUnspecified
#' @export WebSearchSearchAction
#' @export WebSearchOpenPageAction
#' @export WebSearchFindInPageAction
#' @export WebSearchUnknownAction
#' @export WebSearchResult
#' @export WebSearchCallContent
#' @export WebSearchResultContent
#' @export AssistantOperationStartEvent
#' @export AssistantOperationEndEvent
#' @export rho_web_search
#' @export rho_web_search_allowed_domains
#' @export rho_web_search_blocked_domains
#' @export rho_approximate_location
#' @export rho_operation_plan
#' @export rho_bind_operation
#' @export rho_bind_web_search
#' @export rho_plan_operations
#' @export rho_execute_operation
#' @export rho_operation_unsupported
NULL

#' Usage observations and nominal pricing
#'
#' `ProviderUsage` records token and cache counts supplied by a provider.
#' `EstimatedUsage` records an explicitly named estimator and method.
#' `UsageUnavailable` records that a provider did not supply counts; it has no
#' fabricated token counts or cost. Usage components are disjoint: `input`
#' excludes cache reads and writes, while `output` includes any reported
#' reasoning tokens. `reasoning` is an optional breakdown of `output`; it is
#' never added to `total` a second time. The optional `cache_write_1h` value is
#' a subset of `cache_write`.
#'
#' `rho_price_usage()` is the open pricing protocol. Its default `Model`
#' method selects the highest matching long-context tier, prices every
#' component, and returns a new counted usage value with a
#' `NominalUsageCost`. It does not claim to report a subscription charge. Model
#' subclasses may provide methods for provider-specific pricing rules.
#'
#' [rho_summarize_usage()] preserves every typed observation and reports
#' disjoint token totals, nominal cost, and the latest cache-hit proportion.
#' `complete` is false when any turn has `UsageUnavailable`; `cost_complete` is
#' false when a counted turn has no nominal price. Zeroes therefore never hide
#' missing provider data.
#'
#' @name rho_ai_usage
#' @aliases UsageObservation
#' @aliases Usage
#' @aliases ProviderUsage
#' @aliases EstimatedUsage
#' @aliases UsageUnavailable
#' @aliases UsageSummary
#' @aliases UsageCost
#' @aliases NominalUsageCost
#' @aliases rho_provider_usage
#' @aliases rho_estimated_usage
#' @aliases rho_usage_unavailable
#' @aliases rho_nominal_usage_cost
#' @aliases rho_price_usage
#' @aliases rho_usage_observations rho_summarize_usage
#' @export UsageObservation
#' @export Usage
#' @export ProviderUsage
#' @export EstimatedUsage
#' @export UsageUnavailable
#' @export UsageSummary
#' @export UsageCost
#' @export NominalUsageCost
#' @export rho_provider_usage
#' @export rho_estimated_usage
#' @export rho_usage_unavailable
#' @export rho_nominal_usage_cost
#' @export rho_price_usage
#' @export rho_usage_observations
#' @export rho_summarize_usage
NULL

#' Typed OpenAI Responses request composition
#'
#' OpenAI request bodies are reductions over typed sections. Model-specific
#' methods select the sections and their defaults; section methods alone emit
#' wire field names and provider values. Extensions can specialize
#' `rho_openai_request_sections()` for a model subclass or append a new
#' `OpenAIRequestSection` with a `rho_request_fields()` method.
#'
#' Canonical thinking requests are values. `ThinkingOff` therefore dispatches
#' separately from enabled levels without comparing provider wire strings.
#'
#' @name rho_openai_request_policy
#' @aliases ThinkingRequest ThinkingUnspecified ThinkingLevel ThinkingOff
#' @aliases ThinkingEnabled rho_thinking_level OpenAIRequestSection
#' @aliases ProviderRequestSection OpenAIOmittedRequestSection
#' @aliases ProviderRequestSectionProtocol
#' @aliases rho_openai_request_sections
#' @aliases rho_request_fields rho_openai_reasoning_section
#' @aliases rho_openai_input_content
#' @aliases rho_openai_standard_request_sections
#' @export ThinkingRequest
#' @export ThinkingUnspecified
#' @export ThinkingLevel
#' @export ThinkingOff
#' @export ThinkingEnabled
#' @export rho_thinking_level
#' @export OpenAIRequestSection
#' @export ProviderRequestSection
#' @export OpenAIOmittedRequestSection
#' @export ProviderRequestSectionProtocol
#' @export rho_openai_request_sections
#' @export rho_request_fields
#' @export rho_openai_input_content
#' @export rho_openai_reasoning_section
#' @export rho_openai_standard_request_sections
NULL

#' Anthropic Messages dialect
#'
#' Anthropic request construction is a reduction over typed request sections.
#' Model catalog facts select thinking, temperature, cache, and tool-input
#' capabilities; request methods never infer behavior from model names.
#'
#' `AnthropicMessagesEndpoint` separates the Messages dialect from endpoint
#' authentication and transport. Anthropic and GitHub Copilot therefore share
#' message translation and event reduction while retaining their own endpoint
#' headers, URLs, and credentials.
#'
#' Stream JSON is decoded once into typed wire events. S7 methods translate
#' blocks, deltas, and stop reasons into the provider-neutral `AssistantEvent`
#' protocol.
#'
#' @name rho_anthropic_messages
#' @aliases AnthropicApi AnthropicApiKeyAuth AnthropicMessagesEndpoint
#' @aliases AnthropicOAuthCredential AnthropicOAuthModelAuth AnthropicOAuthAuth
#' @aliases AnthropicThinkingCapability AnthropicNoThinkingCapability
#' @aliases AnthropicBudgetThinkingCapability AnthropicAdaptiveThinkingCapability
#' @aliases AnthropicTemperatureCapability AnthropicTemperatureAccepted
#' @aliases AnthropicTemperatureOmitted AnthropicCacheCapability
#' @aliases AnthropicToolInputCapability AnthropicEagerToolInput
#' @aliases AnthropicFineGrainedToolInput AnthropicMessagesCompatibility
#' @aliases AnthropicCacheRetention AnthropicNoCache AnthropicShortCache
#' @aliases AnthropicLongCache AnthropicThinkingDisplay
#' @aliases AnthropicSummarizedThinking AnthropicOmittedThinking
#' @aliases AnthropicToolChoice AnthropicToolChoiceUnspecified
#' @aliases AnthropicToolChoiceAuto AnthropicToolChoiceAny
#' @aliases AnthropicToolChoiceNone AnthropicToolChoiceNamed
#' @aliases AnthropicToolNamePolicy AnthropicExactToolNames
#' @aliases AnthropicClaudeCodeToolNames
#' @aliases AnthropicWebSearchProtocol AnthropicWebSearch20250305
#' @aliases AnthropicWebSearch20260209 AnthropicWebSearch20260318
#' @aliases AnthropicWebSearchBinding
#' @aliases AnthropicRequestSection AnthropicMessagesDecoder AnthropicWireEvent
#' @aliases rho_anthropic_model rho_anthropic_provider
#' @aliases rho_anthropic_oauth_auth rho_anthropic_oauth_credential
#' @aliases rho_load_anthropic_credential
#' @aliases rho_anthropic_messages_request rho_anthropic_messages_url
#' @aliases rho_anthropic_no_cache rho_anthropic_short_cache
#' @aliases rho_anthropic_long_cache rho_anthropic_temperature
#' @aliases rho_anthropic_tool_choice rho_anthropic_thinking_display
#' @aliases rho_anthropic_exact_tool_names rho_anthropic_claude_code_tool_names
#' @aliases rho_anthropic_tool_name rho_anthropic_local_tool_name
#' @aliases rho_anthropic_tool_name_policy
#' @aliases rho_anthropic_content_blocks rho_anthropic_message
#' @aliases rho_anthropic_request_sections rho_anthropic_messages_body
#' @aliases rho_anthropic_cache_control rho_anthropic_thinking_section
#' @aliases rho_anthropic_temperature_section rho_anthropic_tool_fields
#' @aliases rho_anthropic_beta_name rho_anthropic_endpoint_url
#' @aliases rho_anthropic_endpoint_headers rho_anthropic_endpoint_http
#' @aliases rho_anthropic_auth_headers rho_anthropic_system_identity
#' @aliases rho_anthropic_messages_decoder rho_start_anthropic_block
#' @aliases rho_apply_anthropic_delta rho_finish_anthropic_block
#' @aliases rho_anthropic_stop_reason_value rho_anthropic_stop_reason_error
#' @export AnthropicApi
#' @export AnthropicApiKeyAuth
#' @export AnthropicOAuthCredential
#' @export AnthropicOAuthModelAuth
#' @export AnthropicOAuthAuth
#' @export AnthropicMessagesEndpoint
#' @export AnthropicThinkingCapability
#' @export AnthropicNoThinkingCapability
#' @export AnthropicBudgetThinkingCapability
#' @export AnthropicAdaptiveThinkingCapability
#' @export AnthropicTemperatureCapability
#' @export AnthropicTemperatureAccepted
#' @export AnthropicTemperatureOmitted
#' @export AnthropicCacheCapability
#' @export AnthropicToolInputCapability
#' @export AnthropicEagerToolInput
#' @export AnthropicFineGrainedToolInput
#' @export AnthropicMessagesCompatibility
#' @export AnthropicCacheRetention
#' @export AnthropicNoCache
#' @export AnthropicShortCache
#' @export AnthropicLongCache
#' @export AnthropicThinkingDisplay
#' @export AnthropicSummarizedThinking
#' @export AnthropicOmittedThinking
#' @export AnthropicToolChoice
#' @export AnthropicToolChoiceUnspecified
#' @export AnthropicToolChoiceAuto
#' @export AnthropicToolChoiceAny
#' @export AnthropicToolChoiceNone
#' @export AnthropicToolChoiceNamed
#' @export AnthropicToolNamePolicy
#' @export AnthropicExactToolNames
#' @export AnthropicClaudeCodeToolNames
#' @export AnthropicWebSearchProtocol
#' @export AnthropicWebSearch20250305
#' @export AnthropicWebSearch20260209
#' @export AnthropicWebSearch20260318
#' @export AnthropicWebSearchBinding
#' @export AnthropicRequestSection
#' @export AnthropicMessagesDecoder
#' @export AnthropicWireEvent
#' @export rho_anthropic_model
#' @export rho_anthropic_provider
#' @export rho_anthropic_oauth_auth
#' @export rho_anthropic_oauth_credential
#' @export rho_load_anthropic_credential
#' @export rho_anthropic_messages_request
#' @export rho_anthropic_messages_url
#' @export rho_anthropic_no_cache
#' @export rho_anthropic_short_cache
#' @export rho_anthropic_long_cache
#' @export rho_anthropic_temperature
#' @export rho_anthropic_tool_choice
#' @export rho_anthropic_thinking_display
#' @export rho_anthropic_exact_tool_names
#' @export rho_anthropic_claude_code_tool_names
#' @export rho_anthropic_tool_name
#' @export rho_anthropic_local_tool_name
#' @export rho_anthropic_tool_name_policy
#' @export rho_anthropic_content_blocks
#' @export rho_anthropic_message
#' @export rho_anthropic_request_sections
#' @export rho_anthropic_messages_body
#' @export rho_anthropic_cache_control
#' @export rho_anthropic_thinking_section
#' @export rho_anthropic_temperature_section
#' @export rho_anthropic_tool_fields
#' @export rho_anthropic_beta_name
#' @export rho_anthropic_endpoint_url
#' @export rho_anthropic_endpoint_headers
#' @export rho_anthropic_endpoint_http
#' @export rho_anthropic_auth_headers
#' @export rho_anthropic_system_identity
#' @export rho_anthropic_messages_decoder
#' @export rho_start_anthropic_block
#' @export rho_apply_anthropic_delta
#' @export rho_finish_anthropic_block
#' @export rho_anthropic_stop_reason_value
#' @export rho_anthropic_stop_reason_error
NULL

#' OpenAI-compatible Chat Completions stream protocol
#'
#' Chat Completions chunks are parsed into typed wire values and reduced by S7
#' methods to the normalized `AssistantEvent` protocol.
#'
#' @name rho_openai_chat_wire
#' @aliases OpenAIChatCompletionsDecoder OpenAIChatWireEvent OpenAIChatIgnored
#' @aliases OpenAIChatThinkingDelta OpenAIChatTextDelta OpenAIChatToolDelta
#' @aliases OpenAIChatFinishSignal OpenAIChatUsageUpdate OpenAIChatDone
#' @aliases OpenAIChatError rho_openai_chat_decoder rho_openai_chat_message
#' @aliases rho_openai_chat_content
#' @export OpenAIChatCompletionsDecoder
#' @export OpenAIChatWireEvent
#' @export OpenAIChatIgnored
#' @export OpenAIChatThinkingDelta
#' @export OpenAIChatTextDelta
#' @export OpenAIChatToolDelta
#' @export OpenAIChatFinishSignal
#' @export OpenAIChatUsageUpdate
#' @export OpenAIChatDone
#' @export OpenAIChatError
#' @export rho_openai_chat_decoder
#' @export rho_openai_chat_message
#' @export rho_openai_chat_content
NULL

#' Z.ai provider
#'
#' Z.ai uses the OpenAI-compatible Chat Completions protocol with explicit
#' thinking preservation and tool-call streaming policies.
#'
#' @name rho_zai
#' @aliases ThinkingControl ZaiThinkingControl ToolCallStreamingPolicy
#' @aliases BufferedToolCallStreaming ZaiToolCallStreaming
#' @aliases ZaiChatCompletionsModel ZaiEndpoint ZaiCodingEndpoint
#' @aliases ZaiGeneralEndpoint ZaiApi ZaiApiKeyAuth
#' @aliases rho_zai_coding_endpoint rho_zai_china_coding_endpoint
#' @aliases rho_zai_general_endpoint rho_zai_model rho_zai_provider
#' @aliases rho_zai_request rho_apply_thinking_control
#' @aliases rho_apply_tool_call_streaming
#' @export ThinkingControl
#' @export ZaiThinkingControl
#' @export ToolCallStreamingPolicy
#' @export BufferedToolCallStreaming
#' @export ZaiToolCallStreaming
#' @export ZaiChatCompletionsModel
#' @export ZaiEndpoint
#' @export ZaiCodingEndpoint
#' @export ZaiGeneralEndpoint
#' @export ZaiApi
#' @export ZaiApiKeyAuth
#' @export rho_zai_coding_endpoint
#' @export rho_zai_china_coding_endpoint
#' @export rho_zai_general_endpoint
#' @export rho_zai_model
#' @export rho_zai_provider
#' @export rho_zai_request
#' @export rho_apply_thinking_control
#' @export rho_apply_tool_call_streaming
NULL

#' Kimi Platform provider
#'
#' Kimi Platform uses its own Chat Completions dialect. Its typed request
#' methods preserve Kimi thinking controls, use `max_completion_tokens`, and
#' accept explicit image content. The global and China endpoints remain
#' separate providers because their credentials and model catalogs are scoped
#' independently.
#'
#' @name rho_kimi_platform
#' @aliases KimiPlatformEndpoint KimiPlatformGlobalEndpoint
#' @aliases KimiPlatformChinaEndpoint KimiPlatformApi KimiPlatformApiKeyAuth
#' @aliases KimiPlatformChatCompletionsModel KimiPlatformThinkingRequest
#' @aliases KimiPlatformThinkingUnspecified KimiPlatformThinkingDisabled
#' @aliases KimiPlatformThinkingEnabled KimiPlatformThinkingEffort
#' @aliases rho_kimi_platform_global_endpoint rho_kimi_platform_china_endpoint
#' @aliases rho_kimi_platform_model rho_kimi_platform_provider
#' @aliases rho_kimi_platform_thinking rho_kimi_platform_request
#' @export KimiPlatformEndpoint
#' @export KimiPlatformGlobalEndpoint
#' @export KimiPlatformChinaEndpoint
#' @export KimiPlatformApi
#' @export KimiPlatformApiKeyAuth
#' @export KimiPlatformChatCompletionsModel
#' @export KimiPlatformThinkingRequest
#' @export KimiPlatformThinkingUnspecified
#' @export KimiPlatformThinkingDisabled
#' @export KimiPlatformThinkingEnabled
#' @export KimiPlatformThinkingEffort
#' @export rho_kimi_platform_global_endpoint
#' @export rho_kimi_platform_china_endpoint
#' @export rho_kimi_platform_model
#' @export rho_kimi_platform_provider
#' @export rho_kimi_platform_thinking
#' @export rho_kimi_platform_request
NULL

#' Normalized assistant and provider event protocols
#'
#' Providers emit the typed `AssistantEvent` hierarchy. Provider-specific wire
#' events are decoded and reduced through separate S7 generics, keeping wire
#' formats out of the agent loop.
#'
#' @name rho_ai_events
#' @aliases AssistantEvent AssistantPartialEvent AssistantStartEvent
#' @aliases AssistantUpdateEvent AssistantTextStartEvent AssistantTextDeltaEvent
#' @aliases AssistantTextEndEvent AssistantThinkingStartEvent
#' @aliases AssistantThinkingDeltaEvent AssistantThinkingEndEvent
#' @aliases AssistantToolCallStartEvent AssistantToolCallDeltaEvent
#' @aliases AssistantToolCallEndEvent AssistantTerminalEvent AssistantDoneEvent
#' @aliases AssistantErrorEvent ProviderEventDecoder ProviderWireEvent
#' @aliases ResponseItemProtocol rho_assistant_start_event
#' @aliases rho_assistant_text_start_event rho_assistant_text_delta_event
#' @aliases rho_assistant_text_end_event rho_assistant_thinking_start_event
#' @aliases rho_assistant_thinking_delta_event rho_assistant_thinking_end_event
#' @aliases rho_assistant_tool_call_start_event
#' @aliases rho_assistant_tool_call_delta_event rho_assistant_tool_call_end_event
#' @aliases rho_assistant_done_event rho_assistant_error_event
#' @aliases rho_assistant_event_type rho_decode_provider_event
#' @aliases rho_reduce_provider_event rho_start_response_item
#' @aliases rho_finish_response_item
#' @export AssistantEvent
#' @export AssistantPartialEvent
#' @export AssistantStartEvent
#' @export AssistantUpdateEvent
#' @export AssistantTextStartEvent
#' @export AssistantTextDeltaEvent
#' @export AssistantTextEndEvent
#' @export AssistantThinkingStartEvent
#' @export AssistantThinkingDeltaEvent
#' @export AssistantThinkingEndEvent
#' @export AssistantToolCallStartEvent
#' @export AssistantToolCallDeltaEvent
#' @export AssistantToolCallEndEvent
#' @export AssistantTerminalEvent
#' @export AssistantDoneEvent
#' @export AssistantErrorEvent
#' @export ProviderEventDecoder
#' @export ProviderWireEvent
#' @export ResponseItemProtocol
#' @export rho_assistant_start_event
#' @export rho_assistant_text_start_event
#' @export rho_assistant_text_delta_event
#' @export rho_assistant_text_end_event
#' @export rho_assistant_thinking_start_event
#' @export rho_assistant_thinking_delta_event
#' @export rho_assistant_thinking_end_event
#' @export rho_assistant_tool_call_start_event
#' @export rho_assistant_tool_call_delta_event
#' @export rho_assistant_tool_call_end_event
#' @export rho_assistant_done_event
#' @export rho_assistant_error_event
#' @export rho_assistant_event_type
#' @export rho_decode_provider_event
#' @export rho_reduce_provider_event
#' @export rho_start_response_item
#' @export rho_finish_response_item
NULL

#' Runtime-compiled model catalog
#'
#' The catalog stores model facts as package data. `rho_model_expression()`
#' turns a typed provider profile, protocol, and record into an inspectable R
#' call. `rho_compile_catalog_model()` evaluates that call to produce the S7
#' model value used by provider dispatch. Extensions may add provider profiles,
#' protocols, and expression methods without rewriting the catalog reader.
#'
#' Catalog refresh is an explicit development operation. Package installation
#' and ordinary runtime use never contact a catalog service.
#'
#' @name rho_model_catalog
#' @aliases ModelProtocol OpenAIResponsesProtocol OpenAIChatCompletionsProtocol
#' @aliases AnthropicMessagesProtocol ModelCatalogProvider
#' @aliases OpenAIModelCatalogProvider OpenAICodexModelCatalogProvider
#' @aliases GitHubCopilotModelCatalogProvider AnthropicModelCatalogProvider
#' @aliases KimiCodeModelCatalogProvider KimiPlatformModelCatalogProvider
#' @aliases ZaiModelCatalogProvider
#' @aliases ModelCatalogSource ModelCatalogRecord
#' @aliases ModelCatalog ModelCatalogModelNotFound rho_model_expression
#' @aliases rho_compile_catalog_model rho_default_model_catalog
#' @aliases rho_catalog_models rho_catalog_model rho_catalog_bindings
#' @aliases rho_default_model_bindings
#' @export ModelProtocol
#' @export OpenAIResponsesProtocol
#' @export OpenAIChatCompletionsProtocol
#' @export AnthropicMessagesProtocol
#' @export ModelCatalogProvider
#' @export OpenAIModelCatalogProvider
#' @export OpenAICodexModelCatalogProvider
#' @export GitHubCopilotModelCatalogProvider
#' @export AnthropicModelCatalogProvider
#' @export KimiCodeModelCatalogProvider
#' @export KimiPlatformModelCatalogProvider
#' @export ZaiModelCatalogProvider
#' @export ModelCatalogSource
#' @export ModelCatalogRecord
#' @export ModelCatalog
#' @export ModelCatalogModelNotFound
#' @export rho_model_expression
#' @export rho_compile_catalog_model
#' @export rho_default_model_catalog
#' @export rho_catalog_models
#' @export rho_catalog_model
#' @export rho_catalog_bindings
#' @export rho_default_model_bindings
NULL

#' Models, providers, and capability operations
#'
#' Shared model facts live in typed capability, limits, and pricing objects.
#' Provider-specific behavior is queried with typed operation values and S7
#' dispatch, avoiding a lowest-common-denominator boolean map.
#'
#' Provider turns are independent of byte transport. [rho_stream()] always
#' returns normalized assistant events whether an implementation uses SSE,
#' WebSocket, an embedded model, or a remote evaluator. `ProviderTransport`
#' values describe executable strategies. `AutomaticTransport` is a selection
#' policy rather than a model capability. [rho_select_provider_transport()]
#' records the selected strategy and reason; [rho_open_provider_transport()]
#' is the provider-open execution point.
#'
#' @name rho_ai_providers
#' @aliases Context Model OpenAIResponsesModel OpenAICodexResponsesModel
#' @aliases GitHubCopilotResponsesModel OpenAIChatCompletionsModel
#' @aliases AnthropicMessagesModel ModelCapabilities ModelLimits ModelPricingTier
#' @aliases ModelPricing Provider ProviderCapabilityResolver
#' @aliases ProviderRequestTranslator ProviderInputCompactor ProviderErrorValue
#' @aliases ProviderInputUnsupported ModelInputAccepted
#' @aliases ProviderTransportUnsupported ProviderTransportSelection
#' @aliases ProviderTransport SseTransport WebSocketTransport
#' @aliases CachedWebSocketTransport EmbeddedTransport AutomaticTransport
#' @aliases RhoEmbeddedExecutor RhoFunctionEmbeddedExecutor RhoEmbeddedProvider
#' @aliases EmbeddedExecutor rho_embedded_executor rho_embedded_provider
#' @aliases rho_embedded_stream
#' @aliases ProviderOperationUnsupported RhoProviderOperation
#' @aliases RhoToolSearchOperation RhoToolReferencesOperation
#' @aliases RhoCacheRetentionOperation
#' @aliases RhoProviderSupport OpenAIResponsesCompatibility
#' @aliases RhoToolPlacement RhoFullToolPlacement
#' @aliases RhoOpenAIToolSearchPlacement RhoAnthropicToolReferencePlacement
#' @aliases FauxProvider OpenAIApi OpenAIApiKeyAuth OllamaProvider
#' @aliases rho_context rho_model_capabilities rho_model_limits
#' @aliases rho_model_pricing_tier rho_model_pricing rho_model
#' @aliases rho_thinking_levels rho_supported_thinking_levels
#' @aliases rho_clamp_thinking_level rho_map_thinking_level
#' @aliases rho_model_supports_input rho_model_supports_transport
#' @aliases rho_transport_id rho_provider_transports
#' @aliases rho_select_provider_transport rho_open_provider_transport
#' @aliases rho_content_modalities rho_content_text rho_validate_model_input
#' @aliases rho_stream rho_complete rho_provider_error rho_provider_http_error
#' @aliases rho_provider_input_unsupported
#' @aliases rho_provider_context_overflow rho_provider_request_too_large
#' @aliases rho_unsupported_provider_operation rho_provider_support_value
#' @aliases rho_provider_support rho_provider_dialect rho_plan_tools
#' @aliases rho_build_provider_request rho_openai_chat_request_body
#' @aliases rho_openai_responses_body
#' @aliases rho_provider_headers
#' @aliases rho_compact_provider_input rho_openai_responses_compatibility
#' @aliases rho_anthropic_messages_compatibility rho_faux_provider
#' @aliases rho_faux_content_events rho_faux_message_events
#' @aliases rho_openai_model rho_openai_provider rho_openai_request
#' @aliases rho_openai_responses_url
#' @aliases rho_ollama_provider rho_ollama_model rho_ollama_chat_request
#' @aliases rho_ollama_chat_task
#' @export Context
#' @export Model
#' @export OpenAIResponsesModel
#' @export OpenAICodexResponsesModel
#' @export GitHubCopilotResponsesModel
#' @export OpenAIChatCompletionsModel
#' @export AnthropicMessagesModel
#' @export ModelCapabilities
#' @export ModelLimits
#' @export ModelPricingTier
#' @export ModelPricing
#' @export Provider
#' @export ProviderCapabilityResolver
#' @export ProviderRequestTranslator
#' @export ProviderInputCompactor
#' @export ProviderErrorValue
#' @export ProviderInputUnsupported
#' @export ModelInputAccepted
#' @export ProviderTransportUnsupported
#' @export ProviderTransportSelection
#' @export ProviderTransport
#' @export SseTransport
#' @export WebSocketTransport
#' @export CachedWebSocketTransport
#' @export EmbeddedTransport
#' @export AutomaticTransport
#' @export RhoEmbeddedExecutor
#' @export RhoFunctionEmbeddedExecutor
#' @export RhoEmbeddedProvider
#' @export EmbeddedExecutor
#' @export ProviderOperationUnsupported
#' @export RhoProviderOperation
#' @export RhoToolSearchOperation
#' @export RhoToolReferencesOperation
#' @export RhoCacheRetentionOperation
#' @export RhoProviderSupport
#' @export OpenAIResponsesCompatibility
#' @export RhoToolPlacement
#' @export RhoFullToolPlacement
#' @export RhoOpenAIToolSearchPlacement
#' @export RhoAnthropicToolReferencePlacement
#' @export FauxProvider
#' @export OpenAIApi
#' @export OpenAIApiKeyAuth
#' @export OllamaProvider
#' @export rho_context
#' @export rho_model_capabilities
#' @export rho_model_limits
#' @export rho_model_pricing_tier
#' @export rho_model_pricing
#' @export rho_model
#' @export rho_thinking_levels
#' @export rho_supported_thinking_levels
#' @export rho_clamp_thinking_level
#' @export rho_map_thinking_level
#' @export rho_model_supports_input
#' @export rho_content_modalities
#' @export rho_content_text
#' @export rho_validate_model_input
#' @export rho_model_supports_transport
#' @export rho_transport_id
#' @export rho_provider_transports
#' @export rho_select_provider_transport
#' @export rho_open_provider_transport
#' @export rho_embedded_executor
#' @export rho_embedded_provider
#' @export rho_embedded_stream
#' @export rho_stream
#' @export rho_complete
#' @export rho_provider_error
#' @export rho_provider_input_unsupported
#' @export rho_provider_context_overflow
#' @export rho_provider_request_too_large
#' @export rho_provider_http_error
#' @export rho_unsupported_provider_operation
#' @export rho_provider_support_value
#' @export rho_provider_support
#' @export rho_provider_dialect
#' @export rho_plan_tools
#' @export rho_build_provider_request
#' @export rho_openai_chat_request_body
#' @export rho_openai_responses_body
#' @export rho_provider_headers
#' @export rho_compact_provider_input
#' @export rho_openai_responses_compatibility
#' @export rho_anthropic_messages_compatibility
#' @export rho_faux_provider
#' @export rho_faux_content_events
#' @export rho_faux_message_events
#' @export rho_openai_model
#' @export rho_openai_provider
#' @export rho_openai_request
#' @export rho_openai_responses_url
#' @export rho_ollama_provider
#' @export rho_ollama_model
#' @export rho_ollama_chat_request
#' @export rho_ollama_chat_task
NULL

#' Explicit credentials, login effects, and provider catalog state
#'
#' Credentials are owned by a `CredentialStore`; login interaction is owned by
#' a `LoginIO`. Reads, refreshes, writes, prompts, and notifications are explicit
#' async operations. `RhoModels` owns provider selection and serialized refresh
#' gates instead of relying on process-global auth state.
#'
#' `rho_memory_credential_store()` keeps credentials for one R process.
#' `rho_file_credential_store()` persists them as a versioned JSON document at
#' an explicitly supplied path. `rho_encrypted_file_credential_store()` encrypts
#' that document with an explicitly supplied passphrase or 32-byte key using
#' Argon2id and XChaCha20-Poly1305. `rho_keychain_credential_store()` keeps each
#' provider credential in the operating system's native keychain and rejects
#' keyring's environment and file backends. File updates are serialized, replace
#' the prior document, and use owner-only permissions where the platform supports
#' them. `rho_user_credential_path()` returns R's platform-specific user
#' configuration path without creating it.
#'
#' @name rho_ai_auth
#' @aliases CredentialStore OAuthAuth LoginIO RhoCredential RhoApiKeyCredential
#' @aliases RhoOAuthCredential RhoModelAuth RhoAuthResolution RhoApiKeyAuth
#' @aliases RhoOAuthAuth RhoFunctionOAuthAuth RhoProviderAuth RhoCredentialGate
#' @aliases RhoLoginMethod RhoApiKeyLogin RhoOAuthLogin rho_login_strategy
#' @aliases RhoMemoryCredentialStore RhoFileCredentialStore
#' @aliases RhoEncryptedFileCredentialStore RhoKeychainCredentialStore
#' @aliases RhoCredentialEncryptionSecret RhoCredentialPassphrase
#' @aliases RhoCredentialEncryptionKey
#' @aliases RhoAuthPrompt RhoTextAuthPrompt
#' @aliases RhoSecretAuthPrompt RhoManualCodeAuthPrompt RhoSelectAuthPrompt
#' @aliases RhoAuthEvent RhoAuthUrlEvent RhoDeviceCodeEvent RhoAuthProgressEvent
#' @aliases RhoFunctionLoginIO RhoProvider RhoModels AuthErrorValue
#' @aliases rho_api_key_credential rho_model_auth rho_api_key_auth rho_oauth_auth
#' @aliases rho_provider_auth rho_credential_gate rho_memory_credential_store
#' @aliases rho_file_credential_store rho_encrypted_file_credential_store
#' @aliases rho_keychain_credential_store rho_credential_passphrase
#' @aliases rho_credential_encryption_key rho_user_credential_path
#' @aliases rho_login_io rho_provider rho_models rho_models_provider
#' @aliases rho_provider_models rho_available_models
#' @aliases rho_login_provider rho_resolve_model_auth rho_credential_read
#' @aliases rho_credential_modify rho_credential_delete rho_auth_login
#' @aliases rho_credential_encode rho_credential_decode
#' @aliases rho_auth_refresh rho_auth_to_request rho_auth_prompt rho_auth_notify
#' @aliases rho_auth_error OpenAICodexApi OpenAICodexOAuthAuth
#' @aliases OpenAICodexWebSocketRequest
#' @aliases rho_openai_codex_auth rho_openai_codex_credential
#' @aliases rho_load_openai_codex_credential rho_openai_codex_provider
#' @aliases rho_openai_codex_model rho_openai_codex_request
#' @aliases rho_openai_codex_websocket_request
#' @aliases GitHubCopilotClientIdentity GitHubCopilotEndpoints
#' @aliases GitHubCopilotDeviceAuthorization
#' @aliases GitHubCopilotCredential GitHubCopilotModelAuth
#' @aliases GitHubCopilotLoginModelPolicy GitHubCopilotDiscoverModels
#' @aliases GitHubCopilotEnableKnownModels GitHubCopilotModelPolicyResult
#' @aliases GitHubCopilotOAuthAuth GitHubCopilotApi GitHubCopilotAnthropicApi
#' @aliases rho_github_copilot_client_identity rho_github_copilot_auth
#' @aliases rho_github_copilot_credential rho_github_copilot_credential_from_github_token
#' @aliases rho_load_github_copilot_credential rho_github_copilot_provider
#' @aliases rho_github_copilot_model rho_github_copilot_request
#' @aliases rho_github_copilot_discover_models_policy
#' @aliases rho_github_copilot_enable_known_models_policy
#' @aliases rho_prepare_github_copilot_models
#' @aliases KimiCodeIdentity KimiCodeApi KimiCodeApiKeyAuth
#' @aliases KimiCodeOAuthAuth KimiCodeOAuthCredential KimiCodeModelAuth
#' @aliases KimiCodeDeviceAuthorization KimiCodeToken
#' @aliases rho_kimi_code_identity_headers rho_kimi_code_identity
#' @aliases rho_kimi_code_oauth_auth rho_kimi_code_provider
#' @aliases rho_kimi_code_model
#' @aliases rho_message_initiator rho_has_image_input
#' @export CredentialStore
#' @export OAuthAuth
#' @export LoginIO
#' @export RhoCredential
#' @export RhoApiKeyCredential
#' @export RhoOAuthCredential
#' @export RhoModelAuth
#' @export RhoAuthResolution
#' @export RhoApiKeyAuth
#' @export RhoOAuthAuth
#' @export RhoFunctionOAuthAuth
#' @export RhoLoginMethod
#' @export RhoApiKeyLogin
#' @export RhoOAuthLogin
#' @export RhoProviderAuth
#' @export RhoCredentialGate
#' @export RhoMemoryCredentialStore
#' @export RhoFileCredentialStore
#' @export RhoEncryptedFileCredentialStore
#' @export RhoKeychainCredentialStore
#' @export RhoCredentialEncryptionSecret
#' @export RhoCredentialPassphrase
#' @export RhoCredentialEncryptionKey
#' @export RhoAuthPrompt
#' @export RhoTextAuthPrompt
#' @export RhoSecretAuthPrompt
#' @export RhoManualCodeAuthPrompt
#' @export RhoSelectAuthPrompt
#' @export RhoAuthEvent
#' @export RhoAuthUrlEvent
#' @export RhoDeviceCodeEvent
#' @export RhoAuthProgressEvent
#' @export RhoFunctionLoginIO
#' @export RhoProvider
#' @export RhoModels
#' @export AuthErrorValue
#' @export rho_api_key_credential
#' @export rho_model_auth
#' @export rho_api_key_auth
#' @export rho_oauth_auth
#' @export rho_provider_auth
#' @export rho_credential_gate
#' @export rho_memory_credential_store
#' @export rho_file_credential_store
#' @export rho_encrypted_file_credential_store
#' @export rho_keychain_credential_store
#' @export rho_credential_passphrase
#' @export rho_credential_encryption_key
#' @export rho_user_credential_path
#' @export rho_login_io
#' @export rho_provider
#' @export rho_models
#' @export rho_models_provider
#' @export rho_provider_models
#' @export rho_available_models
#' @export rho_login_provider
#' @export rho_resolve_model_auth
#' @export rho_credential_read
#' @export rho_credential_modify
#' @export rho_credential_delete
#' @export rho_credential_encode
#' @export rho_credential_decode
#' @export rho_auth_login
#' @export rho_auth_refresh
#' @export rho_auth_to_request
#' @export rho_login_strategy
#' @export rho_auth_prompt
#' @export rho_auth_notify
#' @export rho_auth_error
#' @export OpenAICodexApi
#' @export OpenAICodexOAuthAuth
#' @export OpenAICodexWebSocketRequest
#' @export rho_openai_codex_auth
#' @export rho_openai_codex_credential
#' @export rho_load_openai_codex_credential
#' @export rho_openai_codex_provider
#' @export rho_openai_codex_model
#' @export rho_openai_codex_request
#' @export rho_openai_codex_websocket_request
#' @export GitHubCopilotClientIdentity
#' @export GitHubCopilotEndpoints
#' @export GitHubCopilotDeviceAuthorization
#' @export GitHubCopilotCredential
#' @export GitHubCopilotModelAuth
#' @export GitHubCopilotLoginModelPolicy
#' @export GitHubCopilotDiscoverModels
#' @export GitHubCopilotEnableKnownModels
#' @export GitHubCopilotModelPolicyResult
#' @export GitHubCopilotOAuthAuth
#' @export GitHubCopilotApi
#' @export GitHubCopilotAnthropicApi
#' @export rho_github_copilot_client_identity
#' @export rho_github_copilot_discover_models_policy
#' @export rho_github_copilot_enable_known_models_policy
#' @export rho_prepare_github_copilot_models
#' @export rho_github_copilot_auth
#' @export rho_github_copilot_credential
#' @export rho_github_copilot_credential_from_github_token
#' @export rho_load_github_copilot_credential
#' @export rho_github_copilot_provider
#' @export rho_github_copilot_model
#' @export rho_github_copilot_request
#' @export KimiCodeIdentity
#' @export KimiCodeApi
#' @export KimiCodeApiKeyAuth
#' @export KimiCodeOAuthAuth
#' @export KimiCodeOAuthCredential
#' @export KimiCodeModelAuth
#' @export KimiCodeDeviceAuthorization
#' @export KimiCodeToken
#' @export rho_kimi_code_identity_headers
#' @export rho_kimi_code_identity
#' @export rho_kimi_code_oauth_auth
#' @export rho_kimi_code_provider
#' @export rho_kimi_code_model
#' @export rho_message_initiator
#' @export rho_has_image_input
NULL

#' Typed OpenAI Responses wire protocol
#'
#' The OpenAI Responses decoder maps JSON/SSE payloads to typed wire event and
#' output-item classes before reducing them to normalized assistant events.
#' Provider extensions may add narrower S7 methods for new item or event types.
#'
#' @name rho_openai_responses_wire
#' @aliases OpenAIResponseDecoder OpenAIResponseSlot OpenAIResponseItem
#' @aliases OpenAIReasoningItem OpenAIMessageItem OpenAIFunctionCallItem
#' @aliases OpenAIWebSearchCallItem OpenAIWebSearchBinding
#' @aliases OpenAIWebSearchCapability OpenAIWebSearchText
#' @aliases OpenAIWebSearchTextAndImage
#' @aliases OpenAIUnsupportedItem OpenAIResponseWireEvent OpenAIResponseIgnored
#' @aliases OpenAIResponseCreated OpenAIResponseOutputItemAdded
#' @aliases OpenAIResponseThinkingDelta OpenAIResponseThinkingBreak
#' @aliases OpenAIResponseTextDelta OpenAIResponseToolArgumentsDelta
#' @aliases OpenAIResponseToolArgumentsDone OpenAIResponseOutputItemDone
#' @aliases OpenAIResponseCompleted OpenAIResponseIncomplete OpenAIResponseError
#' @aliases rho_openai_responses_decoder
#' @export OpenAIResponseDecoder
#' @export OpenAIResponseSlot
#' @export OpenAIResponseItem
#' @export OpenAIReasoningItem
#' @export OpenAIMessageItem
#' @export OpenAIFunctionCallItem
#' @export OpenAIWebSearchCallItem
#' @export OpenAIWebSearchBinding
#' @export OpenAIWebSearchCapability
#' @export OpenAIWebSearchText
#' @export OpenAIWebSearchTextAndImage
#' @export OpenAIUnsupportedItem
#' @export OpenAIResponseWireEvent
#' @export OpenAIResponseIgnored
#' @export OpenAIResponseCreated
#' @export OpenAIResponseOutputItemAdded
#' @export OpenAIResponseThinkingDelta
#' @export OpenAIResponseThinkingBreak
#' @export OpenAIResponseTextDelta
#' @export OpenAIResponseToolArgumentsDelta
#' @export OpenAIResponseToolArgumentsDone
#' @export OpenAIResponseOutputItemDone
#' @export OpenAIResponseCompleted
#' @export OpenAIResponseIncomplete
#' @export OpenAIResponseError
#' @export rho_openai_responses_decoder
NULL
