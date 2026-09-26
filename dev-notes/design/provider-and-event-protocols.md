# Provider and event protocols

Rho has one public semantic flow and several private wire dialects:

```text
provider bytes
  -> private wire parser
  -> canonical assistant events
  -> agent lifecycle events
  -> committed session events
  -> extension, TUI, and projection methods
```

The layers do not need identical event classes. They do need one canonical
public vocabulary at each boundary and an explicit transformation between
boundaries.

## An event exists only when it travels

Defining an S7 class is not implementation. For each public event, an audit
traces:

1. the owning package and class;
2. every site that actually emits it;
3. ordering relative to state mutation and adjacent events;
4. the task or stream that transports it;
5. every extension, TUI, exporter, and projection that consumes it;
6. an executable fixture for payload and order;
7. the package dependency direction introduced by those types.

An advertised but never emitted event is removed or implemented. A produced
event absent from the public union or extension surface is a protocol bug. A
consumer that happens to work because a validator silently discards old fields
is not migrated.

This audit form follows the useful part of Tau's
[Pi-like event migration audit](https://github.com/huggingface/tau/blob/main/dev-notes/design/pi-event-migration-audit.md):
it compared declared types, real producers, consumers, tests, and import
direction, then recorded the remediation against the same list. Rho should use
the same method when its event surface changes, with S7 dispatch replacing
string allow-lists.

Private provider parser events are acceptable when they simplify a wire
dialect and every public provider stream exposes canonical Rho values. They are
not acceptable as a second public profile that every consumer must understand.

## Provider derivation

Provider protocol follows a declared endpoint or typed descriptor. It is not
inferred from a model id, family prefix, or vendor-name regular expression.
Model metadata is compiled from the authored R manifest at
`data-raw/model-registry.R` and pinned upstream projections.
Curated corrections state why the source cannot express the fact and cite
stable evidence.

Request bodies reduce typed request-section values. S7 methods encode their
wire names at the final boundary. Long optional-field `if` chains, provider
strings as runtime state, and separate generated constructor functions for each
model are signs that data and dispatch have collapsed.

## Operations, tools, and extensions

`ToolSpec` describes host code the agent may execute. `RhoOperation` describes
a semantic request. `rho_plan_operations()` returns typed bindings naming the
handler and reason. A provider-hosted web search, local R evaluator, extension
implementation, and remote service can bind the same operation without being
placed in one local tool registry.

Extensions bind to an agent explicitly. Event handlers dispatch on event and
context classes. Context and policy hooks are awaited before the affected
action. Events announcing persisted state occur after commit. Observational
handlers that may lag declare their queue and flush behavior.

## Migration audit template

When changing an event family, create a focused note containing:

- intended package dependency graph;
- old, transitional, and canonical values;
- producer and consumer inventory;
- event-order table;
- fixtures that fail before the migration;
- remaining incompatibilities;
- remediation update after the gate passes.

Do not turn the audit into permanent API documentation. Once the contradiction
is resolved, update the conceptual design and retain the audit as evidence.
