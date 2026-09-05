# nanonext issue #329 investigation

Start with [Gao's proposal and the Rho API assessment](gao-proposal-rho-api.md).
The [native investigation](nanonext-issue-329-investigation.md) records the
rebase, framing/deadline repairs, server lifetime repair, and remaining findings.
These notes preserve the September 4 investigation; proposed APIs are not
implemented contracts.

The JSON files record local measurements. Re-running a probe replaces its JSON
output, so timing differences should not be read as new performance guarantees.
Historical `/tmp` paths in the native investigation identify the original local
builds and logs; those logs are not included in this archive.

All probes use R. They require `nanonext`, `later`, `processx`, and `jsonlite`.
The backend comparison additionally requires the installed Rho HTTP, async,
compute, and httr2 packages and their dependencies. Use the rebased fork pinned
by this repository; upstream nanonext does not provide the fork's streaming API.

From the repository root, with those packages installed:

```sh
Rscript --vanilla dev-notes/investigations/nanonext-329/gao-opening-probe.R
Rscript --vanilla dev-notes/investigations/nanonext-329/rho-header-timing-probe.R
Rscript --vanilla dev-notes/investigations/nanonext-329/nanonext-issue-329-reproduce.R
```

Set `NANONEXT_329_LIB` to select an isolated R library. The framing probe also
accepts an explicit library path and output JSON path as its first two arguments;
`NANONEXT_329_CASES` selects a comma-separated subset of cases. Run the baseline
at `ce7ab71776775c43243880826abd37276d48ac9e` and the repaired build at
`084c8eb82a35c38b2aaf7dd203414829c2bd8011` in separate R processes.

The server-GC reproducer takes its R library path as its first argument. Native
package regression tests live in the nanonext fork's `tests/http-stream.R` and
`tests/http-server-lifetime.R`.
