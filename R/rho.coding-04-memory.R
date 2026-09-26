rho_memory_non_empty_string <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !nzchar(value)) {
      "must be one non-empty string"
    }
  }
)

rho_memory_scalar_string <- S7::new_property(
  S7::class_character,
  default = "",
  validator = function(value) {
    if (length(value) != 1L || is.na(value)) {
      "must be one non-missing string"
    }
  }
)

rho_memory_slug_property <- S7::new_property(
  S7::class_character,
  validator = function(value) {
    if (
      length(value) != 1L ||
        is.na(value) ||
        !grepl("^[a-z0-9]+(?:[-._][a-z0-9]+)*$", value)
    ) {
      "must be one lowercase slug containing letters, numbers, '.', '-', or '_'"
    }
  }
)

rho_memory_sequence <- S7::new_property(
  S7::class_integer,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || value <= 0L) {
      "must be one positive integer"
    }
  }
)

rho_memory_time <- S7::new_property(
  S7::class_double,
  validator = function(value) {
    if (length(value) != 1L || is.na(value) || !is.finite(value)) {
      "must be one finite timestamp"
    }
  }
)

RhoMemoryLink <- S7::new_class(
  "RhoMemoryLink",
  properties = list(
    predicate = rho_memory_non_empty_string,
    to = rho_memory_slug_property
  )
)

RhoMemorySource <- S7::new_class(
  "RhoMemorySource",
  properties = list(
    path = rho_memory_scalar_string,
    url = rho_memory_scalar_string,
    locator = rho_memory_scalar_string,
    quote = rho_memory_scalar_string
  ),
  validator = function(self) {
    if (!any(nzchar(c(self@path, self@url, self@locator, self@quote)))) {
      "must identify a path, URL, locator, or quote"
    }
  }
)

rho_memory_links <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    valid <- vapply(
      value,
      S7::S7_inherits,
      logical(1),
      class = RhoMemoryLink
    )
    if (!all(valid)) "must contain only RhoMemoryLink values"
  }
)

rho_memory_sources <- S7::new_property(
  S7::class_list,
  default = list(),
  validator = function(value) {
    valid <- vapply(
      value,
      S7::S7_inherits,
      logical(1),
      class = RhoMemorySource
    )
    if (!all(valid)) "must contain only RhoMemorySource values"
  }
)

RhoMemoryNote <- S7::new_class(
  "RhoMemoryNote",
  properties = list(
    slug = rho_memory_slug_property,
    title = rho_memory_non_empty_string,
    hook = rho_memory_scalar_string,
    body = rho_memory_scalar_string,
    tags = S7::new_property(S7::class_character, default = character()),
    links = rho_memory_links,
    sources = rho_memory_sources
  )
)

RhoMemoryEdit <- S7::new_class(
  "RhoMemoryEdit",
  abstract = TRUE,
  properties = list(expected_revision_id = rho_memory_non_empty_string)
)

RhoMemoryReplacement <- S7::new_class(
  "RhoMemoryReplacement",
  parent = RhoMemoryEdit,
  properties = list(note = RhoMemoryNote)
)

RhoMemoryCommand <- S7::new_class("RhoMemoryCommand", abstract = TRUE)

RhoRememberMemoryCommand <- S7::new_class(
  "RhoRememberMemoryCommand",
  parent = RhoMemoryCommand,
  properties = list(note = RhoMemoryNote)
)

RhoRecallMemoryCommand <- S7::new_class(
  "RhoRecallMemoryCommand",
  parent = RhoMemoryCommand,
  properties = list(
    slug = rho_memory_slug_property,
    revision_id = rho_memory_scalar_string
  )
)

RhoEditMemoryCommand <- S7::new_class(
  "RhoEditMemoryCommand",
  parent = RhoMemoryCommand,
  properties = list(edit = RhoMemoryEdit)
)

RhoForgetMemoryCommand <- S7::new_class(
  "RhoForgetMemoryCommand",
  parent = RhoMemoryCommand,
  properties = list(
    slug = rho_memory_slug_property,
    expected_revision_id = rho_memory_non_empty_string,
    reason = rho_memory_non_empty_string
  )
)

RhoMemoryHistoryCommand <- S7::new_class(
  "RhoMemoryHistoryCommand",
  parent = RhoMemoryCommand,
  properties = list(slug = rho_memory_slug_property)
)

RhoMemoryClock <- S7::new_class("RhoMemoryClock", abstract = TRUE)
RhoSystemMemoryClock <- S7::new_class(
  "RhoSystemMemoryClock",
  parent = RhoMemoryClock
)

RhoMemoryStore <- S7::new_class("RhoMemoryStore", abstract = TRUE)
RhoInMemoryMemoryStore <- S7::new_class(
  "RhoInMemoryMemoryStore",
  parent = RhoMemoryStore,
  properties = list(
    state = S7::class_environment,
    clock = RhoMemoryClock
  )
)

RhoMemoryObservation <- S7::new_class(
  "RhoMemoryObservation",
  abstract = TRUE,
  properties = list(
    revision_id = rho_memory_non_empty_string,
    sequence = rho_memory_sequence,
    recorded_at = rho_memory_time,
    author = rho_memory_non_empty_string
  )
)

RhoMemoryContentRevision <- S7::new_class(
  "RhoMemoryContentRevision",
  parent = RhoMemoryObservation,
  abstract = TRUE,
  properties = list(
    note = RhoMemoryNote,
    supersedes_revision_id = rho_memory_scalar_string
  )
)

RhoMemoryRemembered <- S7::new_class(
  "RhoMemoryRemembered",
  parent = RhoMemoryContentRevision
)

RhoMemoryEdited <- S7::new_class(
  "RhoMemoryEdited",
  parent = RhoMemoryContentRevision,
  properties = list(retracted_links = rho_memory_links),
  validator = function(self) {
    if (!nzchar(self@supersedes_revision_id)) {
      "@supersedes_revision_id must identify the edited revision"
    }
  }
)

RhoMemoryForgotten <- S7::new_class(
  "RhoMemoryForgotten",
  parent = RhoMemoryObservation,
  properties = list(
    slug = rho_memory_slug_property,
    supersedes_revision_id = rho_memory_non_empty_string,
    reason = rho_memory_non_empty_string,
    retracted_links = rho_memory_links
  )
)

RhoMemoryResult <- S7::new_class("RhoMemoryResult", abstract = TRUE)

RhoMemoryFound <- S7::new_class(
  "RhoMemoryFound",
  parent = RhoMemoryResult,
  properties = list(revision = RhoMemoryContentRevision)
)

RhoMemoryAbsent <- S7::new_class(
  "RhoMemoryAbsent",
  parent = RhoMemoryResult,
  properties = list(
    slug = rho_memory_slug_property,
    last_revision_id = rho_memory_scalar_string
  )
)

RhoMemoryHistory <- S7::new_class(
  "RhoMemoryHistory",
  parent = RhoMemoryResult,
  properties = list(
    slug = rho_memory_slug_property,
    revisions = S7::class_list
  ),
  validator = function(self) {
    valid <- vapply(
      self@revisions,
      S7::S7_inherits,
      logical(1),
      class = RhoMemoryObservation
    )
    if (!all(valid)) "@revisions must contain only RhoMemoryObservation values"
  }
)

RhoMemoryIndex <- S7::new_class(
  "RhoMemoryIndex",
  parent = RhoMemoryResult,
  properties = list(revisions = S7::class_list),
  validator = function(self) {
    valid <- vapply(
      self@revisions,
      S7::S7_inherits,
      logical(1),
      class = RhoMemoryContentRevision
    )
    if (!all(valid)) "@revisions must contain only live content revisions"
  }
)

RhoMemoryErrorValue <- S7::new_class(
  "RhoMemoryErrorValue",
  parent = RhoMemoryResult,
  abstract = TRUE,
  properties = list(
    slug = rho_memory_slug_property,
    message = rho_memory_non_empty_string
  )
)

RhoMemoryAlreadyExists <- S7::new_class(
  "RhoMemoryAlreadyExists",
  parent = RhoMemoryErrorValue,
  properties = list(current_revision_id = rho_memory_non_empty_string)
)

RhoMemoryConflict <- S7::new_class(
  "RhoMemoryConflict",
  parent = RhoMemoryErrorValue,
  properties = list(
    expected_revision_id = rho_memory_non_empty_string,
    actual_revision_id = rho_memory_non_empty_string
  )
)

RhoMemoryNotFound <- S7::new_class(
  "RhoMemoryNotFound",
  parent = RhoMemoryErrorValue,
  properties = list(last_revision_id = rho_memory_scalar_string)
)

RhoMemoryEditUnsupported <- S7::new_class(
  "RhoMemoryEditUnsupported",
  parent = RhoMemoryErrorValue
)

rho_memory_now <- S7::new_generic(
  "rho_memory_now",
  "clock",
  function(clock, ...) S7::S7_dispatch()
)

rho_remember <- S7::new_generic(
  "rho_remember",
  c("store", "note"),
  function(store, note, author, ...) S7::S7_dispatch()
)

rho_recall <- S7::new_generic(
  "rho_recall",
  "store",
  function(store, slug, revision_id = "", ...) S7::S7_dispatch()
)

rho_edit_memory <- S7::new_generic(
  "rho_edit_memory",
  c("store", "edit"),
  function(store, edit, author, ...) S7::S7_dispatch()
)

rho_apply_memory_edit <- S7::new_generic(
  "rho_apply_memory_edit",
  c("note", "edit"),
  function(note, edit, ...) S7::S7_dispatch()
)

rho_forget <- S7::new_generic(
  "rho_forget",
  "store",
  function(store, slug, expected_revision_id, author, reason, ...) {
    S7::S7_dispatch()
  }
)

rho_memory_history <- S7::new_generic(
  "rho_memory_history",
  "store",
  function(store, slug, ...) S7::S7_dispatch()
)

rho_list_memory <- S7::new_generic(
  "rho_list_memory",
  "store",
  function(store, ...) S7::S7_dispatch()
)

rho_memory_tool_result <- S7::new_generic(
  "rho_memory_tool_result",
  "result",
  function(result, ...) S7::S7_dispatch()
)

rho_memory_slug <- S7::new_generic(
  "rho_memory_slug",
  "x",
  function(x, ...) S7::S7_dispatch()
)

rho_as_memory_link <- S7::new_generic(
  "rho_as_memory_link",
  "x",
  function(x, ...) S7::S7_dispatch()
)

rho_as_memory_source <- S7::new_generic(
  "rho_as_memory_source",
  "x",
  function(x, ...) S7::S7_dispatch()
)

rho_execute_memory_command <- S7::new_generic(
  "rho_execute_memory_command",
  c("store", "command"),
  function(store, command, author, ...) S7::S7_dispatch()
)

S7::method(rho_memory_now, RhoSystemMemoryClock) <- function(clock, ...) {
  as.double(Sys.time())
}

S7::method(rho_memory_slug, RhoMemoryNote) <- function(x, ...) x@slug

S7::method(rho_memory_slug, RhoMemoryReplacement) <- function(x, ...) {
  rho_memory_slug(x@note)
}

S7::method(rho_memory_slug, RhoMemoryContentRevision) <- function(x, ...) {
  rho_memory_slug(x@note)
}

S7::method(rho_memory_slug, RhoMemoryForgotten) <- function(x, ...) x@slug

rho_memory_link <- function(predicate, to) {
  RhoMemoryLink(predicate = predicate, to = to)
}

rho_memory_source <- function(path = "", url = "", locator = "", quote = "") {
  RhoMemorySource(path = path, url = url, locator = locator, quote = quote)
}

S7::method(rho_as_memory_link, RhoMemoryLink) <- function(x, ...) x

S7::method(rho_as_memory_link, S7::class_list) <- function(x, ...) {
  do.call(rho_memory_link, x)
}

S7::method(rho_as_memory_source, RhoMemorySource) <- function(x, ...) x

S7::method(rho_as_memory_source, S7::class_list) <- function(x, ...) {
  do.call(rho_memory_source, x)
}

rho_memory_note <- function(
  slug,
  title,
  body,
  hook = "",
  tags = character(),
  links = list(),
  sources = list()
) {
  RhoMemoryNote(
    slug = slug,
    title = title,
    hook = hook,
    body = body,
    tags = as.character(tags),
    links = lapply(links, rho_as_memory_link),
    sources = lapply(sources, rho_as_memory_source)
  )
}

rho_memory_replacement <- function(note, expected_revision_id) {
  RhoMemoryReplacement(
    expected_revision_id = expected_revision_id,
    note = note
  )
}

rho_memory_replacement_command <- function(
  slug,
  expected_revision_id,
  title,
  body,
  hook = "",
  tags = character(),
  links = list(),
  sources = list()
) {
  RhoEditMemoryCommand(
    edit = rho_memory_replacement(
      rho_memory_note(
        slug = slug,
        title = title,
        body = body,
        hook = hook,
        tags = tags,
        links = links,
        sources = sources
      ),
      expected_revision_id
    )
  )
}

rho_in_memory_memory_store <- function(clock = RhoSystemMemoryClock()) {
  state <- new.env(parent = emptyenv())
  state$observations <- list()
  state$position <- 0L
  RhoInMemoryMemoryStore(state = state, clock = clock)
}

rho_memory_revisions_for <- function(store, slug) {
  Filter(
    function(observation) identical(rho_memory_slug(observation), slug),
    store@state$observations
  )
}

rho_memory_latest_revision <- function(store, slug) {
  revisions <- rho_memory_revisions_for(store, slug)
  if (!length(revisions)) NULL else revisions[[length(revisions)]]
}

rho_memory_link_key <- function(link) {
  paste(link@predicate, link@to, sep = "\r")
}

rho_memory_retracted_links <- function(previous, current = list()) {
  current_keys <- vapply(current, rho_memory_link_key, character(1))
  Filter(
    function(link) !rho_memory_link_key(link) %in% current_keys,
    previous
  )
}

rho_memory_next_identity <- function(store, slug, value, author, recorded_at) {
  sequence <- store@state$position + 1L
  digest <- digest::digest(
    list(
      slug = slug,
      sequence = sequence,
      value = value,
      author = author,
      recorded_at = recorded_at
    ),
    algo = "sha256"
  )
  list(
    sequence = sequence,
    revision_id = sprintf("memory:%s:%s", slug, substr(digest, 1L, 20L))
  )
}

rho_append_memory_observation <- function(store, observation) {
  store@state$observations[[length(store@state$observations) + 1L]] <- observation
  store@state$position <- observation@sequence
  observation
}

S7::method(
  rho_apply_memory_edit,
  list(RhoMemoryNote, RhoMemoryReplacement)
) <- function(note, edit, ...) {
  edit@note
}

S7::method(
  rho_remember,
  list(RhoInMemoryMemoryStore, RhoMemoryNote)
) <- function(store, note, author, ...) {
  rho_task_from_function(
    function() {
      current <- rho_memory_latest_revision(store, note@slug)
      if (!is.null(current) && S7::S7_inherits(current, RhoMemoryContentRevision)) {
        return(RhoMemoryAlreadyExists(
          slug = note@slug,
          message = sprintf(
            "Memory '%s' already exists; edit its current revision explicitly",
            note@slug
          ),
          current_revision_id = current@revision_id
        ))
      }
      recorded_at <- rho_memory_now(store@clock)
      identity <- rho_memory_next_identity(
        store,
        note@slug,
        note,
        author,
        recorded_at
      )
      observation <- RhoMemoryRemembered(
        revision_id = identity$revision_id,
        sequence = identity$sequence,
        recorded_at = recorded_at,
        author = author,
        note = note,
        supersedes_revision_id = if (is.null(current)) "" else current@revision_id
      )
      rho_append_memory_observation(store, observation)
    },
    label = "remember-memory"
  )
}

S7::method(rho_recall, RhoInMemoryMemoryStore) <- function(
  store,
  slug,
  revision_id = "",
  ...
) {
  rho_task_from_function(
    function() {
      revisions <- rho_memory_revisions_for(store, slug)
      selected <- if (!nzchar(revision_id)) {
        if (length(revisions)) revisions[[length(revisions)]] else NULL
      } else {
        matched <- Filter(
          function(observation) identical(observation@revision_id, revision_id),
          revisions
        )
        if (length(matched)) matched[[1L]] else NULL
      }
      if (is.null(selected) || S7::S7_inherits(selected, RhoMemoryForgotten)) {
        last_revision_id <- if (is.null(selected)) {
          if (length(revisions)) revisions[[length(revisions)]]@revision_id else ""
        } else {
          selected@revision_id
        }
        return(RhoMemoryAbsent(
          slug = slug,
          last_revision_id = last_revision_id
        ))
      }
      RhoMemoryFound(revision = selected)
    },
    label = "recall-memory"
  )
}

S7::method(
  rho_edit_memory,
  list(RhoInMemoryMemoryStore, RhoMemoryEdit)
) <- function(store, edit, author, ...) {
  rho_task_from_function(
    function() {
      slug <- rho_memory_slug(edit)
      current <- rho_memory_latest_revision(store, slug)
      if (is.null(current) || S7::S7_inherits(current, RhoMemoryForgotten)) {
        return(RhoMemoryNotFound(
          slug = slug,
          message = sprintf("Memory '%s' has no live revision to edit", slug),
          last_revision_id = if (is.null(current)) "" else current@revision_id
        ))
      }
      if (!identical(current@revision_id, edit@expected_revision_id)) {
        return(RhoMemoryConflict(
          slug = slug,
          message = sprintf(
            "Memory '%s' changed after the revision selected for editing",
            slug
          ),
          expected_revision_id = edit@expected_revision_id,
          actual_revision_id = current@revision_id
        ))
      }
      note <- tryCatch(
        rho_apply_memory_edit(current@note, edit),
        error = function(error) error
      )
      if (inherits(note, "error")) {
        return(RhoMemoryEditUnsupported(
          slug = slug,
          message = conditionMessage(note)
        ))
      }
      recorded_at <- rho_memory_now(store@clock)
      identity <- rho_memory_next_identity(
        store,
        slug,
        note,
        author,
        recorded_at
      )
      observation <- RhoMemoryEdited(
        revision_id = identity$revision_id,
        sequence = identity$sequence,
        recorded_at = recorded_at,
        author = author,
        note = note,
        supersedes_revision_id = current@revision_id,
        retracted_links = rho_memory_retracted_links(
          current@note@links,
          note@links
        )
      )
      rho_append_memory_observation(store, observation)
    },
    label = "edit-memory"
  )
}

S7::method(rho_forget, RhoInMemoryMemoryStore) <- function(
  store,
  slug,
  expected_revision_id,
  author,
  reason,
  ...
) {
  rho_task_from_function(
    function() {
      current <- rho_memory_latest_revision(store, slug)
      if (is.null(current) || S7::S7_inherits(current, RhoMemoryForgotten)) {
        return(RhoMemoryNotFound(
          slug = slug,
          message = sprintf("Memory '%s' has no live revision to forget", slug),
          last_revision_id = if (is.null(current)) "" else current@revision_id
        ))
      }
      if (!identical(current@revision_id, expected_revision_id)) {
        return(RhoMemoryConflict(
          slug = slug,
          message = sprintf(
            "Memory '%s' changed after the revision selected for forgetting",
            slug
          ),
          expected_revision_id = expected_revision_id,
          actual_revision_id = current@revision_id
        ))
      }
      recorded_at <- rho_memory_now(store@clock)
      identity <- rho_memory_next_identity(
        store,
        slug,
        list(reason = reason, supersedes = current@revision_id),
        author,
        recorded_at
      )
      observation <- RhoMemoryForgotten(
        revision_id = identity$revision_id,
        slug = slug,
        sequence = identity$sequence,
        recorded_at = recorded_at,
        author = author,
        supersedes_revision_id = current@revision_id,
        reason = reason,
        retracted_links = current@note@links
      )
      rho_append_memory_observation(store, observation)
    },
    label = "forget-memory"
  )
}

S7::method(rho_memory_history, RhoInMemoryMemoryStore) <- function(
  store,
  slug,
  ...
) {
  rho_task_from_function(
    function() {
      RhoMemoryHistory(
        slug = slug,
        revisions = rho_memory_revisions_for(store, slug)
      )
    },
    label = "memory-history"
  )
}

S7::method(rho_list_memory, RhoInMemoryMemoryStore) <- function(store, ...) {
  rho_task_from_function(
    function() {
      slugs <- unique(vapply(
        store@state$observations,
        rho_memory_slug,
        character(1)
      ))
      latest <- lapply(slugs, function(slug) rho_memory_latest_revision(store, slug))
      RhoMemoryIndex(
        revisions = Filter(
          function(revision) {
            S7::S7_inherits(revision, RhoMemoryContentRevision)
          },
          latest
        )
      )
    },
    label = "list-memory"
  )
}

rho_memory_note_text <- function(note, revision_id) {
  sections <- c(
    sprintf("# %s", note@title),
    if (nzchar(note@hook)) note@hook,
    note@body,
    if (length(note@tags)) sprintf("Tags: %s", paste(note@tags, collapse = ", ")),
    if (length(note@links)) {
      sprintf(
        "Links: %s",
        paste(
          vapply(
            note@links,
            function(link) sprintf("%s:%s", link@predicate, link@to),
            character(1)
          ),
          collapse = ", "
        )
      )
    },
    sprintf("Revision: %s", revision_id)
  )
  paste(sections, collapse = "\n\n")
}

S7::method(rho_memory_tool_result, RhoMemoryRemembered) <- function(result, ...) {
  rho_tool_result(
    list(rho_text(sprintf(
      "Remembered '%s' at revision %s",
      rho_memory_slug(result),
      result@revision_id
    ))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryEdited) <- function(result, ...) {
  rho_tool_result(
    list(rho_text(sprintf(
      "Edited '%s': %s supersedes %s",
      rho_memory_slug(result),
      result@revision_id,
      result@supersedes_revision_id
    ))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryForgotten) <- function(result, ...) {
  rho_tool_result(
    list(rho_text(sprintf(
      "Forgot '%s': tombstone %s supersedes %s",
      rho_memory_slug(result),
      result@revision_id,
      result@supersedes_revision_id
    ))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryFound) <- function(result, ...) {
  rho_tool_result(
    list(rho_text(rho_memory_note_text(
      result@revision@note,
      result@revision@revision_id
    ))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryAbsent) <- function(result, ...) {
  rho_tool_error_result(
    list(rho_text(sprintf("No live memory named '%s'", result@slug))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryHistory) <- function(result, ...) {
  revisions <- if (!length(result@revisions)) {
    sprintf("No revisions for '%s'", result@slug)
  } else {
    vapply(
      result@revisions,
      function(revision) {
        sprintf(
          "%d. %s by %s%s",
          revision@sequence,
          revision@revision_id,
          revision@author,
          if (S7::S7_inherits(revision, RhoMemoryForgotten)) " (forgotten)" else ""
        )
      },
      character(1)
    )
  }
  rho_tool_result(
    list(rho_text(paste(revisions, collapse = "\n"))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryIndex) <- function(result, ...) {
  revisions <- if (!length(result@revisions)) {
    "No live memories"
  } else {
    vapply(
      result@revisions,
      function(revision) {
        sprintf(
          "%s: %s [%s]",
          rho_memory_slug(revision),
          revision@note@hook,
          revision@revision_id
        )
      },
      character(1)
    )
  }
  rho_tool_result(
    list(rho_text(paste(revisions, collapse = "\n"))),
    details = list(memory = result)
  )
}

S7::method(rho_memory_tool_result, RhoMemoryErrorValue) <- function(result, ...) {
  rho_tool_error_result(
    list(rho_text(result@message)),
    details = list(memory = result)
  )
}

rho_memory_tool_task <- function(action) {
  task <- tryCatch(action(), error = function(error) error)
  if (inherits(task, "error")) {
    return(rho_task(rho_tool_error_result(
      list(rho_text(conditionMessage(task))),
      details = list(source = task)
    )))
  }
  rho_then(rho_as_task(task), rho_memory_tool_result)
}

S7::method(
  rho_execute_memory_command,
  list(RhoMemoryStore, RhoRememberMemoryCommand)
) <- function(store, command, author, ...) {
  rho_remember(store, command@note, author)
}

S7::method(
  rho_execute_memory_command,
  list(RhoMemoryStore, RhoRecallMemoryCommand)
) <- function(store, command, author, ...) {
  rho_recall(store, command@slug, command@revision_id)
}

S7::method(
  rho_execute_memory_command,
  list(RhoMemoryStore, RhoEditMemoryCommand)
) <- function(store, command, author, ...) {
  rho_edit_memory(store, command@edit, author)
}

S7::method(
  rho_execute_memory_command,
  list(RhoMemoryStore, RhoForgetMemoryCommand)
) <- function(store, command, author, ...) {
  rho_forget(
    store,
    command@slug,
    command@expected_revision_id,
    author,
    command@reason
  )
}

S7::method(
  rho_execute_memory_command,
  list(RhoMemoryStore, RhoMemoryHistoryCommand)
) <- function(store, command, author, ...) {
  rho_memory_history(store, command@slug)
}

rho_memory_note_parameters <- function() {
  list(
    type = "object",
    properties = list(
      slug = list(type = "string"),
      title = list(type = "string"),
      hook = list(type = "string"),
      body = list(type = "string"),
      tags = list(type = "array", items = list(type = "string")),
      links = list(
        type = "array",
        items = list(
          type = "object",
          properties = list(
            predicate = list(type = "string"),
            to = list(type = "string")
          ),
          required = c("predicate", "to")
        )
      ),
      sources = list(
        type = "array",
        items = list(
          type = "object",
          properties = list(
            path = list(type = "string"),
            url = list(type = "string"),
            locator = list(type = "string"),
            quote = list(type = "string")
          )
        )
      )
    ),
    required = c("slug", "title", "body")
  )
}

rho_tool_remember <- function(store, author) {
  rho_tool_spec(
    name = "remember",
    label = "Remember",
    description = paste(
      "Create a durable memory note.",
      "If the slug already has a live revision, recall it and use edit_memory."
    ),
    parameters = rho_memory_note_parameters(),
    prepare_arguments = function(arguments) {
      list(
        command = RhoRememberMemoryCommand(
          note = do.call(rho_memory_note, arguments)
        )
      )
    },
    overlap = ToolRequiresExclusiveExecution(),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_memory_tool_task(function() {
        rho_execute_memory_command(store, params[[1L]], author)
      })
    }
  )
}

rho_tool_recall <- function(store) {
  rho_tool_spec(
    name = "recall",
    label = "Recall",
    description = paste(
      "Recall the current memory revision or an explicit historical revision.",
      "The result includes the revision identifier required by edit_memory and forget."
    ),
    parameters = list(
      type = "object",
      properties = list(
        slug = list(type = "string"),
        revision_id = list(type = "string")
      ),
      required = "slug"
    ),
    prepare_arguments = function(arguments) {
      list(command = do.call(RhoRecallMemoryCommand, arguments))
    },
    overlap = ToolRequiresExclusiveExecution(),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_memory_tool_task(function() {
        rho_execute_memory_command(store, params[[1L]], "reader")
      })
    }
  )
}

rho_tool_edit_memory <- function(store, author) {
  parameters <- rho_memory_note_parameters()
  parameters$properties$expected_revision_id <- list(type = "string")
  parameters$required <- c("slug", "expected_revision_id", "title", "body")
  rho_tool_spec(
    name = "edit_memory",
    label = "Edit memory",
    description = paste(
      "Append a complete replacement that supersedes the selected memory revision.",
      "Pass the revision identifier returned by recall; stale edits are rejected."
    ),
    parameters = parameters,
    prepare_arguments = function(arguments) {
      list(command = do.call(rho_memory_replacement_command, arguments))
    },
    overlap = ToolRequiresExclusiveExecution(),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_memory_tool_task(function() {
        rho_execute_memory_command(store, params[[1L]], author)
      })
    }
  )
}

rho_tool_forget <- function(store, author) {
  rho_tool_spec(
    name = "forget",
    label = "Forget",
    description = paste(
      "Append a tombstone for a live memory without deleting its history.",
      "Pass the revision identifier returned by recall; stale requests are rejected."
    ),
    parameters = list(
      type = "object",
      properties = list(
        slug = list(type = "string"),
        expected_revision_id = list(type = "string"),
        reason = list(type = "string")
      ),
      required = c("slug", "expected_revision_id", "reason")
    ),
    prepare_arguments = function(arguments) {
      list(command = do.call(RhoForgetMemoryCommand, arguments))
    },
    overlap = ToolRequiresExclusiveExecution(),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_memory_tool_task(function() {
        rho_execute_memory_command(store, params[[1L]], author)
      })
    }
  )
}

rho_tool_memory_history <- function(store) {
  rho_tool_spec(
    name = "memory_history",
    label = "Memory history",
    description = "Return every revision of a memory note in commit order.",
    parameters = list(
      type = "object",
      properties = list(slug = list(type = "string")),
      required = "slug"
    ),
    prepare_arguments = function(arguments) {
      list(command = do.call(RhoMemoryHistoryCommand, arguments))
    },
    overlap = ToolRequiresExclusiveExecution(),
    execute = function(tool_call_id, params, signal, on_update, ctx) {
      rho_memory_tool_task(function() {
        rho_execute_memory_command(store, params[[1L]], "reader")
      })
    }
  )
}

rho_memory_tools <- function(store, author) {
  list(
    rho_tool_remember(store, author),
    rho_tool_recall(store),
    rho_tool_edit_memory(store, author),
    rho_tool_forget(store, author),
    rho_tool_memory_history(store)
  )
}
