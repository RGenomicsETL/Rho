rho_new_session_id <- function() {
  paste0("session-", nanonext::random(16L))
}

rho_session_identity <- function(id = rho_new_session_id(), parent_id = "") {
  RhoSessionIdentity(id = id, parent_id = parent_id)
}

rho_next_session_entry_id <- function(agent) {
  used <- vapply(agent@state$entries, function(entry) entry@id, character(1))
  repeat {
    candidate <- paste0("entry-", nanonext::random(16L))
    if (!candidate %in% used) {
      return(candidate)
    }
  }
}

rho_replay_session_entries <- function(entries) {
  node_ids <- character()
  record_ids <- character()
  leaf_id <- ""

  for (position in seq_along(entries)) {
    entry <- entries[[position]]
    if (!S7::S7_inherits(entry, RhoSessionEntry)) {
      return(sprintf("@entries[[%d]] must be a RhoSessionEntry", position))
    }
    if (entry@id %in% record_ids) {
      return("@entries must have unique identifiers")
    }

    if (S7::S7_inherits(entry, RhoSessionNodeEntry)) {
      if (nzchar(entry@parent_id) && !entry@parent_id %in% node_ids) {
        return(sprintf(
          "@entries[[%d]] refers to an unknown parent node",
          position
        ))
      }
      if (!identical(entry@parent_id, leaf_id)) {
        return(sprintf(
          paste0(
            "@entries[[%d]] does not descend from the selected leaf; ",
            "record a RhoSessionLeafEntry before appending a branch"
          ),
          position
        ))
      }
      node_ids <- c(node_ids, entry@id)
      leaf_id <- entry@id
    } else if (S7::S7_inherits(entry, RhoSessionLeafEntry)) {
      if (!identical(entry@previous_leaf_id, leaf_id)) {
        return(sprintf(
          "@entries[[%d]] does not move from the selected leaf",
          position
        ))
      }
      if (nzchar(entry@target_leaf_id) && !entry@target_leaf_id %in% node_ids) {
        return(sprintf(
          "@entries[[%d]] moves to an unknown session node",
          position
        ))
      }
      leaf_id <- entry@target_leaf_id
    } else {
      return(sprintf(
        "@entries[[%d]] must be a session node or leaf-movement entry",
        position
      ))
    }
    record_ids <- c(record_ids, entry@id)
  }

  RhoSessionReplay(leaf_id = leaf_id, node_ids = node_ids)
}

rho_session_replay <- function(entries) {
  replay <- rho_replay_session_entries(entries)
  if (is.character(replay)) {
    return(rho_session_conflict(replay))
  }
  replay
}

rho_session_path_entries <- function(entries, leaf_id) {
  if (!nzchar(leaf_id)) {
    return(list())
  }
  nodes <- Filter(
    function(entry) S7::S7_inherits(entry, RhoSessionNodeEntry),
    entries
  )
  by_id <- stats::setNames(nodes, vapply(nodes, function(entry) entry@id, character(1)))
  if (!leaf_id %in% names(by_id)) {
    return(rho_session_conflict(
      "The requested session leaf does not identify a session node",
      details = list(leaf_id = leaf_id)
    ))
  }

  path <- list()
  current <- leaf_id
  visited <- character()
  while (nzchar(current)) {
    if (current %in% visited || !current %in% names(by_id)) {
      return(rho_session_conflict(
        "The session parent graph is cyclic or incomplete",
        details = list(entry_id = current)
      ))
    }
    entry <- by_id[[current]]
    path <- c(list(entry), path)
    visited <- c(visited, current)
    current <- entry@parent_id
  }
  path
}

rho_session_message_entry <- function(agent, message) {
  RhoSessionMessageEntry(
    id = rho_next_session_entry_id(agent),
    parent_id = agent@state$leaf_id,
    timestamp = message@timestamp,
    message = message
  )
}

rho_memory_session_journal <- function(
  identity = rho_session_identity()
) {
  RhoMemorySessionJournal(
    state = rho_agent_new_state(
      current = RhoSessionSnapshot(
        identity = identity,
        entries = list(),
        position = 0L,
        leaf_id = ""
      )
    )
  )
}

S7::method(
  rho_commit_session_entry,
  list(RhoMemorySessionJournal, RhoSessionAppend)
) <- function(journal, append, ...) {
  snapshot <- journal@state$current
  if (!identical(append@after, snapshot@position)) {
    return(rho_task(rho_session_conflict(
      "The session journal has advanced beyond the expected position",
      details = list(expected = append@after, current = snapshot@position)
    )))
  }
  ids <- vapply(snapshot@entries, function(committed) committed@id, character(1))
  if (append@entry@id %in% ids) {
    return(rho_task(rho_session_conflict(
      "A session entry with this identifier is already committed",
      details = list(
        entry_id = append@entry@id,
        position = match(append@entry@id, ids)
      )
    )))
  }
  entries <- c(snapshot@entries, list(append@entry))
  replay <- rho_replay_session_entries(entries)
  if (is.character(replay)) {
    return(rho_task(rho_session_conflict(
      replay,
      details = list(position = snapshot@position + 1L)
    )))
  }
  position <- snapshot@position + 1L
  next_snapshot <- RhoSessionSnapshot(
    identity = snapshot@identity,
    entries = entries,
    position = position,
    leaf_id = replay@leaf_id
  )
  journal@state$current <- next_snapshot
  rho_task(RhoSessionCommit(
    identity = next_snapshot@identity,
    entry = append@entry,
    position = position,
    leaf_id = next_snapshot@leaf_id
  ))
}

S7::method(
  rho_session_snapshot,
  RhoMemorySessionJournal
) <- function(journal, ...) {
  rho_task(journal@state$current)
}

S7::method(rho_session_trajectory, RhoSessionSnapshot) <- function(
  snapshot,
  leaf_id = snapshot@leaf_id,
  ...
) {
  entries <- rho_session_path_entries(snapshot@entries, leaf_id)
  if (S7::S7_inherits(entries, RhoSessionJournalErrorValue)) {
    return(entries)
  }
  RhoSessionTrajectory(
    identity = snapshot@identity,
    source_position = snapshot@position,
    leaf_id = leaf_id,
    entries = entries
  )
}

rho_project_session_messages <- function(entries, leaf_id) {
  lapply(
    Filter(
      function(entry) S7::S7_inherits(entry, RhoSessionMessageEntry),
      rho_active_session_entries(entries, leaf_id)
    ),
    function(entry) entry@message
  )
}

S7::method(
  rho_apply_session_snapshot,
  list(RhoAgent, RhoSessionSnapshot)
) <- function(agent, snapshot, ...) {
  if (!S7::S7_inherits(agent@state$phase, RhoAgentIdle)) {
    return(rho_task(rho_session_conflict(
      "A running agent cannot synchronize its session"
    )))
  }

  current_position <- agent@state$journal_position
  if (snapshot@position < current_position) {
    return(rho_task(rho_session_conflict(
      "The session snapshot is behind the agent projection",
      details = list(
        agent_position = current_position,
        snapshot_position = snapshot@position
      )
    )))
  }

  current <- agent@state$entries
  prefix <- if (length(current)) {
    snapshot@entries[seq_along(current)]
  } else {
    list()
  }
  if (length(current) > length(snapshot@entries) || !identical(current, prefix)) {
    return(rho_task(rho_session_conflict(
      "The session snapshot diverges from the agent projection",
      details = list(
        agent_position = current_position,
        snapshot_position = snapshot@position
      )
    )))
  }

  if (
    nzchar(agent@state$session_id) &&
      !identical(agent@state$session_id, snapshot@identity@id)
  ) {
    return(rho_task(rho_session_conflict(
      "The session snapshot belongs to a different session",
      details = list(
        agent_session_id = agent@state$session_id,
        snapshot_session_id = snapshot@identity@id
      )
    )))
  }

  agent@state$entries <- snapshot@entries
  agent@state$session_id <- snapshot@identity@id
  agent@state$parent_session_id <- snapshot@identity@parent_id
  agent@state$leaf_id <- snapshot@leaf_id
  agent@state$messages <- rho_project_session_messages(
    snapshot@entries,
    snapshot@leaf_id
  )
  agent@state$journal_position <- snapshot@position
  rho_task(agent)
}

S7::method(rho_sync_session, RhoAgent) <- function(agent, ...) {
  if (!S7::S7_inherits(agent@state$phase, RhoAgentIdle)) {
    return(rho_task(rho_session_conflict(
      "A running agent cannot synchronize its session"
    )))
  }
  rho_then(
    rho_session_snapshot(agent@journal),
    function(snapshot) {
      if (S7::S7_inherits(snapshot, RhoSessionJournalErrorValue)) {
        return(snapshot)
      }
      if (!S7::S7_inherits(snapshot, RhoSessionSnapshot)) {
        return(rho_session_journal_error(
          "A session journal snapshot must resolve to RhoSessionSnapshot or RhoSessionJournalErrorValue"
        ))
      }
      rho_apply_session_snapshot(agent, snapshot)
    }
  )
}

rho_apply_session_commit <- function(agent, commit) {
  if (S7::S7_inherits(commit, RhoSessionJournalErrorValue)) {
    return(commit)
  }
  if (!S7::S7_inherits(commit, RhoSessionCommit)) {
    rho_signal_contract_violation(
      "A session journal append must resolve to RhoSessionCommit or RhoSessionJournalErrorValue"
    )
  }
  if (commit@position != agent@state$journal_position + 1L) {
    return(rho_session_conflict(
      "The session journal returned a non-consecutive commit position",
      details = list(
        expected = agent@state$journal_position + 1L,
        received = commit@position
      )
    ))
  }
  if (
    nzchar(agent@state$session_id) &&
      !identical(commit@identity@id, agent@state$session_id)
  ) {
    return(rho_session_conflict(
      "The session journal commit belongs to a different session",
      details = list(
        agent_session_id = agent@state$session_id,
        commit_session_id = commit@identity@id
      )
    ))
  }
  agent@state$journal_position <- commit@position
  agent@state$entries[[length(agent@state$entries) + 1L]] <- commit@entry
  replay <- rho_replay_session_entries(agent@state$entries)
  if (is.character(replay) || !identical(replay@leaf_id, commit@leaf_id)) {
    return(rho_session_conflict(
      "The session journal commit has an invalid selected leaf",
      details = list(
        commit_leaf_id = commit@leaf_id,
        replay = if (is.character(replay)) replay else replay@leaf_id
      )
    ))
  }
  agent@state$session_id <- commit@identity@id
  agent@state$parent_session_id <- commit@identity@parent_id
  agent@state$leaf_id <- commit@leaf_id
  agent@state$messages <- rho_project_session_messages(
    agent@state$entries,
    agent@state$leaf_id
  )
  commit
}

S7::method(
  rho_append_session_entry,
  list(RhoAgent, RhoSessionEntry)
) <- function(agent, entry, ...) {
  rho_then(
    rho_commit_session_entry(
      agent@journal,
      RhoSessionAppend(
        entry = entry,
        after = agent@state$journal_position
      )
    ),
    function(commit) rho_apply_session_commit(agent, commit)
  )
}

S7::method(rho_move_session_leaf, RhoAgent) <- function(
  agent,
  target_entry_id = "",
  ...
) {
  if (!S7::S7_inherits(agent@state$phase, RhoAgentIdle)) {
    return(rho_task(rho_session_conflict(
      "A running agent cannot move its session leaf"
    )))
  }
  target_entry_id <- as.character(target_entry_id)
  if (length(target_entry_id) != 1L || is.na(target_entry_id)) {
    rho_signal_contract_violation(
      "`target_entry_id` must be one non-missing entry identifier or the empty root identifier"
    )
  }
  nodes <- Filter(
    function(entry) S7::S7_inherits(entry, RhoSessionNodeEntry),
    agent@state$entries
  )
  node_ids <- vapply(nodes, function(entry) entry@id, character(1))
  if (nzchar(target_entry_id) && !target_entry_id %in% node_ids) {
    return(rho_task(rho_session_conflict(
      "The requested session leaf does not identify a committed session node",
      details = list(target_entry_id = target_entry_id)
    )))
  }
  rho_append_session_entry(
    agent,
    RhoSessionLeafEntry(
      id = rho_next_session_entry_id(agent),
      timestamp = as.double(Sys.time()),
      previous_leaf_id = agent@state$leaf_id,
      target_leaf_id = target_entry_id
    )
  )
}

rho_record_agent_message <- function(agent, message) {
  entry <- rho_session_message_entry(agent, message)
  rho_append_session_entry(agent, entry)
}

rho_exclude_session_entry <- function(agent, target_entry_id, reason) {
  entry <- RhoSessionContextExclusionEntry(
    id = rho_next_session_entry_id(agent),
    parent_id = agent@state$leaf_id,
    timestamp = as.double(Sys.time()),
    target_entry_id = target_entry_id,
    reason = reason
  )
  rho_append_session_entry(agent, entry)
}

rho_latest_compaction_index <- function(entries) {
  indexes <- which(vapply(
    entries,
    function(entry) S7::S7_inherits(entry, RhoSessionCompactionEntry),
    logical(1)
  ))
  if (!length(indexes)) NULL else indexes[[length(indexes)]]
}

rho_latest_compaction_entry <- function(agent) {
  entries <- rho_active_session_entries(
    agent@state$entries,
    agent@state$leaf_id
  )
  index <- rho_latest_compaction_index(entries)
  if (is.null(index)) NULL else entries[[index]]
}

rho_active_session_entries <- function(entries, leaf_id) {
  entries <- rho_session_path_entries(entries, leaf_id)
  if (S7::S7_inherits(entries, RhoSessionJournalErrorValue)) {
    rho_signal_contract_violation(entries@message)
  }
  resets <- which(vapply(
    entries,
    function(entry) S7::S7_inherits(entry, RhoSessionResetEntry),
    logical(1)
  ))
  if (!length(resets)) {
    return(entries)
  }
  start <- resets[[length(resets)]] + 1L
  if (start > length(entries)) list() else entries[seq.int(start, length(entries))]
}

rho_session_context_entries <- function(agent) {
  entries <- rho_active_session_entries(
    agent@state$entries,
    agent@state$leaf_id
  )
  compaction_index <- rho_latest_compaction_index(entries)
  selected <- entries

  if (!is.null(compaction_index)) {
    compaction <- entries[[compaction_index]]
    ids <- vapply(entries, function(entry) entry@id, character(1))
    first_kept <- match(compaction@result@first_kept_entry_id, ids)
    retained <- if (!is.na(first_kept) && first_kept < compaction_index) {
      entries[seq.int(first_kept, compaction_index - 1L)]
    } else {
      list()
    }
    following <- if (compaction_index < length(entries)) {
      entries[seq.int(compaction_index + 1L, length(entries))]
    } else {
      list()
    }
    selected <- c(list(compaction), retained, following)
  }

  excluded <- vapply(
    Filter(
      function(entry) S7::S7_inherits(entry, RhoSessionContextExclusionEntry),
      entries
    ),
    function(entry) entry@target_entry_id,
    character(1)
  )
  Filter(
    function(entry) {
      !S7::S7_inherits(entry, RhoSessionMessageEntry) ||
        !entry@id %in% excluded
    },
    selected
  )
}

S7::method(
  rho_project_session_entry,
  list(RhoSessionEntry, RhoAgent)
) <- function(entry, agent, ...) {
  list()
}

S7::method(
  rho_project_session_entry,
  list(RhoSessionMessageEntry, RhoAgent)
) <- function(entry, agent, ...) {
  list(entry@message)
}

rho_compaction_summary_message <- function(entry) {
  rho_user_message(
    paste0(
      "The conversation history before this point was compacted into the following summary:\n\n",
      "<summary>\n",
      entry@result@summary,
      "\n</summary>"
    ),
    timestamp = entry@timestamp
  )
}

S7::method(
  rho_project_session_entry,
  list(RhoSessionCompactionEntry, RhoAgent)
) <- function(entry, agent, ...) {
  list(rho_compaction_summary_message(entry))
}

S7::method(rho_build_agent_context, RhoAgent) <- function(agent, ...) {
  entries <- rho_session_context_entries(agent)
  messages <- if (length(entries)) {
    unlist(
      lapply(entries, rho_project_session_entry, agent = agent),
      recursive = FALSE
    )
  } else {
    list()
  }
  rho_context(
    agent@options@system_prompt,
    messages,
    agent@state$tools,
    agent@options@operations
  )
}
