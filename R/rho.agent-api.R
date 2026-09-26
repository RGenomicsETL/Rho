#' Agent state machine, policy, scheduling, and lifecycle events
#'
#' [rho_prompt()] and [rho_continue()] return tasks. The agent consumes typed
#' assistant events, schedules tool tasks, preserves source-order results, and
#' emits typed lifecycle events. Steering and follow-up queues have separate,
#' typed draining policies.
#'
#' Policy and scheduling decisions are S7 generics. Packages can specialize
#' context transformation, before/after-tool behavior, next-turn preparation,
#' assistant event reduction, queue draining, and tool batch execution without
#' replacing the core loop.
#'
#' @name rho_agent_contracts
#' @aliases RhoAgent RhoAgentOptions RhoAgentRunResult RhoAgentErrorValue
#' @aliases RhoAgentPolicy RhoDefaultAgentPolicy AgentPolicy AgentEventListener
#' @aliases RhoToolExecutionMode RhoParallelToolExecution
#' @aliases RhoSequentialToolExecution RhoQueueMode RhoOneAtATimeQueue
#' @aliases RhoAllQueue RhoAgentPhase RhoAgentIdle RhoAgentRunning
#' @aliases RhoAgentCompacting RhoBeforeToolCallDecision RhoAfterToolCallDecision
#' @aliases RhoRunContext RhoToolContext RhoCompletedToolContext
#' @aliases RhoNextTurnDecision RhoAssistantTurn RhoAssistantResponse RhoToolBatch
#' @aliases RhoAgentEvent RhoAgentStartEvent RhoAgentEndEvent
#' @aliases RhoAgentSettledEvent RhoTurnStartEvent RhoTurnEndEvent
#' @aliases RhoMessageEvent RhoMessageStartEvent RhoMessageUpdateEvent
#' @aliases RhoMessageEndEvent RhoToolExecutionStartEvent
#' @aliases RhoToolExecutionUpdateEvent RhoToolExecutionEndEvent
#' @aliases RhoQueueUpdateEvent rho_agent rho_prompt rho_continue rho_subscribe
#' @aliases rho_steer rho_follow_up rho_reset rho_abort_agent rho_wait_for_idle
#' @aliases rho_emit_agent_event rho_handle_agent_event rho_state_messages
#' @aliases rho_transform_agent_context rho_before_tool_call rho_after_tool_call
#' @aliases rho_prepare_next_turn rho_reduce_assistant_event
#' @aliases rho_execute_tool_batch rho_resolve_tool_execution rho_take_agent_queue
#' @aliases rho_run_context rho_tool_context rho_completed_tool_context
#' @aliases rho_agent_error rho_before_tool_call_decision
#' @aliases rho_after_tool_call_decision rho_next_turn_decision
#' @export RhoAgent
#' @export RhoAgentOptions
#' @export RhoAgentRunResult
#' @export RhoAgentErrorValue
#' @export RhoAgentPolicy
#' @export RhoDefaultAgentPolicy
#' @export AgentPolicy
#' @export AgentEventListener
#' @export RhoToolExecutionMode
#' @export RhoParallelToolExecution
#' @export RhoSequentialToolExecution
#' @export RhoQueueMode
#' @export RhoOneAtATimeQueue
#' @export RhoAllQueue
#' @export RhoAgentPhase
#' @export RhoAgentIdle
#' @export RhoAgentRunning
#' @export RhoAgentCompacting
#' @export RhoBeforeToolCallDecision
#' @export RhoAfterToolCallDecision
#' @export RhoRunContext
#' @export RhoToolContext
#' @export RhoCompletedToolContext
#' @export RhoNextTurnDecision
#' @export RhoAssistantTurn
#' @export RhoAssistantResponse
#' @export RhoToolBatch
#' @export RhoAgentEvent
#' @export RhoAgentStartEvent
#' @export RhoAgentEndEvent
#' @export RhoAgentSettledEvent
#' @export RhoTurnStartEvent
#' @export RhoTurnEndEvent
#' @export RhoMessageEvent
#' @export RhoMessageStartEvent
#' @export RhoMessageUpdateEvent
#' @export RhoMessageEndEvent
#' @export RhoToolExecutionStartEvent
#' @export RhoToolExecutionUpdateEvent
#' @export RhoToolExecutionEndEvent
#' @export RhoQueueUpdateEvent
#' @export rho_agent
#' @export rho_prompt
#' @export rho_continue
#' @export rho_subscribe
#' @export rho_steer
#' @export rho_follow_up
#' @export rho_reset
#' @export rho_abort_agent
#' @export rho_wait_for_idle
#' @export rho_emit_agent_event
#' @export rho_handle_agent_event
#' @export rho_state_messages
#' @export rho_transform_agent_context
#' @export rho_before_tool_call
#' @export rho_after_tool_call
#' @export rho_prepare_next_turn
#' @export rho_reduce_assistant_event
#' @export rho_execute_tool_batch
#' @export rho_resolve_tool_execution
#' @export rho_take_agent_queue
#' @export rho_run_context
#' @export rho_tool_context
#' @export rho_completed_tool_context
#' @export rho_agent_error
#' @export rho_before_tool_call_decision
#' @export rho_after_tool_call_decision
#' @export rho_next_turn_decision
#' @importFrom promises promise
#' @importFrom s7contract interface_requirement new_interface
NULL
