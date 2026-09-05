# Architecture

Rho has an acyclic package graph and asynchronous effects.

```text
rho.async -> rho.http -> rho.ai -> rho.agent -> rho.coding
rho.ai -> rho.ext -> rho.bio.agent
rho.async -> rho.compute -> rho.graphics
rho.http + rho.compute -> rho.http.httr2
rho.compute -> rho.coding
rho.async -> rho.bio -> rho.duckdb
```

This is the current DESCRIPTION dependency graph. `rho.ext` is not yet bound to
`rho.agent`, and `rho.bio.agent` does not yet consume `rho.duckdb`; that missing
integration is tracked in [issue #9](https://github.com/RGenomicsETL/Rho/issues/9)
rather than shown here as implemented architecture.

The central rule is that effectful public APIs return `RhoTask` or `RhoStream`.
Synchronous waiting is explicit through `rho.async::rho_await()` and test helpers.

## Functional OOP contracts

Ordinary S7 generics and methods own dispatch. Semantic alternatives are class
values rather than strings interpreted by a central manager. Reusable field
constraints are S7 properties attached directly to class definitions, so
constructors and helper predicates do not repeat validation or invent competing
error messages.

`s7contract` interfaces bundle the generics required by a consumer. They are
structural: an implementation satisfies an interface through its ordinary S7
methods and does not join another inheritance hierarchy. Interfaces are small
and defined from the consuming side, such as `HttpClient`, `Provider`, `Tool`,
`CredentialStore`, and `AgentPolicy`. Progressive argument and return contracts
are applied at important package and asynchronous boundaries. Explicit traits
are reserved for a demonstrated need for opt-in conformance, default methods,
or associated metadata.

The detailed design and the distinction between properties, interfaces,
traits, and progressive checks are in
[Functional OOP in R](https://github.com/RGenomicsETL/Rho/blob/main/dev-notes/design/functional-oop.md).

## Tool scheduling and execution

Agent scheduling does not decide where code runs. `rho.agent` opens tool tasks,
joins them, emits lifecycle events, and returns results in source order. Each
`ToolSpec` carries a typed overlap value:

- `ToolMayOverlap` permits the agent to start the call beside other calls.
- `ToolRequiresExclusiveExecution` makes the batch serial.

`rho_tool_overlap()` is a generic, so a specialized tool may derive the value
from the call or its context. A tool then chooses the backend that realizes its
task. Network tools may return nanonext-backed tasks, CPU or blocking R work may
return `rho.compute` mirai tasks, and already available values may return
immediate tasks. `rho.agent` neither imports mirai nor moves work between
backends implicitly.

The distinction matters: two main-session tasks can be concurrent without
executing R bytecode in parallel. True R-process parallelism comes from the
tool-selected mirai compute profile. Compute-profile size and placement remain
deployment decisions.

Worker selection is represented by values rather than inferred from an R
expression. `RhoComputeExpressionSpec` carries quoted code plus explicitly named
arguments. `RhoComputeCallSpec` carries a worker function plus explicitly named
arguments. `rho_submit_compute()` dispatches on both the backend and the spec;
higher packages use `rho_mirai_eval()` or `rho_mirai_call()` and do not inject
temporary globals into a worker expression. Results cross the mirai promise
bridge in a success envelope so language objects remain values, while worker
failures resolve to typed `RhoComputeErrorValue` objects.

## Shell and R evaluation

The coding shell keeps Bash-compatible command semantics on every platform.
On Unix it selects Bash when available and records an explicit POSIX-shell
alternative when Bash is absent. On Windows it selects a configured Bash, Git
Bash, or Bash found on `PATH`; it does not reinterpret a Bash command through
`cmd.exe`. Legacy WSL Bash uses stdin command transport. Shell processes run in
a mirai worker through `rho.compute`, with `processx` handling argument passing,
timeouts, UTF-8 output, and process-tree cleanup.

R evaluation has two deliberately different values:

- `RhoMiraiExpressionEvaluator` evaluates an isolated expression asynchronously
  and may run in parallel according to its compute profile.
- `RhoCurrentSessionREvaluator` evaluates in an explicitly supplied environment,
  preserves that environment across calls, and requires exclusive scheduling.

A pool of interchangeable mirai daemons is not a persistent REPL. Persistent
daemon-global setup uses a separate mirai contract and must state its routing
and lifetime semantics.

## Open provider protocols

Rho normalizes requests for behavior, not provider wire formats. Stable questions
are S7 generics with broad, explicit default methods. Provider/API classes add
narrower methods only for verified behavior, and extension packages may add still
narrower methods without editing the agent loop.

HTTP implementation and provider-turn execution are separate protocols.
`rho.http::HttpClient` owns complete HTTP requests and incremental response
bodies; nanonext and the worker-owned httr2 adapter implement the same methods.
`rho.ai::rho_stream()` owns the normalized assistant-event result. Its default
method selects a typed `ProviderTransport` implemented by both the provider and
model, then dispatches through `rho_open_provider_transport()`. SSE, WebSocket,
cached WebSocket, and embedded execution are distinct values. An in-process model
uses `RhoEmbeddedProvider` with an explicit `EmbeddedExecutor`; it does not
construct an HTTP request. An executor returns a `RhoStream` or a
`RhoTask<RhoStream>`, so an embedded R object, a native engine, and a remote
relay can share provider semantics without sharing an I/O implementation.
The selection is a typed value with a reason, while an unavailable explicit
choice resolves through `ProviderTransportUnsupported`.

Provider token reports become `Usage` values before entering the agent. Input,
cache-read, cache-write, and output counts are disjoint; reasoning and one-hour
cache writes are typed subsets of their parent counts. `rho_price_usage()` applies
the model catalog's component rates and long-context tiers through S7 dispatch.
`rho_summarize_usage()` retains the original `ProviderUsage`, `EstimatedUsage`,
and `UsageUnavailable` values while calculating session totals, cache-hit
proportion, and nominal cost. Its completeness properties prevent an absent
subscription usage block from appearing as a measured zero.

Provider request bodies are composed from `ProviderRequestSection` values, with
OpenAI and Anthropic subclasses for their wire dialects. The standard OpenAI,
Codex, and Copilot model subclasses select OpenAI sections through
`rho_openai_request_sections()`; Anthropic models select sections through
`rho_anthropic_request_sections()`. Wire names are emitted only by
`rho_request_fields()` methods, so extensions can replace one policy or append
a section without copying a complete request builder.

`AnthropicMessagesEndpoint` separates Messages semantics from endpoint auth and
transport. Anthropic and GitHub Copilot share content translation, request
sections, and typed stream reduction while implementing different endpoint
methods. Model capability profiles select adaptive or budget thinking,
temperature acceptance, cache retention, tool-input streaming, and hosted
operation dialects without request-time model-name tests.

`ToolSpec` and `RhoOperation` are deliberately different. A `ToolSpec` names
host code that the agent may execute after receiving a `ToolCall`.
`RhoOperation` states a semantic capability requested by the conversation.
`rho_plan_operations()` asks a handler to bind each operation for the selected
model; every `RhoOperationBinding` records that handler and the reason for its
selection. An OpenAI or Anthropic web-search binding is translated into a
provider-hosted tool declaration. Its response becomes typed content and
operation lifecycle events, never an executable local `ToolCall`.

Bindings are the override point. A context may carry a binding supplied by an
extension or host, while an unbound operation must pass through
`rho_plan_operations()`. Low-level request translation returns a typed
configuration error when handed an unbound semantic operation. The same
protocol applies outside providers: `rho.coding` binds an `RhoRExpression` to a
current-session or mirai evaluator, and a remote NNG evaluator can implement
the same methods without changing the agent loop.

For dynamic tools, `ToolResultMessage@added_tool_names` is the portable transcript
fact. `rho_plan_tools()` returns one of these successful plans:

- `RhoFullToolPlacement`: advertise every active definition at the request
  request and state whether that may replace the cached prefix.
- `RhoOpenAIToolSearchPlacement`: put newly activated definitions into completed
  client tool-search items at the recorded tool-result position.
- `RhoAnthropicToolReferencePlacement`: defer definitions and expose references at
  the recorded tool-result position.

The complete-placement plan is not an error: all requested tools remain available.
Only the cache optimization differs. Provider support is queried through typed
operation values and `rho_provider_support()` instead of a universal boolean map.

## Session compaction

Session compaction belongs to the agent harness. A provider-native compaction
primitive is one possible binding of that semantic operation, not the owner of
the policy.

`rho.ai` defines `RhoCompactionOperation`, the provider-binding point, and typed
unsupported defaults. `rho.agent` owns the session-entry protocol, stable cut
point, semantic summary entry, threshold trigger, provider-input recovery, and
before/after policy methods. The agent closes over a structural `SessionJournal`
supplied by the host. The shipped implementation is process-local memory with
compare-and-append and full snapshots. A stale writer fails before mutation,
and an idle agent may asynchronously synchronize an existing snapshot into the
committed projection used for context and compaction. An application may
provide another compactor or specialize the public generics without replacing
the loop. A provider-encrypted item is an input optimization, not a durable
semantic summary.

Compaction transforms only the selected session trajectory. It retains the
original entries and commits a new node containing the semantic summary and the
first retained entry identity. Base instructions and context contributions such
as a session-pinned memory index are composed separately and are not summarized
or refreshed by compaction. Recalled memory already present as a tool result is
ordinary transcript and may be represented in the summary.

The coding host owns the first authored-memory implementation. Its open
`MemoryStore` interface is implemented by a process-local append-only store;
typed commands drive `remember`, `recall`, `edit_memory`, `forget`, and history
tools. A remembered note creates a revision, an edit is a complete replacement
that names the revision it supersedes, and forgetting appends a tombstone. A
stale expected revision resolves to `RhoMemoryConflict`. Historical revisions
and retracted graph links remain visible in receipts.

The remaining open agent contract is a context-contribution generic whose
implementations return typed, receipted contributions. Provider request methods
will lower the resulting pinned context plan. Extensions add implementations
through S7 methods rather than mutating a system-prompt string through
event-name conditionals.

## Session persistence and extension projections

The authoritative conversation is a logical append-only agent session. A
host-selected journal persists its typed entries and exposes stable session
identity, lineage, committed cursors, optional snapshots, and lifecycle events.
The agent substrate depends only on that protocol. Memory, JSONL, a database,
or an NNG-owned service may implement it. JSONL is one coding-host adapter, not
the definition of durability.

The first exercised journal contract is deliberately smaller: a typed
compare-and-append request and a full snapshot. The in-memory implementation
returns typed commits and snapshots. The coding-host JSONL implementation uses
the same methods, stable semantic records, locked compare-and-append
in a worker, and strict partial-tail detection. Explicit adapters translate
between wire records and current S7 classes; the file contains neither package
names nor reflected class properties. Journal
failure remains an operational value. Assistant partials stay inside the active
turn; only a terminal assistant message is appended. Reset is also an entry, so
it begins a new active context without deleting prior history. Snapshot
synchronization rebuilds an idle agent's projection; partial-tail recovery,
storage synchronization, branch identity, and remote cursors remain refinements
rather than methods added in anticipation.

The schema and extension rules are specified in the
[Rho JSONL session schema](session-jsonl-schema.md).

Rho's JSONL schema is not Pi's session JSONL schema. Both carry session identity
and parent-linked entry trees, but Rho uses stable semantic record tags and
explicit leaf-movement records under its own schema. A Pi interoperability codec
may translate these representations; the native codec does not silently erase
either model's lineage or selection semantics.

Extensions consume the same session lifecycle. They may append typed custom
entries or derive another representation from committed entries, a cursor, or
a snapshot. A derived representation is not a replacement session journal. In
particular, `rho.bio.agent` may retain immutable payloads in CAS and project
messages, tool calls, artifacts, and lineage into DuckDB. That projection must
be idempotent and rebuildable from the authoritative session after a lock,
connection loss, or database-owner restart.

CAS and the journal have different jobs. CAS establishes the identity of
immutable bytes. Session order, blackboard notes, jobs, leases, and observations
are changing coordination facts and remain behind their own open protocols.
Sub-agents and remote workers may share those capabilities over NNG without
sharing a filesystem or moving topology policy into the agent loop. The
current synthesis and unresolved proofs are recorded in
[Current synthesis](synthesis.html) and [Refinements](refinements.html).

## Authentication

Credentials are effects supplied through an explicit `CredentialStore`; provider
implementations do not read API keys from environment variables. Login and token
refresh are open auth generics. Resolution produces a typed `RhoModelAuth` value
that is passed to request translation in `options$auth`. A provider implementation
contains transport configuration, never ambient process credentials. Concurrent
refresh is serialized by the credential-store queue and publishes the refreshed
credential back to that store before another request resolves auth.

The process-scoped memory store, durable plaintext-file store, encrypted-file
store, and operating-system keychain store implement the same protocol. The
file stores are opt-in through explicit paths, persist login and rotated refresh
credentials, replace their document, and request `0600` permissions. The
encrypted store accepts an explicit passphrase or 32-byte key and authenticates
the complete credential document. The keychain store accepts native keyring
backends only; it rejects environment and keyring-file backends. Neither choice
changes provider or agent-loop semantics.

## Interactive safe points and presentation

The optional `rho.async` task-callback bridge drains already-ready
`later`/promise notifications after top-level R expressions. It never waits and
is not registered during package loading. Native graphics windows, terminal
renderers, and desktop toolkits own their presentation lifecycle without taking
over provider or agent scheduling.

Candidate R-native presentation and secure-storage components, together with
their package responsibilities, are recorded in
[R-native interaction and secure storage](https://rgenomicsetl.github.io/Rho/docs/r-native-runtime.html).

## Publication gate

Development is public and remains experimental while execution, extension,
artifact, and downstream application contracts are incomplete. The verified
provider and agent-core rows are recorded separately in the parity ledger. A
tagged release follows only after the declared release scope is satisfied, every
package installs and checks on supported platforms, required live provider
checks pass without stored credentials, generated documentation is current,
and a secret scan is clean. R-universe inclusion is release distribution, not a
substitute for those checks.
