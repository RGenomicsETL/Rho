MemoryStore <- s7contract::new_interface(
  "MemoryStore",
  generics = list(
    rho_remember = s7contract::interface_requirement(
      rho_remember,
      args = list(note = RhoMemoryNote),
      returns = RhoTask
    ),
    rho_recall = s7contract::interface_requirement(
      rho_recall,
      args = list(slug = S7::class_character),
      returns = RhoTask
    ),
    rho_edit_memory = s7contract::interface_requirement(
      rho_edit_memory,
      args = list(edit = RhoMemoryEdit),
      returns = RhoTask
    ),
    rho_forget = s7contract::interface_requirement(
      rho_forget,
      args = list(
        slug = S7::class_character,
        expected_revision_id = S7::class_character,
        author = S7::class_character,
        reason = S7::class_character
      ),
      returns = RhoTask
    ),
    rho_memory_history = s7contract::interface_requirement(
      rho_memory_history,
      args = list(slug = S7::class_character),
      returns = RhoTask
    ),
    rho_list_memory = s7contract::interface_requirement(
      rho_list_memory,
      returns = RhoTask
    )
  )
)
