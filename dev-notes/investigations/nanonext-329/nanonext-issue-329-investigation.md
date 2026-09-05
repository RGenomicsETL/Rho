# nanonext #329 investigation — 2026-09-04

The upstream discussion is still open and the proposed stream API is not implemented in upstream `main`. Preserve the fork's existing public API during this rebase. Three reproducible native defects warrant a separate, bounded correction: interim responses prematurely finish opening, unsupported transfer codings are accepted without decoding, and a receive timeout restarts on internal framing reads.

## Verified versions and upstream position

- Original current fork: `RGenomicsETL/nanonext` `5302ac39732477aafbd042ab61e314d763220658`.
- Upstream inspected: `9d32d058ae03e7bc51d72e1f61a7694923c63b65`, dated 2026-08-29, including the failed-TLS-dial double-free correction.
- Rebased baseline tested: `ce7ab71776775c43243880826abd37276d48ac9e`, version `1.10.2.9001`, installed at `/tmp/rho-nanonext-rebase-lib`.
- [Issue #329](https://github.com/r-lib/nanonext/issues/329) remains open; its only comment is the [maintainer's proposal from July 16](https://github.com/r-lib/nanonext/issues/329#issuecomment-4996794888). [PR #328](https://github.com/r-lib/nanonext/pull/328) is closed and unmerged. Read with `gh issue view`/`gh pr view` on the investigation date.
- `git grep` in upstream `R/` and `NAMESPACE` finds none of `ncurl_stream`, `stream_aio`, or `as.promise.sendAio`. The rebase therefore does not eliminate Rho's fork dependency.

The maintainer proposes a synchronous constructor returning a stream plus response headers, followed by ordinary `recv_aio()`, with a zero-length chunk indicating EOF. Constructor naming, precise status/header access, header selection, cancellation aftermath, repeated EOF, and repeated close are not settled in the issue. The suggested `ncurl_stream()` name in Rho's existing note is a downstream proposal, not an agreed or exported upstream API.

## Current API and downstream dependency

The existing [Rho design note](../../../docs/nanonext-http-streaming.md) cites historical fork `cf24957d`. Current fork history has eight commits beyond upstream, including asynchronous ordinary stream dialing and send-Aio promise support; those additions must survive as well as HTTP streaming.

| Current surface | Contract / current Rho use |
|---|---|
| `ncurl_session()` + `transact()` | Existing synchronous reusable connection and complete transactions; not an incremental response-body stream. |
| `ncurl_stream_aio()` | Cancellable asynchronous opening; resolves to `list(status, headers, stream)`. Rho HTTP opening calls it directly. |
| `ncurl_stream_recv()` | One active receive; resolves to `list(data = raw, complete = logical)`; supports condition variables, terminal cancellation/timeout, and repeated EOF. |
| `ncurlStream` + `close()` | Separate HTTP external pointer; raw-response-body owner. First close returns `0`; another returns `errorValue(7)`. |
| `stream_aio()` | Asynchronous TCP/TLS/WebSocket dialer; used by Rho WebSocket opening. |
| `as.promise.sendAio()` | Resolves send results or rejects NNG errors; used through Rho's general Aio-to-promise adapter. |

Source: [fork R HTTP wrappers](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/R/ncurl.R), [stream wrappers](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/R/stream.R), [promise methods](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/R/aio.R), [Rho opening methods](../../../packages/rho.http/R/02-http.R), [Rho body receiver](../../../packages/rho.http/R/04-streams.R), [Rho Aio adapter](../../../packages/rho.async/R/03-tasks.R).

`ncurlStream` is not accepted by ordinary `recv_aio()`. Changing its R class alone would not make it safe: [the native receive path](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/src/aio.c) selects by external-pointer tag and casts ordinary streams to `nano_stream`, whose first member is an `nng_stream *`; the HTTP owner contains an `nng_http_conn *` in a different layout. A future unified R API needs explicit native dispatch and preserved HTTP framing/lifecycle state, plus an unsupported-operation result for sends. It should not fabricate a private NNG stream implementation.

Repeated close is safe but does not return success twice. That matches [ordinary nanonext stream close](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/src/proto.c), and the reproduction confirms `0`, then `7`. Rho deliberately makes its own close method idempotent by recording `state$closed`. Do not accidentally change that distinction in a public rewrite.

## Executable baseline evidence

Run the bounded standalone peer harness:

```sh
Rscript --vanilla dev-notes/investigations/nanonext-329/nanonext-issue-329-reproduce.R /tmp/rho-nanonext-rebase-lib
```

The base-R server emits exact HTTP bytes from a separate R process, with finite socket and client operation timeouts. Results are in [baseline JSON](nanonext-issue-329-reproduce.json); [harness source](nanonext-issue-329-reproduce.R) accepts an optional second argument naming a different output file. The harness uses [shared process helpers](http-probe-tools.R) and the [raw peer](http-probe-peer.R). Timing values describe a run, not a performance guarantee.

| Wire scenario | Observed baseline behavior | Assessment |
|---|---|---|
| `103`, then final `200` with `abc`, in one write | Opens status `103`; empty body and stable EOF | Loses final response. |
| `100`, then `103`, then `200` | Opens status `100`; empty body and stable EOF | Same defect for multiple interim heads. |
| `Transfer-Encoding: gzip, chunked` with genuinely compressed, chunked `abc` | Returns gzip bytes successfully | Transfer coding remains undecoded under the body-bytes contract. |
| `Transfer-Encoding: chunked, gzip` with a plain chunked wire body | Accepts `abc` | Invalid wire/coding combination accepted because `chunked` matches anywhere. |
| `Transfer-Encoding: chunked, chunked` | Accepts `abc` | Invalid duplicate coding accepted. |
| `Transfer-Encoding: gzip` | Returns gzip bytes successfully | Unsupported transfer coding is not rejected. |
| Both `Transfer-Encoding: chunked` and `Content-Length: 999` | Returns decoded `abc` | Rejecting this is defensive policy strengthening; existing transfer-encoding precedence alone is not proof of a protocol violation. |
| Negative, nondecimal, overflowing, conflicting separate/list `Content-Length` | Opening returns protocol error `13` | Existing validation works. |
| Two identical `Content-Length: 3` fields | Opening returns protocol error `13` | Strict rejection already exists; not a new regression. |
| Valid fixed/chunked body; valid extension/trailer | Returns `abc`, then stable EOF | Working controls. |
| Non-hex chunk size | Receive returns protocol error `13` | Existing framing validation works. |
| Control byte in chunk extension | Returns `abc` | Remaining parser-validation gap; separate from the minimal repair. |
| Chunk-size line arrives in eight fragments spaced 40 ms apart; one-byte buffer; receive timeout 100 ms | Completes after approximately 322 ms | Single user receive exceeds its documented timeout. |

HTTP requires clients to process interim responses before the final response. A `1xx` message has no body, but it is not completion of the overall response operation. `101` switches protocols and needs a separate unsupported path for this body-only interface. [RFC 9110 §15.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.2).

Final transfer-coding position controls framing; duplicate `chunked` is forbidden. Transfer-encoding plus length merits defensive rejection. The standard permits handling a valid list of identical lengths, while conflicting lengths must fail. Supporting only a single `chunked` transfer coding is a narrow capability choice; other transfer codings should fail explicitly. Content-Encoding remains a separate layer. [RFC 9112 §§6–7](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3).

The timeout failure comes from reusing an NNG Aio across internal reads with a relative timeout. [NNG's Aio scheduler](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/src/nng/src/core/aio.c) computes a new expiration per scheduled operation and clears `a_use_expire` on completion. A correction must store the absolute deadline per public opening/receive operation and reapply it before every chained native operation. Merely calling `nng_aio_set_expire()` once is insufficient.

## Independent verification of the bounded correction

The working correction was installed separately at `/tmp/rho-nanonext-fixed-lib`, retaining version `1.10.2.9001`. Re-running all 19 scenarios produced [fixed-build evidence](nanonext-issue-329-fixed.json):

- Both interim-response cases now open the final `200`, expose its `Content-Length: 3`, and deliver `abc`.
- All four unsupported/invalid transfer-coding cases now reject opening with `errorValue(9)` (`NNG_ENOTSUP`).
- TE plus Content-Length rejects with `errorValue(13)` (`NNG_EPROTO`).
- The 100 ms slow-framing receive now fails with `errorValue(5)` (`NNG_ETIMEDOUT`) after approximately 118 ms including R-side setup/collection overhead; it delivers no body.
- Valid fixed/chunked bodies, valid extensions/trailers, invalid chunk sizes, all length checks, repeated EOF, and first/second close behavior retain their expected outcomes.
- Invalid extension control bytes remain accepted, explicitly outside this small repair.

Read-only review of the native diff found no additional blocker: interim heads reset only the response object, preserving NNG connection read-ahead; supported transfer coding is checked without changing bodyless-response precedence; and the stored absolute deadlines are reapplied at each chained native operation. This review and harness complement the package tests; they do not establish full HTTP parser conformance.

## Rho migration constraints and corrective direction

Preserve `ncurl_session()` and its complete-transaction behavior. A future separate synchronous response-stream constructor can share request conventions without overloading that session lifecycle. Preserve raw bytes: transport boundaries can split UTF-8 and SSE lines. If a receive yields data while discovering completion, return that data first and expose `raw(0)` on the next receive; EOF must never mean temporary lack of available bytes.

Synchronous response-head opening would block the R process through connect, request write, and head receipt. Wrapping it in `rho_task_from_function()` does not move execution. It can also prevent a callback-driven HTTP test server in the same R process from running its response callback, producing a stall until timeout. This is an execution constraint inferred from blocking waits and callback dispatch, not a failure reproduced against a new upstream constructor (none exists).

Offloading such an opener to a worker cannot return a live native external pointer for the caller to receive from. The worker must retain ownership and relay typed heads, body bytes, errors, and completion, as [Rho's httr2 worker transport](../../../packages/rho.http.httr2/R/02-workers.R) does. Rho already distinguishes `RhoHttpAioOpen` from caller-thread opening; a synchronous replacement must change that declared execution behavior and its tests.

For the rebase follow-up, keep public names and result shapes intact. Fix the demonstrated interim-head, supported-transfer-coding, and absolute-deadline defects, with a defensive TE/CL policy and explicit unsupported upgrade/tunnel behavior. Re-run native lifecycle tests and the Rho async/HTTP/WebSocket consumers. Leave the proposed upstream API redesign for #329 discussion.

Before a public API replacement, retain tests for coalesced head/body bytes; every framing boundary with one-byte buffers; `HEAD`, `204`, `304`; interim heads; clean and truncated fixed/chunked/close-delimited bodies; malformed lengths/codings; active receive cancellation, close, timeout and repeated EOF; HTTPS caller TLS; condition-variable/promise completion; early SSE delivery while the connection remains open; and Rho's bounded error-body collection.

## Separate server lifetime defect exposed by combined integration tests

Running all six Rho package suites in one R process exposed a native callback failure after the HTTP fixture suites had finished. The rebased baseline also failed (including a segmentation fault), so this was not introduced by the framing correction. The original installed fork `1.10.1.9001` independently fails the minimal reproduction below, establishing that the defect also predates this rebase.

[The standalone reproduction](nanonext-server-gc-reproduce.R) opens a local streaming server, closes the client and server, drops the R references, forces **two** garbage collections plus heap allocation, then runs deferred callbacks. Both original and rebased baselines fail immediately with an invalid `R_ClearExternalPtr` argument. One collection alone can retain a newly finalized object's graph, which explains why lighter fixture runs can pass.

The server's C struct retains handler functions and connection external pointers through `srv->prot`, but the only R protection was the server external pointer's protected field. [Server finalization](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/src/server.c) queued later callbacks without preserving that graph. Once the R server object was collected, those callbacks could use reclaimed/reused SEXPs. This directly explains invalid callback functions and the non-external-pointer argument during connection cleanup.

The separate five-line native fix preserves `srv->prot` when finalization begins and releases it at the end of deferred server cleanup. It retains objects until their last actual use. [The regression test](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/tests/http-server-lifetime.R) uses the existing complete-transaction `ncurl_aio()` client, exercises explicit close and GC-triggered finalization, forces collection before callback delivery, and requires exactly one `on_close` callback per connection. The fixture completes the response through the server connection and waits for native transaction completion while leaving the R cleanup callback queued. This isolates the lifetime defect from an intermittent `stop_aio(ncurl_aio)` wait encountered in the first fixture draft.

Verified with the isolated build `/tmp/rho-nanonext-server-fixed-lib`: all 10 regression-test teardown cycles and all 20 standalone forced-GC cycles pass. Commands:

```sh
R_LIBS=/tmp/rho-nanonext-server-fixed-lib Rscript --vanilla /root/Rho/nanonext/tests/http-server-lifetime.R
Rscript --vanilla dev-notes/investigations/nanonext-329/nanonext-server-gc-reproduce.R /tmp/rho-nanonext-server-fixed-lib
```

The adjacent concern about client callbacks examining `nng_aio_result()` immediately after resubmission remains a separate source-audit question. Some NNG failures schedule another callback, whereas beginning an already stopped Aio returns cancellation without another callback. No observed failure in this investigation was attributed to that path, and it was not changed to fix the demonstrated server lifetime defect.

The first regression fixture also exposed an intermittent hang while cancelling
an incomplete `ncurl_aio()` transaction. A native stack showed `stop_aio()`
waiting in `nng_aio_stop()` / `nni_task_wait()` with the worker threads idle.
That cancellation path has not been fixed or attributed to a particular commit.
The final lifetime test completes the response normally, waits for native
transaction completion, then forces GC before deferred R cleanup. It still
fails on the baseline and passed 20 independent processes / 200 teardown cycles
on the fixed build. This separates the demonstrated lifetime repair from the
remaining complete-transaction cancellation investigation. The captured stack
is at `/tmp/rho-nanonext-lifetime-deadlock-stacks.log`.

## Final changes

The final fork tip is `084c8eb82a35c38b2aaf7dd203414829c2bd8011`, version
`1.10.2.9001`, built on upstream `9d32d058ae03e7bc51d72e1f61a7694923c63b65`.
The original eight fork commits were rebased; only the version/news conflict
needed a content change. Separate follow-up commits contain
[framing/deadline fixes](https://github.com/RGenomicsETL/nanonext/commit/dac8e81c7)
and the [server lifetime repair](https://github.com/RGenomicsETL/nanonext/commit/084c8eb82a35c38b2aaf7dd203414829c2bd8011).

The final native code passed 1,151 assertions across the six installed Rho
packages (`rho.async`, `rho.http`, `rho.compute`, `rho.http.httr2`, `rho.ai`,
`rho.agent`) in one R process. Rho's dependency installer and both HTTP package
remotes/minimum versions now select this fork. Its HTTP design note records
the current API and migration constraints. These Rho changes are recorded in
commit `b9febad`; pre-existing worktree changes were preserved byte-for-byte.

The final source tarball passed `R CMD check --no-manual` with
`NOT_CRAN=true`, bundled NNG/Mbed TLS, and R 4.6.0 on Linux: **Status: OK**.
This includes both new regression files and the existing complete test suite,
documentation, examples, and vignette checks. The log is
`/tmp/rho-nanonext-final-check.log`.

The fork's remote `main` was updated to the final tip with an explicit
`--force-with-lease` against the previously observed SHA. The atomic push also
preserved `5302ac39732477aafbd042ab61e314d763220658` as remote branch
`backup/pre-rebase-2026-09-04`; both remote refs were verified afterward.
Rho's dependency/documentation changes are included alongside this archive.

No GitHub comment was posted. The report and standalone R harnesses are archived
here; native fixes and regression tests are in the nanonext fork, and the
dependency/documentation changes are in the Rho repository.
