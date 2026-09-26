# Rho engineering constitution

Rho takes semantic pressure from Pi and resolves it through R. It is not a
line-for-line port. The repository follows four motifs:

- **Simplicity:** one semantic source of truth, the smallest public protocol,
  and no compatibility or abstraction ceremony without a current consumer.
- **Functional OOP:** immutable semantic values, S7 properties and validators,
  open generics, narrow methods, useful default implementations, and small
  consumer-defined `s7contract` interfaces. Prefer dispatch and structural
  conformance to managers, string switches, or forests of helper functions.
- **R:** use modern R, including language objects, lazy evaluation, closures,
  environments, active bindings, and package namespaces where they clarify the
  design. Write C only for a measured native concern or an interface R cannot
  express honestly.
- **Dialectical movement:** begin with a concrete thesis, push it against a
  contradictory provider or application, and keep the smaller synthesis that
  survives executable evidence. Do not freeze an early answer into an ADR.

## Read before changing a contract

| Work | Source |
|---|---|
| Package ownership and public concepts | [Architecture](docs/architecture.md) |
| Abstractions that currently survive | [Current synthesis](docs/synthesis.md) |
| Open contradictions and required evidence | [Refinements](docs/refinements.md) |
| S7, `s7contract`, properties, and R design | [Functional OOP in R](dev-notes/design/functional-oop.md) |
| Tasks, streams, cancellation, and placement | [Asynchronous effects](dev-notes/design/async-effects.md) |
| Provider, agent, session, and extension events | [Provider and event protocols](dev-notes/design/provider-and-event-protocols.md) |
| Sessions, resolvers, CAS, NNG, and sub-agents | [Session and resource topologies](dev-notes/design/session-resource-topologies.md) |
| Ordered delivery work | [Roadmap](ROADMAP.md) |
| Verified Pi behavior | [Pi parity ledger](docs/pi-parity.md) |

Design notes explain focused contracts and audits. `docs/synthesis.md` changes
when stronger evidence changes the design. `docs/refinements.md` is a pressure
ledger, not a feature list. A claim graduates from either document only with a
linked test, executable Rmd, or integration run.

## Invariants

1. Public behavior that varies by class enters through an S7 generic. A method
   implements it. A broad default method expresses genuinely shared behavior;
   it must not conceal an unsupported operation.
2. A consuming package bundles the generics it needs in a small structural
   `s7contract` interface. Conformance comes from ordinary S7 methods, not a
   second inheritance hierarchy. Use an explicit trait only when opt-in
   conformance, default methods, or associated metadata are themselves part of
   the contract. Add progressive argument and return checks at consequential
   boundaries, not indiscriminately around every internal call.
3. S7 properties and class validators own field constraints and their messages.
   Attach a reusable constraint directly to the class property. Do not write an
   `is_*()` helper that merely reopens an S7 object and checks one of its fields.
   Stateful runtime objects keep explicit state in environment properties, and
   mutation goes through named functions or generics.
4. Protocols carry typed values. Character strings belong at provider wires,
   serialization, user input, and other real boundaries, not in runtime class
   switches. A durable schema declares stable semantic tags and fields; it must
   not reflect package names, S7 class names, or the current property layout
   into stored data.
5. Effectful public APIs return `RhoTask`, `RhoStream`, or `RhoDuplex`.
   Synchronous waiting is visible at `rho_await()`, a CLI boundary, or a test
   helper. Operational failure is a typed value.
6. nanonext owns low-level I/O, signalling, and TLS. `rho.http` owns HTTP, SSE,
   and WebSocket contracts. mirai execution enters higher packages only through
   `rho.compute`.
7. Scheduling and placement are distinct. The agent may start and join tool
   tasks in source order; a typed binding selects current-session R, a mirai
   worker, a persistent process, an embedded model, or a remote endpoint.
8. Credentials, stores, connections, clocks, filesystem authority, and worker
   placement are explicit capabilities. Package code does not discover them
   from process globals.
9. `ToolSpec` is executable host code. `RhoOperation` is a semantic request
   that a provider, extension, local evaluator, or remote backend may bind.
   Provider-hosted activity never masquerades as a local tool call.
10. Provider behavior is derived from declared endpoints and typed catalog
   values. Model names are identity, not protocol or capability tests. Missing
   support remains explicit and fails closed.
11. The agent substrate contains no coding or bioinformatics policy.
    `rho.bio` does not import `rho.agent` or `rho.ext`; downstream applications
    compose the stable ports.
12. CAS identifies immutable bytes. It is not a freshness oracle, session
    journal, blackboard, lease service, or scheduler. A filesystem adapter does
    not make a path part of an open protocol.
13. Graphics and complete tool outputs are typed artifacts rather than console
    side effects. Durable graphics use declared devices and content digests;
    `recordedplot` is only an ephemeral preview.

## R and package practice

- The repository root is the `rho` package. `R/` contains the components;
  `inst/tinytest/rmd/` contains the authored test suite. Optional backends
  keep their external dependencies in `Suggests`.
- Target R 4.6.0 or newer; older R has ABI differences we do not support. Use modern base R directly; do not redefine `%||%`
  or add compatibility shims for older R.
- Do not create dot-prefixed pseudo-private functions or constants. Package
  namespaces already provide encapsulation. Standard package hooks such as
  `.onLoad()` are the exception.
- Every package defining S7 methods calls `S7::methods_register()` from
  `.onLoad()`.
- Provider packages use `rho.http`; higher packages use `rho.compute`; neither
  opens a parallel implementation around an inconvenient contract.
- Authored tests live in `inst/tinytest/rmd/`; generated `test-*.R` files are
  not edited. Every asynchronous test has a finite timeout.
- Roxygen is the source for `NAMESPACE` and `man/`. Air formats authored R.
  Run the focused test first, then the package gates appropriate to the
  changed contract.
- Documentation describes supported behavior and links its evidence. It does
  not relay a coding session, invent output, or call an unevaluated example a
  verification.

When an abstraction changes, change all consumers in `rho` together and
retain only the clearer form.
