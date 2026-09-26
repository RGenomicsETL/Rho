# Refinements

This is a pressure ledger, not a feature queue. A refinement enters the Rho
substrate only when a current provider, host, extension, or downstream
application cannot express the behavior through S7 dispatch, explicit
capabilities, tasks and streams, resolvers, execution bindings, session
journals, CAS references, or a coordination port.

## Current pressure

### Session ownership across topologies

The agent now closes over the structural `SessionJournal` interface. The
in-memory implementation proves compare-and-append, full snapshots, typed
journal failure, terminal-only assistant entries, and reset as an append-only
entry. The coding-host JSONL implementation runs reads, locking, validation,
and append in mirai workers. An idle agent can asynchronously synchronize either
implementation. Its committed process-local projection then drives context and
compaction.

Compare-and-append supplies the first concurrency rule: a writer presents its
known committed position, and the journal rejects a stale position before
mutation. This prevents a process-local agent from discovering divergence only
after an external journal has already accepted its entry. Session nodes now
carry parent identity, explicit leaf-movement records select a branch, and a
trajectory projection follows one root-to-leaf path without erasing abandoned
work. Incremental cursors and durable recovery remain unproven.

The JSONL fixtures prove replay after restart, rejection of a stale writer,
branch selection after restart, and strict detection of a partial final line.
Detection is not repair: the adapter refuses further mutation until the file
is repaired by an explicit host policy. It does not prove remote ownership,
`fsync()` durability, incremental delivery, or sub-agent composition.

The first value codec reflected reachable S7 classes and wrote
`package::Class` plus every current property. That made ordinary R refactoring
an accidental storage migration and is rejected. The current codec registers
explicit semantic adapters. Each adapter owns a stable wire tag, stable field
names, and a mapping to current S7 properties; a test maps wire field `value`
to an in-memory property named `current_value`. Unknown S7 objects fail closed.

The native JSONL schema is not Pi's version-3 session schema. Both now store a
session header and an ID-linked entry tree, but Rho's records use
stable semantic tags and explicit leaf movements under Rho's own schema. S7
class names and reflected property layouts are not part of that format.
Interoperability belongs in a Pi codec, not in conditionals inside the native
codec. A trajectory exporter may choose one branch for training; an archival
export must retain the whole tree and leaf-movement audit records.

Do not make a path part of the agent contract. First exercise committed append,
ordered read, cursor/watermark, branch lineage, flush, and close through an
in-memory adapter, a JSONL adapter, and an NNG-owned adapter. Extension delivery
must carry session identity and committed position rather than inviting an
extension to inspect a file.

Evidence required: disconnect, duplicate-delivery, cancellation, and
resumed-cursor fixtures for NNG; the same agent and extension tests against all
adapters. JSONL still needs an explicit recovery policy and a durability test
that can distinguish a flushed R connection from storage synchronization.

Current evidence: the
[`SessionJournal` interface](https://github.com/RGenomicsETL/Rho/blob/main/R/rho.agent-04-interfaces.R),
[in-memory implementation](https://github.com/RGenomicsETL/Rho/blob/main/R/rho.agent-06-session.R),
[JSONL implementation](https://github.com/RGenomicsETL/Rho/blob/main/R/rho.coding-03-session-jsonl.R),
[authored in-memory fixture](https://github.com/RGenomicsETL/Rho/blob/main/inst/tinytest/rmd/rho.agent-agent-loop.Rmd),
and [authored JSONL fixture](https://github.com/RGenomicsETL/Rho/blob/main/inst/tinytest/rmd/rho.coding-coding-tools.Rmd).

### Immutable content versus changing state

Tool output, graphics, model attachments, resource snapshots, and session
snapshots may be large immutable byte products. They fit CAS. Session ordering,
job status, leases, compaction, blackboard notes, and observation revisions do
not.

Keep CAS references in typed session or run entries. Put mutable coordination
behind its own port. Shared CAS reuse needs explicit roots or leases before
garbage collection can be claimed safe.

Evidence required: oversized tool-result round trip; downstream projection
rebuilt from journal entries and CAS bytes; concurrent read versus collection
fixture for any shared CAS implementation.

### Authored memory and prompt layers

Agent-authored memory belongs to a temporal observation port. A successful
write produces a receipt that can be linked to the originating session tool
call; it does not append an invisible message or rewrite the base system
prompt. A bounded memory index may be selected for a turn, while complete note
bodies enter context through explicit recall or graph queries.

`pi-bio-agent` proves the usefulness of this two-stage retrieval, but its
current adapter concatenates the index onto a system-prompt string and omits it
when the store is unavailable. Rho needs explicit semantics before adopting
that behavior: base prompt, extension orientation, and dynamic memory layers
carry distinct authority; a dynamic layer records its as-of instant, selected
revision ids, limit, and digest; unavailable memory resolves to a typed policy
decision whose continuation rule is supplied by the host.

Cache preservation adds a second constraint. Base prompt and stable extension
orientation precede a deterministically rendered memory index pinned to one
revision set. A memory write does not rewrite that prefix during an active run.
Complete recalled notes enter as late tool results. A provider may map these
semantics to automatic prefix caching or explicit cache-control blocks through
dispatch, while a provider without cache controls receives the same prompt
meaning. Cache receipts and usage counts measure that lowering; they do not
choose which memory is visible.

The first implementation now lives in `rho.coding`. `MemoryStore` is a small
structural interface over open S7 generics. The reference implementation and
typed tool commands distinguish create, complete compare-and-supersede,
tombstone, current recall, and ordered history. Dropped links are explicit in
edit and forget receipts. The next movement is a smaller `rho.agent`
context-contribution generic so another host or extension can provide a memory
source without replacing the loop. The current whole-context transform remains
useful as lifecycle orchestration, but is too permissive to be the durable
memory contract.

Compaction supplied the immediate counterexample to message-only accounting.
It now evaluates the transformed `Context` and includes the system prompt,
tools, operations, activation state, and transcript. Each assistant usage
observation records the request-context revision it measured; a model, prompt,
tool, operation, or activation change invalidates that count and causes a full
estimate. A future pinned contribution participates in the same revision
without changing the accounting rule.

Current evidence: the authored memory fixture exercises create, duplicate
rejection, stale conflict, superseding edit, historical recall, dropped-link
retraction, tombstone, recreation, typed tools, and session-codec retention.
The compaction fixture proves complete request accounting and invalidation when
the stable request revision changes.

Evidence still required: one complete agent-authored note flow linked to its
tool call and journal entry; live-current and session-pinned index policies producing different declared
receipts; full recall entering the transcript only through a tool result; and a
store-unavailable fixture that exercises both continue-without-memory and
require-memory host policies without hidden omission. Repeated requests with a
pinned index must produce identical prefix bytes, while an explicit refresh
must change the rendered digest and the declared cache expectation. A
compaction fixture must keep the pinned index unchanged, preserve the original
memory receipt in the journal, and account for the complete prompt plan while
summarizing transcript entries only.

### Lazy resolver forcing

R promises and active bindings can make virtual resources natural to use, but
they can also conceal blocking I/O. A virtual resource must retain a
serializable specification and an explicit resolution context. Forcing begins
or returns a `RhoTask`; only a declared wait operation obtains the value.

The executable resolver may be an S7 method or closure over injected
capabilities. Its captured environment is not durable identity. Memoization in
one R process is not evidence that a cached materialization is current.

Evidence required: a resource referenced twice resolves once in one context;
cancellation propagates during forcing; a changed source receipt prevents stale
CAS reuse; no active binding calls `rho_await()`.

### Remote and recursive execution

Current-session R and mirai workers cover two placements. The same operation
shape should admit a persistent R kernel, a remote NNG worker, an embedded
model, or a recursively invoked Rho agent without a type switch in the agent
loop.

Recursive calls require explicit parentage, budgets, cancellation, and bounded
resource access. They do not inherit ambient credentials, files, transcript,
or stores. Remote handles need stable status and collection semantics after the
originating task object disappears.

Evidence required: local and remote execution of one quoted R operation with
the same receipt; cancellation before and after remote admission; one bounded
recursive call whose parent receives only its declared result.

### Decentralized sub-agent coordination

A central scheduler is not the only useful topology. In the `pi-bio-agent`
blackboard proof, workers start independently, wait for access-list
dependencies, and publish notes. A diamond order emerges from shared state.

Rho needs only the smallest coordination protocol demonstrated by both an
environment/condition-variable implementation and a remote SQL or NNG
implementation. Do not promote Fugu prompts, a scaffold schema, or a universal
multi-agent scheduler into core.

Evidence required: a four-worker diamond with no central topological loop;
bounded worker context; deterministic dependency receipts; failure and
cancellation propagation.

### `targets` and `crew` composition

Deterministic scientific invalidation, durable dynamic agent coordination, and
provider streaming are not one problem. Before adding a Rho scheduler or
action cache, bind one resolver or operation to `targets`/`crew` and identify
which semantics are already supplied.

Promote only a missing common contract. A target graph may own reproducible
materialization while Rho owns conversation lifecycle; mirai may serve both
through separate policies.

Evidence required: one scientific operation executed directly and through the
adapter with matching result and provenance; a written account of invalidation,
cancellation, resumption, and remote placement that names the remaining gap.

## Closed constraints

Do not reopen these without contradictory executable evidence:

- providers and the agent loop receive credentials and effects explicitly;
- effectful public APIs return tasks, streams, or typed error values;
- provider transport, model behavior, and execution placement remain separate
  dispatch questions;
- CAS identifies immutable bytes but does not establish freshness or truth;
- bioinformatics remains downstream of provider and agent semantics;
- a file-backed adapter does not make the filesystem part of an open protocol;
- recursive and multi-agent arrangements are host compositions over the same
  agent, resource, execution, and coordination contracts.

The abstractions that currently survive these pressures are summarized in
[Current synthesis](synthesis.html). Concrete delivery order remains in the
[roadmap](https://github.com/RGenomicsETL/Rho/blob/main/ROADMAP.md).
