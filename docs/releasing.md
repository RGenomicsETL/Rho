# Publishing Rho

The monorepo has one development version. `VERSION` is authoritative, every
package `DESCRIPTION` must match it, and every dependency on another Rho
package must require at least that version. R-universe builds package
subdirectories concurrently, so each internal dependency also has a matching
`Remotes` entry for its package directory. `make check-version` enforces both
declarations.

`make public-ready` is the publication gate. It verifies version coherence,
package and monorepo news, lifecycle badges, generated tests and READMEs, the
model catalog, formatting, the parity ledger, repository history and working
tree, installed behavior, source tarballs, and package sites. A non-verified
row in `docs/pi-parity.md` is a failure, not a release note.

The secret scan uses Gitleaks 8.30.1 over the complete Git history. The Linux
x86-64 release archive has SHA-256 digest
`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`.
CI installs that exact artifact; local runs must provide the same `gitleaks`
executable on `PATH`.

Run `make hooks` once in each clone to configure the checked-in pre-push hook.
It runs the same `make check-secrets` scan before every push, over the local
Git history and working tree. Git never transfers hook configuration with a
clone, so this is deliberately an explicit setup step.

Before publishing a tagged release or changing the R-universe package set:

1. Run `make rd` and `make rdm`, then commit the generated namespaces,
   manuals, tests, model catalog, and package READMEs.
2. Run `make rdm-codex CREDENTIAL=/absolute/path/to/auth.json`. This executes
   the root README's Codex agent example and updates `README.md`; knitr caches
   remain ignored.
3. Complete every fixture and external-account row in the Pi parity ledger.
4. Run `make public-ready` from the commit that will become public.
5. Require green R 4.4 and R-release checks for that commit.
6. Confirm that the pinned nanonext streaming commit is public and available
   to the R-universe build graph. Track its upstream API in
   [nanonext issue #329](https://github.com/r-lib/nanonext/issues/329); do not
   remove the pin until an upstream release provides the semantics exercised by
   `rho.http`.

The repository and Pages deployment are already public. After those conditions
hold, create the release from the audited commit and update
`RGenomicsETL/rgenomicsetl.r-universe.dev` for every package in the declared
release set. Verify the resulting package builds; repository visibility and a
green Pages workflow are not release evidence by themselves.
