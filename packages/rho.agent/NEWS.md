# rho.agent 0.0.1.9001

- Cancels active tool tasks when an agent is aborted, retains their task handles
  only for the active call, and records cancellation as a tool error before the
  aborted run settles.
- Accounts for the complete transformed provider context before compaction.
  Reported token counts are reused only for the same model, prompt, tool,
  operation, and activation revision. Agent run results include cumulative
  typed usage and nominal-cost summaries.
- Marks prepared tool-call arguments explicitly, so policy events and execution
  share one typed argument value without running wire preparation twice.
- Represents idle, running, and compacting phases as S7 values. Agent behavior
  no longer branches on phase-name strings.
- Adds the structural `SessionJournal` contract and an in-memory implementation.
  Assistant partials remain in the active turn and only terminal messages enter
  the append-only journal; reset is represented by a committed entry instead of
  erasing history.
- Adds asynchronous session synchronization and compare-and-append positions.
  An idle agent can rebuild its projection from an existing journal, while a
  stale writer receives `RhoSessionConflictErrorValue` before journal mutation.

- Uses only counted usage observations when projecting context usage; an
  unavailable provider observation causes a complete-context estimate.

# rho.agent 0.0.1.9000

- Gives the provider-operation agent-loop fixture enough time on slower build
  hosts while retaining an explicit test timeout.

- Adds the experimental asynchronous multi-turn agent loop, ordered lifecycle
  events, tool scheduling, queues, cancellation, and policy generics.
- Adds append-only session entries, projected provider context, semantic
  compaction, typed skip and failure outcomes, threshold compaction, and one
  provider-input recovery attempt selected by an open S7 generic.
