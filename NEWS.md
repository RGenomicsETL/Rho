# Rho 0.0.1.9001

- Propagates agent aborts to active tool tasks instead of waiting for their
  ordinary completion.
- Adds explicit encrypted-file and native-keychain credential stores. Portable
  storage authenticates the complete credential envelope; keychain storage
  rejects environment and file backends.
- Publishes a synchronized package version so repositories select matching
  internal Rho dependencies instead of stale same-version artifacts.
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

- Establishes the experimental monorepo for Rho's asynchronous S7 provider,
  agent, extension, compute, graphics, coding, and bioinformatics packages.
- Adds append-only agent sessions, semantic compaction, threshold compaction,
  and one typed provider-input recovery attempt.
- Preserves bounded non-success HTTP response bodies so provider adapters can
  translate structured input-limit responses without matching prose.
- Adds reproducible package, documentation, model-catalog, parity, formatting,
  and repository-history checks for the initial development release.
- Builds the repository landing page with litedown using a responsive article
  layout and direct links to the source repository and package documentation.
- Declares internal package remotes so concurrent R-universe builds can install
  Rho dependencies from their monorepo directories.
- Uses deployed package URLs for cross-package README links.
