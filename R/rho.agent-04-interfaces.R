AgentEventListener <- s7contract::new_interface(
  "AgentEventListener",
  generics = list(
    rho_handle_agent_event = s7contract::interface_requirement(
      rho_handle_agent_event,
      args = list(event = RhoAgentEvent),
      returns = RhoTask
    )
  )
)

AgentPolicy <- s7contract::new_interface(
  "AgentPolicy",
  generics = list(
    rho_transform_agent_context = rho_transform_agent_context,
    rho_before_tool_call = s7contract::interface_requirement(
      rho_before_tool_call,
      args = list(context = RhoToolContext),
      returns = RhoTask
    ),
    rho_after_tool_call = s7contract::interface_requirement(
      rho_after_tool_call,
      args = list(context = RhoCompletedToolContext),
      returns = RhoTask
    ),
    rho_before_compaction = s7contract::interface_requirement(
      rho_before_compaction,
      args = list(context = RhoBeforeCompactionContext),
      returns = RhoTask
    ),
    rho_after_compaction = s7contract::interface_requirement(
      rho_after_compaction,
      args = list(context = RhoAfterCompactionContext),
      returns = RhoTask
    ),
    rho_prepare_next_turn = rho_prepare_next_turn
  )
)

SessionJournal <- s7contract::new_interface(
  "SessionJournal",
  generics = list(
    rho_commit_session_entry = s7contract::interface_requirement(
      rho_commit_session_entry,
      args = list(append = RhoSessionAppend),
      returns = RhoTask
    ),
    rho_session_snapshot = s7contract::interface_requirement(
      rho_session_snapshot,
      returns = RhoTask
    )
  )
)
