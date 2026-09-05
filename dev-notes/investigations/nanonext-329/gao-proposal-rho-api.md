# Gao's proposal and Rho's HTTP contract

Investigated against upstream issue #329 and the local Rho sources on 2026-09-04.
This is a design assessment with executable evidence, not an implemented API
change or a commitment to a new public contract.

The recommended direction is to adopt Gao's ordinary body-stream API and retain
asynchronous opening for Rho's default native backend. Synchronous opening can
support an individual SSE response, but it weakens the responsiveness and
cancellation semantics that Rho currently provides while waiting for headers.
These are two separable design decisions.

## What Gao actually proposed

The [maintainer's comment](https://github.com/r-lib/nanonext/issues/329#issuecomment-4996794888)
proposes a constructor resembling `ncurl_session()`, returning a stream with
headers synchronously, followed by ordinary `recv_aio()` operations and a
zero-length chunk for EOF. It does not settle the constructor name, class
hierarchy, metadata representation, timeout scope, concurrent-receive rules,
cancellation aftermath, or repeated-close return value. Those details in the
earlier investigation were recommendations, not promises from upstream.

The existing [ncurl_session()](https://github.com/RGenomicsETL/nanonext/blob/084c8eb82a35c38b2aaf7dd203414829c2bd8011/R/ncurl.R#L195) remains a reusable HTTP
connection whose `transact()` collects a complete response. It does not currently
provide incremental body reads. A streaming constructor should preserve that
existing contract.

## What synchronous headers allow

Assuming correct HTTP body decoding and normal Aio lifecycle integration:

| Rho requirement | Synchronous head constructor in the main R session |
|---|---|
| Read status and headers before the body completes | Supported; opening must stop at the final head. |
| Deliver SSE events, NDJSON records, or download bytes incrementally | Supported after opening; framing above raw body bytes stays in Rho. |
| Cancel a pending body read or close its owner | Compatible with ordinary Aios; native ownership and cancellation still need implementation and tests. |
| Collect a bounded non-success response body | Supported through Rho's existing status-error adapter. |
| Cancel through a scheduled R task while waiting for headers | Unavailable while a non-event-pumping native constructor occupies the main R thread. |
| Keep R callbacks/rendering responsive while another stream opens | Unavailable during that blocking phase. Native I/O on other connections can still progress and buffer. |
| Start several opens concurrently from the same R event loop | Calls serialize while each opening blocks. |

Wrapping the constructor in `rho_task_from_function()` schedules blocking work;
it does not turn that work into asynchronous I/O. The wrapper can be cancelled
before it starts, but scheduled cancellation and R deadline callbacks cannot run
inside the blocking interval. An explicit native opening deadline can still
bound it. Keyboard-interrupt handling depends on the actual implementation and
is distinct from programmatic task cancellation.

The proposal alone does not establish HTTP/2, decompression, redirects, upload
streaming, automatic SSE reconnection, or bounded end-to-end buffering. HTTP
dechunking belongs below the public raw-byte stream. Ordinary informational
responses must be skipped until the final head; they must not become EOF for the
request. Protocol switching needs separate treatment.

## Measured opening behavior

The [R opening probe](gao-opening-probe.R) uses an independent
[base-R HTTP peer](http-probe-peer.R) that waits 350 ms before sending headers
and the first SSE event, then leaves the response open. The synchronous case
uses `call_aio()` on the existing fork to model a non-event-pumping wait for the
head. It does not implement or benchmark Gao's proposed constructor.

The [recorded R-only run](gao-opening-probe.json) shows:

| Measurement | Asynchronous opening | Simulated synchronous opening |
|---|---:|---:|
| Opening call returns | 1 ms | 368 ms |
| Scheduled heartbeat executes before head delivery | 51 ms | No |
| Scheduled cancellation callback can execute before head delivery | Yes, 101 ms | No |
| First SSE event delivered while response remains open | Yes | Yes |
| Subsequent pending body read cancelled | Yes | Yes |

A separate asynchronous cancellation case terminated opening at 101 ms with
NNG cancellation error 20. Times illustrate ordering in this local run, not a
performance guarantee.

## The smaller nanonext API Rho should seek

Proposed shape, not available upstream today:

```r
ncurl_stream(...)       # synchronously returns the HTTP body stream
ncurl_stream_aio(...)   # resolves asynchronously to that same stream type

recv_aio(stream, mode = "raw")  # bytes; raw(0) means HTTP EOF
close(stream)
```

The asynchronous constructor is the one addition Rho benefits from beyond Gao's
initial scope. It does not require a separate body receive operation,
`list(data, complete)` payload, or bespoke public opening class. Arguments should
follow the ncurl family, including `response` header selection; Rho requests all
headers. Raw receive mode avoids converting incomplete UTF-8 fragments.

This is a native dispatch change, not merely an R class change. Current ordinary
stream receives assume an `nng_stream *`, whereas the fork's HTTP owner uses a
different representation. Reuse the proven HTTP framing state while dispatching
receive and close through nanonext-owned state. Do not depend on a fabricated
private NNG stream vtable.

If upstream initially accepts only synchronous opening, a responsive Rho
adapter can keep the entire connection in a worker and relay head/body values.
The external pointer cannot be opened in a worker and then used as the live
connection in the main process. Worker placement requires real lifecycle,
cancellation, queue bounds, and capacity management. Rho already has a worker
relay in `rho.http.httr2`; it is a useful pattern with its own gaps, not a free
substitute for native asynchronous opening.

## A better Rho API can keep its current useful shapes

Rho need not mirror nanonext's public objects. Its current primitive is already
well chosen:

```text
rho_http_open_stream(client, request)
  -> RhoTask resolving at the final response head
  -> RhoHttpBodyStream carrying @head and owning its connection

rho_stream_next(body)
  -> RhoTask containing raw bytes, typed failure, or RhoStreamEnd

rho_sse_connect(client, request)
  -> RhoStream of decoded SSE events
```

Keep EOF normalization inside the transport adapter. Provider code should never
need to know whether the native representation is `raw(0)` or the fork's
`complete` flag. Both constructors can therefore share the same Rho body adapter.

Make `rho_http_open_stream()` the common backend primitive. A default
`rho_http_send()` can asynchronously collect it with a byte limit and optional
overall deadline; specialized methods can remain where a backend needs them.
Do not implement this default with the existing synchronous
`rho_stream_collect()` inside a task callback. SSE decoding and bounded error
collection already compose above body streams. This reduces duplicated HTTP
ownership and error paths without adding another public response hierarchy.

Three concrete Rho improvements are supported by this investigation:

1. **Make opening semantics enforceable.** The default streaming contract should
   require a promptly returned task, final-head resolution independent of first
   body data, and cancellation of opening. The current
   `rho_http_open_execution()` classifications describe placement but providers
   do not use them to enforce these properties. Establish these requirements in
   shared backend tests; a deliberately blocking adapter needs an explicit
   boundary rather than a hidden change behind the same task signature.

2. **Separate deadlines and fix inheritance.** Opening timeout covers admission
   or queueing, connection, request write, and final-head receipt. Read timeout
   bounds a pending body pull. An optional overall deadline bounds the complete
   operation. Explicit request overrides should inherit from the client when
   absent. Currently `rho_http_request()` always inserts 30000 ms, so a client
   configured for 1234 ms still produces a 30000 ms payload with a default
   request; see the [measured values](rho-timeout-inheritance-probe.json) and
   [payload construction](../../../packages/rho.http/R/02-http.R). The nanonext
   streaming adapter applies the payload timeout to opening and each pull,
   whereas [the httr2 worker](../../../packages/rho.http.httr2/R/02-workers.R) also
   passes it as curl's total-transfer timeout. Those meanings can terminate
   long-lived SSE streams differently.

3. **Deliver httr2 headers at the header boundary.** Its current worker sends
   the head from the body-data callback or the completion callback. In the
   [R backend probe](rho-header-timing-probe.R), the peer sent headers and held
   the body for 400 ms. Nanonext exposed the head at 151 ms and body at 402 ms;
   httr2 exposed the head at 405 ms and body at 410 ms. The finding is the
   ordering, not a backend speed comparison. See [recorded results](rho-header-timing-probe.json).

The shared contract tests should additionally cover cancellation racing with
head delivery, closing a pending pull, one active pull per body, stable EOF,
bounded error-body collection, and resource release after errors. They should
assert behavior rather than trusting the execution-class declaration.

The practical recommendation is an ordinary nanonext body stream plus an
asynchronous opener for Rho, with one Rho opening contract and consistent
deadlines across backends. Synchronous opening remains usable for an explicit
blocking workflow or as a worker-owned implementation.
