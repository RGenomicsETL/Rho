# Rho 0.0.1.9001

- Requires R 4.6.0 or newer; earlier R releases differ in ABI.
- Distributes the async, HTTP, provider, agent, extension, compute, graphics,
  coding, and bioinformatics components as one top-level `rho` package with a
  unified test suite and optional backend dependencies.
- Propagates agent aborts to active tool tasks instead of waiting for their
  ordinary completion.
- Adds explicit encrypted-file and native-keychain credential stores. Portable
  storage authenticates the complete credential envelope; keychain storage
  rejects environment and file backends.
- Publishes one version for the Rho API.
- Distinguishes provider-reported, explicitly estimated, and unavailable usage
  observations; nominal API-equivalent pricing is not a subscription charge.

# Rho 0.0.1.9000

- Separates the HTTP client contract from its nanonext implementation and adds
  a worker-owned httr2 adapter with incremental response delivery.
- Selects provider turns through typed SSE, WebSocket, cached-WebSocket, and
  embedded strategies while preserving one normalized assistant-event stream.
- Compiles GitHub Copilot protocols from declared endpoint metadata instead of
  model-name patterns.
- Makes task composition cancellation-aware, adds `rho_race()`, gives task
  groups ownership of their children, and applies deadlines through derived
  streams.
- Replaces blocking extension, credential-refresh, provider-completion, and bio
  resolver composition with task chains and a cancellable serial queue.
- Makes mirai cancellation resolve as a typed `RhoCancellation` value.
- Pins every installation path to the reviewed nanonext HTTP streaming commit
  and exercises cancellation through the complete SSE receive stack.
- Makes the provider-operation agent fixture reliable across the R-universe
  operating-system matrix.
- Declares dependencies loaded by authored package tests and checks that every
  internal test dependency is present in package metadata.

- Establishes the asynchronous S7 provider, agent, extension, compute,
  graphics, coding, and bioinformatics components.
- Adds append-only agent sessions, semantic compaction, threshold compaction,
  and one typed provider-input recovery attempt.
- Preserves bounded non-success HTTP response bodies so provider adapters can
  translate structured input-limit responses without matching prose.
- Adds reproducible package, documentation, model-catalog, parity, formatting,
  and repository-history checks for the initial development release.
- Builds the repository landing page with litedown using a responsive article
  layout and direct links to the source repository and package documentation.
- Pins the nanonext development dependency for reproducible HTTP streaming.
- Uses deployed package URLs for cross-package README links.
