# Rho roadmap

Rho has a working provider and agent substrate. The next work is to make its
execution and transport semantics as complete as its provider surface, while
keeping storage engines and application policy downstream. This roadmap orders
that work; [the parity ledger](docs/pi-parity.md) records only behavior already
supported by an executable fixture.

## Current foundation

- The `rho` package is version `0.0.1.9001`; its components share one namespace
  and one package check.
- Its async, HTTP, provider, and agent components provide the task, stream,
  provider, and multi-turn agent contracts.
- OpenAI, OpenAI Codex, GitHub Copilot, Anthropic, Z.ai, Kimi Code, Kimi
  Platform, Ollama, and the deterministic faux provider use the same normalized
  assistant-event stream.
- HTTP clients dispatch through `rho_http_send()` and
  `rho_http_open_stream()`. The nanonext and httr2 implementations can be
  selected without changing provider code.
- The nanonext client also implements typed WebSocket connection and duplex
  contracts. OpenAI Codex uses its one-shot `response.create` WebSocket
  transport or SSE according to an explicit transport selection; an embedded
  provider runs through an explicit executor without an HTTP request.
- `rho_http_open_execution()` records Aio, worker, or caller-process response
  opening as typed values. Both shipped implementations run the same installed
  client contract for fixed, chunked, and connection-delimited bodies, one-byte
  reads, end-of-stream, cancellation, timeout, truncated bodies, bounded
  errors, and repeated close.
- Typed operations separate a semantic request from its local, provider-hosted,
  extension, worker, or remote implementation.
- `rho.agent` closes over the structural `SessionJournal` interface. Its
  in-memory implementation proves compare-and-append, snapshot synchronization,
  typed failure, stable identity, parent-linked branches, explicit leaf
  movement, terminal-only assistant entries, and reset without erasing journal
  history.
- `rho.coding` implements that interface as locked, worker-backed JSONL. Its
  fixtures prove lossless semantic-entry and selected-branch replay after
  restart, stale-writer rejection, and refusal to read or append after a partial
  final record. Explicit adapters isolate the wire schema from the
  current S7 class layout.
- `rho.coding` also provides the structural `MemoryStore` interface and typed
  `remember`, `recall`, `edit_memory`, `forget`, and `memory_history` tools. Its
  reference store keeps append-only attributed revisions and tombstones, and
  uses expected revision identity to reject stale mutation.
- Agent usage summaries preserve reported, estimated, unavailable, and unpriced
  observations. Context-window accounting covers the transformed prompt,
  transcript, tools, operations, and activation state under a stable request
  revision.

## 1. Publication integrity

- Register `rho.http.httr2` beside the other twelve packages in the
  RGenomicsETL R-universe manifest, then require successful builds in
  dependency order.
- Keep every package README, reference site, `NEWS.md`, lifecycle badge, and
  package link reproducible from the checkout.
- Make the package check, publication check, parity ledger, generated-file
  check, model-catalog check, and secret scan required release evidence.
- Correct any ledger wording that implies durable state before a durable journal
  implementation exists. In-memory compaction and durable replay are different
  features.

## 2. Transport correctness

- Continue using the nanonext fork while
  [nanonext issue #329](https://github.com/r-lib/nanonext/issues/329) defines the
  upstream incremental-response API. The proposed shape and the remaining
  questions are recorded in
  [the HTTP streaming design note](docs/nanonext-http-streaming.md).
- Preserve `rho.http.httr2` as an independent implementation of the same HTTP
  client interface. It is also the executable alternative when opening a
  nanonext response remains synchronous.
- The nanonext transport fixture uses a raw local peer to distinguish a
  connection-delimited body, which ends normally, from a premature close before
  the declared `Content-Length`, which yields a typed transport error after
  already received bytes. It also verifies that a malformed chunked body is
  reported as a typed transport error after its successful response head.
- Keep response opening explicit through `rho_http_open_execution()`. The
  nanonext fork declares cancellable Aio opening, httr2 declares worker opening,
  and an implementation without an asynchronous method receives the explicit
  caller-process default with its reason.

## 3. Durable sessions and artifacts

- Keep only the open storage protocols in the provider and agent substrate.
  Filesystem layouts, content-addressed storage, database schemas, retention,
  and provenance policy belong to downstream implementations.
- Extend the open `SessionJournal` interface from its exercised typed append
  request and snapshot methods to cursors and branching only as those consumers
  land. The agent receives a journal explicitly; it does not construct a
  filesystem layout.
- Keep the in-memory implementation for embedding and the exercised JSONL
  implementation as one coding-host adapter. Exercise the same contract through
  an NNG-owned service before treating any method set or deployment topology as
  settled. Provider and bio packages do not learn filesystem session layouts.
- Keep the defined atomic append and leaf-movement rules independent of a file
  or database implementation. The JSONL adapter proves compare-and-append
  across independent writers in one host. It deliberately detects and refuses
  a torn final record; it does not yet claim recovery or `fsync()` durability.
- Rho JSONL is not Pi JSONL. Both have session identity and parent-linked trees,
  but Rho uses stable semantic records and explicit leaf-movement
  records. Add Pi import/export as a separate codec rather than conditionals in
  the native journal.
- Emit typed session-start, compaction, switch/fork, and shutdown events only
  after the corresponding session mutation commits. Extension handlers receive
  the session identity, lineage, committed sequence, and a journal cursor or
  snapshot capability; shutdown awaits their required flush work.
- Make compaction write an ordinary typed session entry through that interface.
  Keep provider-native compaction, extension compaction, and the default Rho
  compactor as dispatchable implementations.
- Keep the authored-memory generics and typed tool commands independent of the
  process-local reference store. Implement a durable DuckDB/NNG observation
  adapter and derive a small agent-level context-contribution generic. Pin that
  composed plan for a run; compaction already summarizes only transcript while
  accounting for the complete transformed request and its plan revision.
- Define the minimal artifact-reference and admission protocols shared by
  graphics, tool output, and bio resources. Concrete stores remain optional
  downstream packages. Content hashes identify immutable bytes; metadata and
  provenance remain typed values.
- Resolve [oversized tool results](https://github.com/RGenomicsETL/Rho/issues/3)
  by storing the complete result and returning a bounded model-facing view with
  an artifact reference.
- Compare the resulting dependency and invalidation semantics with `targets`
  before adding a scheduler or another content-addressed store. Rho should reuse
  an R-native implementation when it already supplies the required semantics.

## 4. Compute and remote execution

- Extend `rho.compute` with explicit pool creation and shutdown, queue limits,
  worker placement, affinity, cancellation, and execution receipts.
- Let a tool or operation select current-session R, an isolated mirai worker, a
  persistent worker, or a remote NNG endpoint through typed bindings. The agent
  schedules tasks but does not choose a worker on the tool's behalf.
- Preserve source-order results while allowing genuinely independent calls to
  run concurrently.
- Replace the Boolean tool-overlap decision with typed resource claims. Calls
  may overlap only when their declared resources and access modes are
  compatible; unrelated calls should not be serialized merely because one tool
  can also write a database.
- Move credential-file access, coding filesystem operations, and long DuckDB
  work off the main R process when their selected implementation can block.
- Add remote execution fixtures that cover disconnects, cancellation, repeated
  delivery, and receipt verification before the bio agent depends on them.
- Exercise a blackboard port with both environment/condition-variable and
  remote NNG or SQL implementations. A Fugu-shaped worker receives only its
  declared upstream notes and resources; no multi-agent scheduler enters core
  merely to produce that topology.

## 5. Coding-agent completeness

- Stream Bash and R tool updates, retain a bounded recent tail, and persist the
  complete output through the artifact store.
- Resolve Bash explicitly on every supported platform and report the selected
  executable. Do not translate Bash syntax into another shell language.
- Implement [portable typed text search](https://github.com/RGenomicsETL/Rho/issues/4)
  with a native R implementation and an explicitly selected external engine
  where available.
- Complete file, edit, search, and process tools with typed operational results,
  cancellation, size limits, and path policy supplied through tool context.
- Keep current-session R evaluation explicit and exclusive; keep ordinary
  mirai evaluation isolated. Persistent and remote R sessions become separate
  evaluator classes rather than modes encoded as strings.

## 6. Provider and agent completion

- Bind `rho.ext` to an agent explicitly from the host. Registered tools enter
  that agent, lifecycle handlers receive typed event values, context and tool
  decisions compose through the corresponding agent generics, and extension
  entries append through the selected session journal. The extension runtime does
  not maintain a second transcript or infer lifecycle from string event names.
- Define event-specific delivery rules: context and policy decisions are
  awaited before the run proceeds, committed-session notifications are ordered,
  and shutdown awaits required projection and cleanup work. Observational work
  that may lag carries an explicit queue and flush contract.
- Add native Ollama NDJSON decoding instead of relying on an SSE-shaped path.
- Exercise image input for each catalog profile that declares image support and
  reject unsupported content before request transmission.
- Complete WebSocket request reuse and cache-preserving dynamic tool changes for
  providers that declare those capabilities.
- Keep provider-hosted web search, compaction, and future operations as typed
  bindings. A host, extension, provider, or remote service may implement the
  same semantic operation through S7 methods.
- Add durable-session recovery, oversized-result continuation, and transport
  interruption to the agent fixtures.

## 7. Downstream R applications

- Derive opt-in tools from installed R packages through typed package catalogs.
  S7 contracts are the primary schema; function formals and package
  documentation supplement them. A catalog declares the package, selected
  exports, execution placement, and authority. It never advertises every
  installed export implicitly or converts returned R objects to console text.
- Let `rho.bio.agent` specialize those catalogs for bioinformatics packages,
  manifests, and operations. `rho.agent` continues to see ordinary tools and
  operations; it does not acquire package discovery or bio-specific behavior.
- Finish the downstream artifact implementation before expanding
  `rho.graphics` into previews, comparison, alternative text, and interactive
  display.
- Build an R-native terminal interface as a client of agent events, not as agent
  policy. Graphics display and user input remain replaceable interfaces.
- Re-implement `pi-bio-agent` as the first demanding downstream application of
  the session, artifact, compute, and operation protocols. Use R-native
  relational composition, DuckDB, mirai, NNG, and `targets` where their
  semantics fit; do not move its ledger, CAS, resolver, or durability policy
  into the agent substrate.
- Follow `pi-bio-agent`'s extension composition: the authoritative agent session
  remains in the host session journal. At committed session lifecycle events,
  `rho.bio.agent` retains a snapshot in CAS and idempotently projects messages,
  tool calls, artifacts, and lineage into its DuckDB ledger. The projection is
  rebuildable and a failed projection never corrupts or replaces the session.
- Correct DuckDB ownership before putting a durable bio ledger on it. One owner
  process creates one database instance per canonical file and derives its
  connections from that instance. Schema initialization is serialized per
  store. Multiple processes do not independently write the same local file;
  they use one remote owner or receive a typed busy result before persistence.
- Cover the failure reported in
  [pi-bio-agent issue #3](https://github.com/sounkou-bioinfo/pi-bio-agent/issues/3):
  concurrent calls must not publish a successful run before its ledger receipt
  commits, a native DuckDB or extension version mismatch must be rejected before
  opening the store, and a database-owner crash must not corrupt the agent
  process or turn a partially persisted run into success.
- Treat DuckDB extension ABI support as its own release concern: build against
  declared DuckDB header versions, select an exact compatible artifact at
  runtime, carry documented patches only where needed, and test each supported
  ABI.

## Release evidence

A roadmap item is complete only when its public behavior has documentation and
an executable fixture. A release candidate must also satisfy:

- every package reports `Status: OK` under the supported R versions;
- the complete R-universe package set builds in dependency order;
- live account exercises and deterministic wire fixtures agree on normalized
  provider behavior;
- cancellation and end-of-stream tests pass for every advertised transport;
- session recovery and artifact integrity survive a killed process;
- generated files, documentation, model data, and repository history pass the
  publication checks.
