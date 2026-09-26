# Generated from inst/tinytest/rmd/rho.coding-coding-tools.Rmd; do not edit.

library(tinytest)
library(rho)

tmp <- tempfile()
write_tool <- rho_tool_write()
read_tool <- rho_tool_read()
rho_await(rho_execute_tool(
  write_tool,
  ToolCall("1", "write", list(path = tmp, text = "hello")),
  context = NULL
))
out <- rho_await(rho_execute_tool(
  read_tool,
  ToolCall("2", "read", list(path = tmp)),
  context = NULL
))
expect_equal(out@content[[1]]@text, "hello")

shell <- rho_resolve_bash(rho_current_platform())
expect_true(
  S7::S7_inherits(shell, RhoShellConfig) ||
    S7::S7_inherits(shell, RhoShellUnavailable)
)

unavailable_unix <- rho_resolve_bash(RhoUnixPlatform(bash = character()))
expect_true(S7::S7_inherits(unavailable_unix, RhoShellUnavailable))
expect_true(grepl("Bash", unavailable_unix@message, fixed = TRUE))

fake_git_bash <- tempfile(fileext = "bash.exe")
file.create(fake_git_bash)
windows <- RhoWindowsPlatform(bash = fake_git_bash)
resolved <- rho_resolve_bash(windows)
expect_true(S7::S7_inherits(resolved, RhoBashShell))
expect_equal(resolved@executable, fake_git_bash)

missing <- rho_resolve_bash(windows, shell_path = paste0(fake_git_bash, "-missing"))
expect_true(S7::S7_inherits(missing, RhoShellUnavailable))

if (S7::S7_inherits(shell, RhoShellConfig)) {
  bash <- rho_tool_bash(shell = shell)
  success <- rho_execute_tool(
    bash,
    ToolCall("shell-1", "bash", list(command = "printf rho-shell-ok")),
    context = NULL
  )
  expect_true(rho_is_task(success))
  success <- rho_await(success, timeout = 10000)
  expect_equal(success@content[[1]]@text, "rho-shell-ok")

  failure <- rho_execute_tool(
    bash,
    ToolCall("shell-2", "bash", list(command = "printf shell-error >&2; exit 7")),
    context = NULL
  ) |>
    rho_await(timeout = 10000)
  expect_true(S7::S7_inherits(failure, ToolErrorResult))
  expect_equal(failure@details$exit_status, 7L)
  expect_true(grepl("shell-error", failure@content[[1]]@text, fixed = TRUE))
}

r_tool <- rho_tool_r()
r_task <- rho_execute_tool(
  r_tool,
  ToolCall("r-1", "r", list(code = "21L * 2L")),
  context = NULL
)

expect_true(rho_is_task(r_task))
r_result <- rho_await(r_task, timeout = 10000)
expect_true(S7::S7_inherits(r_result, ToolResult))
expect_equal(r_result@details$value, 42L)
expect_true(grepl("42", r_result@content[[1]]@text, fixed = TRUE))
expect_true(S7::S7_inherits(r_tool@overlap, ToolMayOverlap))

expression <- RhoRExpression(code = "6L * 7L")
evaluator <- RhoMiraiExpressionEvaluator(compute = NULL)
binding <- rho_bind_operation(
  evaluator,
  rho_model("fixture", "fixture"),
  expression,
  rho_context()
)
expect_true(S7::S7_inherits(expression, RhoOperation))
expect_true(S7::S7_inherits(binding, RhoREvaluationBinding))
expect_true(S7::S7_inherits(binding@handler, RhoMiraiExpressionEvaluator))
expect_true(grepl("mirai worker", binding@reason, fixed = TRUE))
bound_result <- rho_execute_operation(binding, NULL) |>
  rho_await(timeout = 10000)
expect_equal(bound_result@value, 42L)

r_failure <- rho_execute_tool(
  r_tool,
  ToolCall("r-2", "r", list(code = "stop('r-eval-failed', call. = FALSE)")),
  context = NULL
) |>
  rho_await(timeout = 10000)
expect_true(S7::S7_inherits(r_failure, ToolErrorResult))
expect_true(grepl("r-eval-failed", r_failure@content[[1]]@text, fixed = TRUE))

session <- new.env(parent = baseenv())
evaluator <- RhoCurrentSessionREvaluator(environment = session)
r_repl <- rho_tool_r(evaluator)

rho_execute_tool(
  r_repl,
  ToolCall("r-3", "r", list(code = "answer <- 41L")),
  context = NULL
) |>
  rho_await(timeout = 5000)
repl_result <- rho_execute_tool(
  r_repl,
  ToolCall("r-4", "r", list(code = "answer + 1L")),
  context = NULL
) |>
  rho_await(timeout = 5000)

expect_equal(repl_result@details$value, 42L)
expect_equal(session$answer, 41L)
expect_true(S7::S7_inherits(r_repl@overlap, ToolRequiresExclusiveExecution))

memory <- rho_in_memory_memory_store()
expect_true(s7contract::implements(memory, MemoryStore))

related <- rho_memory_link("related_to", "other-note")
derived <- rho_memory_link("derived_from", "source-note")
note <- rho_memory_note(
  slug = "project-shape",
  title = "Project shape",
  hook = "How the project is organized",
  body = "The core is provider and agent infrastructure.",
  tags = c("architecture", "rho"),
  links = list(related, derived),
  sources = list(rho_memory_source(path = "docs/architecture.md"))
)

remembered <- rho_remember(memory, note, author = "agent:fixture") |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(remembered, RhoMemoryRemembered))
expect_equal(remembered@supersedes_revision_id, "")

duplicate <- rho_remember(memory, note, author = "agent:fixture") |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(duplicate, RhoMemoryAlreadyExists))
expect_equal(duplicate@current_revision_id, remembered@revision_id)

stale <- rho_edit_memory(
  memory,
  rho_memory_replacement(
    rho_memory_note(
      slug = "project-shape",
      title = "Project shape",
      body = "stale replacement"
    ),
    "memory:project-shape:stale"
  ),
  author = "agent:fixture"
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(stale, RhoMemoryConflict))

updated_note <- rho_memory_note(
  slug = "project-shape",
  title = note@title,
  hook = note@hook,
  body = "The core is provider and agent infrastructure; bio is downstream.",
  tags = note@tags,
  links = list(related),
  sources = note@sources
)
edited <- rho_edit_memory(
  memory,
  rho_memory_replacement(updated_note, remembered@revision_id),
  author = "agent:fixture"
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(edited, RhoMemoryEdited))
expect_equal(edited@supersedes_revision_id, remembered@revision_id)
expect_identical(edited@retracted_links, list(derived))

current <- rho_recall(memory, "project-shape") |>
  rho_await(timeout = 10000L)
historical <- rho_recall(
  memory,
  "project-shape",
  revision_id = remembered@revision_id
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(current, RhoMemoryFound))
expect_true(S7::S7_inherits(historical, RhoMemoryFound))
expect_equal(current@revision@note@body, edited@note@body)
expect_equal(historical@revision@note@body, note@body)

stale_forget <- rho_forget(
  memory,
  "project-shape",
  remembered@revision_id,
  author = "agent:fixture",
  reason = "superseded guidance"
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(stale_forget, RhoMemoryConflict))

forgotten <- rho_forget(
  memory,
  "project-shape",
  edited@revision_id,
  author = "agent:fixture",
  reason = "superseded guidance"
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(forgotten, RhoMemoryForgotten))
expect_identical(forgotten@retracted_links, list(related))

absent <- rho_recall(memory, "project-shape") |>
  rho_await(timeout = 10000L)
history <- rho_memory_history(memory, "project-shape") |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(absent, RhoMemoryAbsent))
expect_equal(length(history@revisions), 3L)
expect_identical(
  vapply(history@revisions, function(revision) revision@sequence, integer(1)),
  1:3
)

recreated <- rho_remember(memory, note, author = "agent:fixture") |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(recreated, RhoMemoryRemembered))
expect_equal(recreated@supersedes_revision_id, forgotten@revision_id)

tool_memory <- rho_in_memory_memory_store()
memory_tools <- rho_memory_tools(tool_memory, author = "agent:tool")
expect_identical(
  vapply(memory_tools, function(tool) tool@name, character(1)),
  c("remember", "recall", "edit_memory", "forget", "memory_history")
)
expect_true(all(vapply(
  memory_tools,
  function(tool) S7::S7_inherits(tool@overlap, ToolRequiresExclusiveExecution),
  logical(1)
)))

remember_tool_result <- rho_execute_tool(
  memory_tools[[1L]],
  ToolCall(
    "memory-1",
    "remember",
    list(
      slug = "tool-note",
      title = "Tool note",
      body = "Created through the tool contract.",
      tags = list("tool")
    )
  ),
  context = NULL
) |>
  rho_await(timeout = 10000L)
expect_true(S7::S7_inherits(remember_tool_result, ToolResult))

recall_tool_result <- rho_execute_tool(
  memory_tools[[2L]],
  ToolCall("memory-2", "recall", list(slug = "tool-note")),
  context = NULL
) |>
  rho_await(timeout = 10000L)
expect_true(grepl("Created through", recall_tool_result@content[[1L]]@text))
expect_true(grepl("Revision:", recall_tool_result@content[[1L]]@text))

codec <- rho_json_session_codec()
usage <- ProviderUsage(
  input = 4,
  output = 2,
  cache_read = 1,
  cache_write = 0,
  total = 7,
  cost = NULL,
  provider = "fixture"
)
message <- rho_assistant_message(
  content = list(
    rho_text("persisted"),
    ToolCall(
      id = "call-1",
      name = "r",
      arguments = list(iterations = 2L, label = NA_character_)
    )
  ),
  provider = "fixture",
  model = "fixture",
  usage = usage,
  timestamp = 1
)
entry <- RhoSessionMessageEntry(
  id = "entry-1",
  timestamp = 1,
  message = message
)

document <- rho_encode_session_value(codec, entry)
expect_equal(document$kind, "semantic")
expect_equal(document$type, "session.message")
expect_false("class" %in% names(document))
json <- yyjsonr::write_json_str(
  document,
  auto_unbox = TRUE,
  null = "null",
  digits = -1L
)
expect_false(grepl("rho::", json, fixed = TRUE))
expect_false(grepl("rho::", json, fixed = TRUE))
parsed <- yyjsonr::read_json_str(
  json,
  arr_of_objs_to_df = FALSE,
  obj_of_arrs_to_df = FALSE
)
restored <- rho_decode_session_value(codec, parsed)

expect_identical(restored, entry)
expect_equal(restored@message@content[[2L]]@arguments$iterations, 2L)
expect_true(is.na(restored@message@content[[2L]]@arguments$label))

memory_message <- rho_tool_result_message(
  tool_call_id = "memory-call",
  tool_name = "remember",
  content = remember_tool_result@content,
  details = remember_tool_result@details,
  timestamp = 2
)
memory_document <- rho_encode_session_value(codec, RhoSessionMessageEntry(
  id = "memory-entry",
  timestamp = 2,
  message = memory_message
))
memory_restored <- rho_decode_session_value(codec, memory_document)
expect_identical(memory_restored@message@details, memory_message@details)

RhoFixtureSessionValue <- S7::new_class(
  "RhoFixtureSessionValue",
  properties = list(current_value = S7::class_integer)
)
fixture <- RhoFixtureSessionValue(current_value = 1L)
unsupported <- rho_encode_session_value(codec, fixture)
expect_true(S7::S7_inherits(unsupported, RhoSessionCodecErrorValue))

fixture_adapter <- rho_json_semantic_adapter(
  "fixture.value",
  RhoFixtureSessionValue,
  c(value = "current_value")
)
extended <- rho_json_session_codec(adapters = list(fixture_adapter))
extended_document <- rho_encode_session_value(
  extended,
  fixture
)
expect_equal(names(extended_document$fields), "value")
expect_identical(
  rho_decode_session_value(extended, extended_document),
  fixture
)

invalid_atomic <- rho_decode_session_value(
  codec,
  list(
    kind = "atomic",
    storage = "raw",
    length = 1L,
    values = list("999"),
    missing = list(),
    names = list(kind = "null")
  )
)
expect_true(S7::S7_inherits(invalid_atomic, RhoSessionCodecErrorValue))
expect_true(grepl("@values", invalid_atomic@details$message, fixed = TRUE))

unknown_document <- rho_decode_session_value(codec, list(kind = "future"))
expect_true(S7::S7_inherits(unknown_document, RhoSessionCodecErrorValue))

path <- tempfile(fileext = ".jsonl")
journal <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
expect_true(s7contract::implements(journal, SessionJournal))

writer <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = journal
)
first_run <- rho_prompt(writer, "before restart") |>
  rho_await(timeout = 15000L)
first_snapshot <- rho_session_snapshot(journal) |>
  rho_await(timeout = 15000L)
expect_equal(first_run@status, "completed")
expect_equal(length(readLines(path, warn = FALSE)), 3L)
header <- yyjsonr::read_json_str(
  readLines(path, n = 1L, warn = FALSE),
  arr_of_objs_to_df = FALSE,
  obj_of_arrs_to_df = FALSE
)
expect_false("version" %in% names(header))

reopened <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
reader <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = reopened
)
expect_identical(
  rho_sync_session(reader) |> rho_await(timeout = 15000L),
  reader
)
expect_equal(rho_state_messages(reader), first_run@messages)

second_run <- rho_prompt(reader, "after restart") |>
  rho_await(timeout = 15000L)
snapshot <- rho_session_snapshot(reopened) |>
  rho_await(timeout = 15000L)
expect_equal(second_run@status, "completed")
expect_equal(snapshot@position, 4L)
expect_equal(length(snapshot@entries), 4L)
expect_identical(snapshot@identity, first_snapshot@identity)
expect_equal(length(readLines(path, warn = FALSE)), 5L)
if (.Platform$OS.type == "unix") {
  expect_equal(as.character(file.info(path)$mode), "600")
}

unlink(c(path, paste0(path, ".lock")))

path <- tempfile(fileext = ".jsonl")
journal <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
writer <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = journal
)

rho_prompt(writer, "original") |> rho_await(timeout = 15000L)
original <- rho_session_snapshot(journal) |> rho_await(timeout = 15000L)
root_id <- original@entries[[1L]]@id
abandoned_id <- original@leaf_id
rho_move_session_leaf(writer, root_id) |> rho_await(timeout = 15000L)
rho_prompt(writer, "alternative") |> rho_await(timeout = 15000L)
written <- rho_session_snapshot(journal) |> rho_await(timeout = 15000L)

reopened <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
reader <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = reopened
)
rho_sync_session(reader) |> rho_await(timeout = 15000L)
replayed <- rho_session_snapshot(reopened) |> rho_await(timeout = 15000L)
trajectory <- rho_session_trajectory(replayed)

expect_identical(replayed, written)
expect_equal(replayed@position, 5L)
expect_true(S7::S7_inherits(replayed@entries[[3L]], RhoSessionLeafEntry))
expect_equal(replayed@entries[[3L]]@previous_leaf_id, abandoned_id)
expect_false(abandoned_id %in% vapply(
  trajectory@entries,
  function(entry) entry@id,
  character(1)
))
expect_equal(rho_state_messages(reader), lapply(
  Filter(
    function(entry) S7::S7_inherits(entry, RhoSessionMessageEntry),
    trajectory@entries
  ),
  function(entry) entry@message
))

unlink(c(path, paste0(path, ".lock")))

path <- tempfile(fileext = ".jsonl")
first_journal <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
second_journal <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
first <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = first_journal
)
second <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = second_journal
)

rho_sync_session(first) |> rho_await(timeout = 15000L)
rho_sync_session(second) |> rho_await(timeout = 15000L)
rho_prompt(first, "committed first") |> rho_await(timeout = 15000L)
conflicted <- rho_prompt(second, "stale writer") |>
  rho_await(timeout = 15000L)
snapshot <- rho_session_snapshot(first_journal) |>
  rho_await(timeout = 15000L)

expect_equal(conflicted@status, "error")
expect_true(S7::S7_inherits(conflicted@error, RhoSessionConflictErrorValue))
expect_equal(snapshot@position, 2L)
expect_equal(length(readLines(path, warn = FALSE)), 3L)

unlink(c(path, paste0(path, ".lock")))

path <- tempfile(fileext = ".jsonl")
journal <- rho_jsonl_session_journal(path, timeout_ms = 10000L)
agent <- rho_agent(
  rho_faux_provider(),
  rho_model("faux", "faux"),
  journal = journal
)
rho_prompt(agent, "complete record") |> rho_await(timeout = 15000L)

blank_path <- tempfile(fileext = ".jsonl")
expect_true(file.copy(path, blank_path))
connection <- file(blank_path, open = "ab")
writeBin(as.raw(10L), connection)
close(connection)

blank <- rho_session_snapshot(rho_jsonl_session_journal(blank_path)) |>
  rho_await(timeout = 15000L)
expect_true(S7::S7_inherits(blank, RhoJsonlSessionJournalErrorValue))
expect_true(grepl("empty line", blank@message, fixed = TRUE))

connection <- file(path, open = "ab")
writeBin(charToRaw("{\"schema\":"), connection)
close(connection)

corrupt <- rho_session_snapshot(journal) |> rho_await(timeout = 15000L)
expect_true(S7::S7_inherits(corrupt, RhoJsonlSessionJournalErrorValue))
expect_true(grepl("partial line", corrupt@message, fixed = TRUE))

blocked <- rho_prompt(agent, "must not append") |> rho_await(timeout = 15000L)
expect_equal(blocked@status, "error")
expect_true(S7::S7_inherits(blocked@error, RhoJsonlSessionJournalErrorValue))

unlink(c(
  path,
  paste0(path, ".lock"),
  blank_path,
  paste0(blank_path, ".lock")
))
