# Implementation status

This workspace contains package code, S7 classes and generics, async task and
stream contracts, nanonext HTTP adapters, mirai task adapters, graphics artifact
rendering, Rmd-driven tinytest specs, and provider request builders. Package API
documentation and namespaces are generated from roxygen2 tags. Air is the
authoritative formatter; the local verified version is 0.10.0.

All thirteen source packages are versioned `0.0.1.9001`, build from tarballs, and
report `Status: OK` under `R CMD check --no-manual` locally and in the R 4.4 and
R-release CI jobs. The check driver treats every NOTE, WARNING, or ERROR as a
failed monorepo gate. This establishes package health; it does not claim provider
or Pi behavioral parity.

Verified executable behavior now includes typed assistant events, repeated agent
turns, awaited listeners, steering/follow-up machinery, cancellation, typed
per-tool overlap requirements, concurrent task joining with source-order
results, real parallel mirai workers, cross-platform resolution of an actual
Bash executable, shell execution in mirai workers, isolated R expression
evaluation, an opt-in stateful current-session R evaluator, and a structural
session journal with in-memory and worker-backed JSONL implementations. The
JSONL fixtures cover semantic-record replay after restart, stable session
identity, parent-linked branches, explicit leaf movement, stale-writer
rejection, and partial-tail refusal. Its records contain stable
semantic tags and declared fields, not reflected S7 class or package names.
Provider request builders require explicit
resolved `RhoModelAuth`; they do not read API keys from process-global
environment variables. Successful login and refresh values can be retained by
the process-scoped memory store or an explicitly selected, owner-only JSON
store; both implement the same serialized credential protocol. JSON parsing and
serialization use `yyjsonr` throughout.
Semantic operations are planned separately from executable tools. OpenAI and
Anthropic web search use typed, catalog-backed provider bindings, normalize
provider activity as content, and reject unbound operations at request
translation. R expression evaluators use the same binding protocol.
Task continuations propagate cancellation to their active child. Task groups
cancel their children when cancelled or rejected, races cancel losing tasks,
and deadlines cancel their source. Derived streams preserve timeout and close
semantics, and stream collection applies one total deadline. A serial task queue
orders asynchronous mutations without blocking the R event loop or allowing a
cancelled queued entry to cancel active work. Extension handlers, provider
completion, credential refresh, and bio resolution compose tasks directly;
none performs an internal blocking wait.

Agent provider context is projected from message, compaction, and exclusion
entries held in memory. Compaction has manual and threshold triggers, open
policy and compactor methods, typed successful skips and operational failures,
lifecycle events, and one retry for typed provider input-limit values.
Each assistant usage observation records the stable request-context revision it
measured. Threshold and manual compaction account for the transformed system
prompt, transcript, tools, operations, and dynamic tool activation state; an
older provider count is reused only for the same model and context revision.
Agent run results include a `UsageSummary` that keeps provider-reported,
estimated, unavailable, and unpriced observations distinct while aggregating
tokens, cache use, and nominal API-equivalent cost.

`rho.coding` now supplies an open authored-memory port, a structural
`MemoryStore` interface, and `remember`, `recall`, `edit_memory`, `forget`, and
`memory_history` tools. The process-local implementation appends attributed
content revisions and tombstones, rejects stale edit and forget requests, keeps
historical revisions queryable, and records retracted links. A typed,
session-pinned context-contribution plan and a durable observation-store adapter
remain unimplemented.
The HTTP stream retains a configurable bounded body for non-success responses so
provider adapters can classify structured wire errors without matching message
text.

Known incomplete work, stated directly:

- `rho.ai::rho_faux_provider()` is the deterministic provider used by tests.
- OpenAI Responses/Codex, Anthropic Messages, and Ollama's OpenAI-compatible
  chat protocol have typed request and event protocols with end-to-end agent
  fixtures. External-account checks remain recorded in the parity ledger.
- Z.ai authentication is explicitly API-key based. Its
  [documented API surface](https://docs.z.ai/guides/develop/http/introduction)
  offers API-key and JWT bearer authentication, not an OAuth device grant;
  requesting OAuth therefore resolves to a typed unsupported login-method value
  without prompting or issuing a network request.
- `rho.http::rho_sse_connect()` opens the response with the pinned nanonext
  `ncurl_stream_aio()` fork and incrementally decodes arbitrary body chunks. The
  transport remains pinned while
  [nanonext issue #329](https://github.com/r-lib/nanonext/issues/329) establishes
  the upstream API; replacing the pin will require the same receive,
  cancellation, completion, and close semantics.
- `rho.http.httr2` implements complete requests with httr2 and incremental
  bodies through curl's native multi loop in a selected worker. Its fixtures
  verify response heads, incremental SSE delivery, completion, and cancellation
  without making provider code depend on httr2.
- Provider turns select typed SSE, WebSocket, cached-WebSocket, or embedded
  strategies before opening a normalized assistant-event stream. OpenAI Codex
  implements one-shot `response.create` WebSocket execution with the nanonext
  WebSocket client and the same event decoder as SSE. Cached connection reuse
  remains an explicit unsupported strategy until its lifecycle and fixtures
  exist. Embedded providers run through an explicit executor that returns a
  stream or a task resolving to one.
- `rho.duckdb` has only a lexical first-token/forbidden-keyword SQL guard. It
  accepts multiple-statement and unmodelled effect paths and must not receive
  untrusted SQL; parser-backed statement plus relation/path capability admission
  is tracked in issue #7.
- The Bash tool currently returns complete combined output. Pi-equivalent
  incremental output updates, bounded tail retention, and persisted full-output
  artifacts remain explicit coding-agent parity work.
- `RhoMiraiExpressionEvaluator` gives isolated worker evaluation.
  `RhoCurrentSessionREvaluator` preserves state only in the environment supplied
  by its caller and requires exclusive execution.
- `rho_task_from_function()` defers an R closure but does not move blocking work
  out of the main R process. Credential-file reads, coding filesystem tools, and
  DuckDB calls still need explicit compute bindings where they may block.
  `rho_resolve_resource()` currently invokes its resolver before returning a
  task, which is a stronger effect-contract violation tracked in issue #8.
- `RhoFileCredentialStore` remains plaintext JSON with owner-only permissions
  for explicit development use. `RhoEncryptedFileCredentialStore` supplies
  Argon2id/XChaCha20-Poly1305 portable storage, and
  `RhoKeychainCredentialStore` supplies native keychain storage while rejecting
  environment and keyring-file backends. Durable file stores serialize access
  within one R process; a cross-process file lock remains work.
- The coding-host JSONL session journal detects a partial final record and
  refuses further mutation. It does not yet repair that record, establish
  storage synchronization beyond a flushed R connection, expose incremental or
  remote cursors, or provide Pi-format import and export.
- The authored-memory reference store is process-local. A DuckDB/NNG adapter,
  as-of time queries, graph walks, and a pinned prompt-index contribution remain
  downstream work; the tools do not silently add note bodies to the system
  prompt.
- `rho.ext` is a standalone string-keyed registry/dispatcher and is not bound to
  `rho.agent`. `rho.bio.agent` registers only one manifest-listing tool and does
  not resolve, query, retain receipts, or project a ledger. Issue #9 requires a
  real typed lifecycle slice or removal of the dormant surface.
- Coding read/write tools use the host user's ordinary paths and Bash inherits
  the current process environment by default. Secret-bearing model-auth and HTTP
  request values also print their contents. Explicit capability admission and
  secret-safe representation are tracked in issue #11.
- Graphics, tool output, and bio resources do not yet share an artifact store.
- `rho.compute` does not yet model pool lifecycle, placement, affinity, bounded
  queues, or remote execution receipts.

The parity ledger records provider and agent-core behavior. It is not a claim
that every durability, execution-placement, coding-tool, or downstream bio-agent
refinement is complete.
