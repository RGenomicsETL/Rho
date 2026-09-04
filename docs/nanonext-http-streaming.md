# Incremental HTTP response bodies in nanonext

This note turns [nanonext issue
#329](https://github.com/r-lib/nanonext/issues/329) into a small proposed API,
states what it gives Rho, and separates public NNG facilities from implementation
details that should remain private to NNG.

## Current status (4 September 2026)

The shape below is a proposal. [Issue #329](https://github.com/r-lib/nanonext/issues/329)
is still open, and upstream
[`9d32d058`](https://github.com/r-lib/nanonext/commit/9d32d058ae03e7bc51d72e1f61a7694923c63b65)
does not export `ncurl_stream()`. The RGenomicsETL fork has been rebased onto that
commit, preserving its public interfaces. Its version is `1.10.2.9001`.

The current fork has more API additions than the original HTTP prototype:

| Surface | Current behavior and Rho dependency |
|---|---|
| `ncurl_session()` / `transact()` | Existing upstream reusable connection and complete transactions; unchanged by the fork. |
| `ncurl_stream_aio()` | Cancellable HTTP opening returning `{status, headers, stream}`. |
| `ncurl_stream_recv()` / `is_ncurl_stream()` | Separate HTTP stream receiving `{data, complete}`; used by the Rho HTTP body adapter. |
| `stream_aio()` | Asynchronous ordinary-stream opening; used by Rho WebSockets. |
| `as.promise.sendAio()` | Send completion through promises; used by Rho's Aio bridge. |

The rebased fork also corrects three reproduced HTTP defects: it skips interim
`100`/`103` responses until the final head, rejects unsupported transfer codings,
and preserves a single deadline across opening phases and framing-only receive
reads. It defensively rejects simultaneous `Transfer-Encoding` and
`Content-Length`, and rejects protocol upgrades and successful CONNECT tunnels.
These changes preserve the existing fork API; they do not implement the proposed
ordinary-stream API. [Native changes and regression tests](https://github.com/RGenomicsETL/nanonext/commit/dac8e81c7).

The pinned fork also retains HTTP server callback objects through deferred
teardown. Without that retention, garbage collection between server close and
the next event-loop iteration can reclaim connection pointers still used by
cleanup. The regression covers explicit close and finalizer-driven close with
two intervening garbage collections. This defect was reproduced on both the
old fork and the rebased baseline. [Lifetime fix and regression test](https://github.com/RGenomicsETL/nanonext/commit/084c8eb82a35c38b2aaf7dd203414829c2bd8011).

Repeated close is safe, but ordinary nanonext streams return an `errorValue`
on a second close. Rho makes its own close operation idempotent. A future public
API should state that distinction rather than promise repeated success by
accident.

## Short answer

The proposed synchronous response head is enough for Rho to consume SSE once a
request is open. Rho receives the status and headers before the response body
ends, then each `recv_aio()` supplies another raw body fragment. A zero-length
raw vector means that the body has ended.

It does not make opening the request asynchronous. DNS lookup, TCP and TLS
connection, request transmission, and receipt of the response head occupy the R
process that calls the constructor. Rho can return a task around that call, but
the task does not make the call cancellable or move it to another process.

The clean initial nanonext API is therefore useful, but Rho must describe it
accurately and retain an HTTP implementation with asynchronous opening.

Synchronous opening also prevents an HTTP server using callbacks in the same R
process from producing its response head while the constructor is waiting.
Those integration fixtures would need a separate server process. Moving only
the constructor to a worker is insufficient: the worker must own the native
connection and relay subsequent body bytes as well.

## 1. `ncurl_session()` already has a different job

`ncurl_session()` is an existing exported function. Its documentation defines a
reusable connection on which repeated `transact()` calls return complete
responses ([R wrapper and documentation](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/R/ncurl.R#L168-L234)).
The C constructor connects and waits before returning
([connection setup](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/ncurl.c#L590-L669));
`transact()` then waits for a complete HTTP transaction
([complete transaction](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/ncurl.c#L689-L749)).

An incremental response is different:

| Existing session | Proposed response stream |
|---|---|
| reusable connection | one response body |
| repeated `transact()` calls | repeated `recv_aio()` calls |
| each call returns the complete body | each call returns currently available bytes |
| transaction result contains status, headers, and body | stream carries status and headers; body arrives later |

The existing function should remain unchanged. “Like `ncurl_session()`” is best
read as “a synchronous constructor with the same request conventions and owned
cleanup,” not as a request to overload the session class.

## 2. Proposed R shape

A separate constructor keeps the two lifecycles clear:

```r
stream <- ncurl_stream(
  url,
  method = NULL,
  headers = NULL,
  data = NULL,
  response = NULL,
  timeout = NULL,
  tls = NULL,
  buffer = 65536L
)
```

It returns either an `errorValue` or a stream recognized by ordinary nanonext
operations. The response head is attached to that stream:

```r
stream$status
stream$headers

receiving <- recv_aio(stream, mode = "raw", timeout = 30000L)
bytes <- receiving[]

if (!length(bytes)) {
  # The response body has ended.
}

close(stream)
```

The class may be a `nanoStream` or an HTTP subtype, but these behaviors matter
more than the class spelling:

- `recv_aio(stream, mode = "raw")` is the only body-receive operation;
- `stop_aio()` interrupts a pending receive;
- `close()` interrupts a pending receive and follows the existing nanonext
  stream convention on a later close;
- one receive may be active at a time;
- a nonempty raw vector contains response-body bytes only;
- `raw(0)` means end-of-stream and nothing else;
- another receive after end-of-stream immediately returns `raw(0)`.

There is no `convert` argument. A network read can split an SSE line or a UTF-8
character, so conversion belongs after the caller has assembled complete
application data. The existing `response` argument should be considered for
consistency with the ncurl family: Rho would request `response = TRUE`, while a
caller could request selected headers or none.

The opening timeout should cover the whole call through receipt of the final
response head. A body-receive timeout is supplied separately to `recv_aio()`.

## 3. What the current fork proves

The Rho fork added `ncurl_stream_aio()` and `ncurl_stream_recv()`
([public R additions](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/R/ncurl.R#L283-L368)),
plus `is_ncurl_stream()`
([validator](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/R/utils.R#L191-L204)).
It proves that nanonext can:

- return a response head while the body remains open;
- deliver later body fragments;
- decode HTTP chunk framing;
- signal condition variables;
- cancel an opening or pending receive;
- make receive timeout terminal;
- return a stable end-of-stream result.

Its lifecycle tests cover an early SSE event, a later event, end-of-stream,
repeated end-of-stream, opening cancellation, receive cancellation, concurrent
receive rejection, and timeout
([fork tests](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/tests/tests.R#L1444-L1571)).

For a response framed by connection close, the fork treats both NNG's ordinary
closed value and its connection-shutdown value as end-of-body. It does not apply
that rule to fixed-length or chunked responses: a peer closing those before
their declared framing completes remains a transport error
([receive completion](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L574-L674)).

The fork's public shape is not the desired final shape. Its opening resolves to
`list(status, headers, stream)`, and its special receive resolves to
`list(data, complete)`
([native result construction](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L1086-L1164)).
The stream has only the `ncurlStream` class
([object construction](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L1242-L1265)),
so ordinary `recv_aio()` does not recognize it. The maintainer's proposal removes
those extra result shapes and body methods.

## 4. What must change inside nanonext

An ordinary nanonext stream currently contains an `nng_stream *`
([native stream structure](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nanonext.h#L159-L173)).
`recv_aio()` extracts that pointer and calls `nng_stream_recv()` directly
([stream receive path](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/aio.c#L905-L940)).
An HTTP response body instead owns an `nng_http_conn *` and must call the HTTP
read operation.

Changing only the R class would therefore be unsafe. Nanonext needs a small
internal distinction between its ordinary byte stream and an HTTP-body stream.
Its existing `recv_aio()` and `close()` implementations can select the correct
native operation from that distinction. Sending on an HTTP-body stream should
return the ordinary unsupported-operation value because the stream is read-only.

The fork already has a nanonext-owned HTTP state object for fixed-length,
chunked, connection-ended, and bodyless responses
([state definitions](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L205-L253)).
That state machine is the useful implementation core to adapt to the ordinary
stream interface.

## 5. How far to inspect NNG internals

Inspecting NNG source is warranted for understanding and tests. Depending on its
private symbols is not warranted.

NNG 1.12 already exposes the required calls publicly: connect a client, write a
request, read a response head, read raw bytes, and close the connection
([public HTTP connection API](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/include/nng/supplemental/http/http.h#L155-L177),
[public client API](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/include/nng/supplemental/http/http.h#L251-L269)).
The fork uses those public calls for opening and reading
([open sequence](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L524-L570),
[body read](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L574-L674)).

Reading private source answers two important questions:

1. NNG keeps bytes read past the end of the response head in its connection
   buffer, and the following raw read consumes those bytes first
   ([read buffer](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/src/supplemental/http/http_conn.c#L40-L62),
   [buffer consumption](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/src/supplemental/http/http_conn.c#L120-L200)).
   Early body bytes are therefore not lost when headers and the first event
   arrive together.
2. NNG's private chunk parser stores chunks until the complete body is known
   ([chunk storage](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/src/supplemental/http/http_chunk.c#L30-L74));
   the complete transaction later copies all stored chunks into the response
   ([whole-body assembly](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/src/supplemental/http/http_client.c#L317-L331)).
   It is not an incremental body reader that nanonext can call.

Nanonext therefore needs its own small HTTP/1.1 body decoder, but it does not
need private `nni_*` functions. It should use private source only to understand
observable behavior and to design regression tests.

## 6. NNG 2.0

NNG's current `main` branch identifies itself as development software with
breaking changes and directs production users to its stable branch
([NNG development notice](https://github.com/nanomsg/nng/blob/1addbf8b2544f736e94e77a04f22da9f6d18bef7/README.md#L18-L27)).
The public HTTP concepts still match the proposed R API. NNG 2.0 exposes a
unified HTTP connection, asynchronous raw reads, request writes, and a response
read that deliberately stops before entity data
([NNG 2.0 HTTP operations](https://github.com/nanomsg/nng/blob/1addbf8b2544f736e94e77a04f22da9f6d18bef7/include/nng/http.h#L102-L144)).

The C names and ownership model differ between NNG 1.12 and 2.0. Nanonext can
keep that difference inside a small set of its own HTTP functions, with one
implementation for each NNG version. Its R API and body-state logic need not
change.

Nanonext should not manufacture a private NNG `nng_stream` implementation. The
private stream layout has already changed from six operations in NNG 1.12
([1.12 private layout](https://github.com/r-lib/nanonext/blob/2573ee2ebdc32388ce5c1a2e0c81a8fcedc91888/src/nng/src/core/stream.h#L30-L37))
to a larger layout in NNG 2.0
([2.0 private layout](https://github.com/nanomsg/nng/blob/1addbf8b2544f736e94e77a04f22da9f6d18bef7/src/core/stream.h#L42-L56)).
That is exactly the kind of private coupling that a major NNG update would
break.

NNG 2.0 is the library version, not the HTTP protocol version. Its HTTP header
still says that HTTP/2 is not supported
([protocol note](https://github.com/nanomsg/nng/blob/1addbf8b2544f736e94e77a04f22da9f6d18bef7/include/nng/http.h#L167-L170)).

## 7. Exact effect on Rho

Rho's HTTP interface already requires every client to implement
`rho_http_send()` and `rho_http_open_stream()`
([interface](https://github.com/RGenomicsETL/Rho/blob/899b9ff6ad3240c6d44066ebbf4b0ae00c6ccf88/packages/rho.http/R/02-interfaces.R#L1-L16)).
The current nanonext method calls only the fork's opener
([opening adapter](https://github.com/RGenomicsETL/Rho/blob/899b9ff6ad3240c6d44066ebbf4b0ae00c6ccf88/packages/rho.http/R/02-http.R#L100-L143))
and its body stream calls only the fork's receive function
([receive adapter](https://github.com/RGenomicsETL/Rho/blob/899b9ff6ad3240c6d44066ebbf4b0ae00c6ccf88/packages/rho.http/R/04-streams.R#L1-L53)).

The upstream migration is narrow:

```text
ncurl_stream_aio()                 ncurl_stream()
ncurl_stream_recv()                recv_aio(mode = "raw")
result$data + result$complete      bytes + zero length means end
```

Provider translators, SSE decoding, the agent loop, cancellation, and extension
interfaces do not change.

The limitation is opening. `rho_task_from_function()` records a closure for
later execution but does not assign it to a worker
([task construction](https://github.com/RGenomicsETL/Rho/blob/899b9ff6ad3240c6d44066ebbf4b0ae00c6ccf88/packages/rho.async/R/03-tasks.R#L116-L133)).
When a synchronous `ncurl_stream()` eventually runs, it still occupies the main
R process until the response head arrives. A later `ncurl_stream_aio()` could
resolve to the same ordinary stream and remove that limitation without adding a
second body-receive API.

Until then, `rho.http.httr2` remains the implementation that owns the connection
in a worker and relays typed heads, chunks, and completion to the caller. The
generic Rho interface makes that a client selection rather than provider logic.

## 8. Tests required before replacing the fork API

The upstream implementation should cover:

- headers and first body bytes arriving in one transport read;
- one-byte receive buffers;
- fixed-length bodies split at every relevant position;
- chunk-size lines and chunk data split at every relevant position;
- chunk extensions and trailers;
- rejection of malformed chunk syntax and conflicting lengths;
- `chunked` only as the final transfer coding, with unsupported preceding
  codings rejected;
- connection-ended bodies;
- `HEAD`, `204`, `304`, and interim `1xx` responses;
- clean zero-length end-of-stream and repeated receives after it;
- one active receive per stream;
- `stop_aio()`, timeout, and close while a receive is pending;
- terminal state after an interrupted receive;
- HTTPS with caller-supplied `tls_config()`;
- bounded collection of a non-success response in Rho;
- the first SSE event while the server keeps the connection open, a later event,
  and clean completion.

Two defects in the historical prototype are now regression tests in the
rebased fork. The prototype accepted `chunked` anywhere in `Transfer-Encoding`
([body selection](https://github.com/RGenomicsETL/nanonext/blob/cf24957d95ae7d48e1f0e06df75d1d02d197b56a/src/ncurl.c#L352-L384)),
and treated every `1xx` head as a bodyless completed response. The current fork
accepts only the single supported `chunked` coding and continues past interim
heads until the final response. A public API rewrite must retain these fixes.
This is not a full HTTP parser conformance claim: ignored chunk extensions do
not yet receive complete syntax validation.

## 9. Questions for issue #329

1. Should the constructor be named `ncurl_stream()` while the existing
   `ncurl_session()` remains unchanged?
2. Should the returned object be an ordinary `nanoStream` or an HTTP subtype
   recognized by the ordinary `recv_aio()`, `stop_aio()`, and `close()` paths?
3. Should the constructor retain `response = NULL`, `TRUE`, or a character
   vector like the other ncurl functions?
4. Does cancelling or timing out a receive make the response stream terminal?
   This is the safe rule when a partial transport read may already have advanced
   HTTP framing state.
5. After end-of-stream, should every later receive immediately return `raw(0)`?
6. Should a later `close()` return the same error value as an ordinary closed
   nanonext stream?
7. Can a later asynchronous constructor resolve to the same stream type, while
   leaving `recv_aio()` as the only receive operation?

## Suggested issue reply

> Thanks. I read “like `ncurl_session()`” as a new synchronous constructor,
> perhaps `ncurl_stream()`, rather than a change to the existing reusable
> `ncurlSession`/`transact()` contract. The result would be a stream carrying the
> response status and requested headers; `recv_aio(stream, mode = "raw")` would
> return entity-body bytes, and `raw(0)` would mean end-of-stream.
>
> That shape is sufficient for Rho's incremental SSE semantics once the response
> is open. It removes the fork's separate `ncurl_stream_recv()` operation and
> `{data, complete}` result. The trade-off is that connect, request write, and
> response-head receipt are synchronous, so Rho cannot cancel or overlap that
> opening phase on the main R process. I think that is reasonable for an initial
> implementation if the timeout is explicit. A later asynchronous constructor
> could resolve to the same stream without changing the body API.
>
> I checked NNG 1.12 and the current 2.0 development API. Both publicly expose
> the required sequence: connect, write the request, read the response head, then
> read raw bytes. The C names and ownership differ, but a small set of
> nanonext-owned HTTP functions can have one implementation for each NNG version
> while keeping the R API stable. I would inspect NNG internals to confirm
> buffering and build tests, but avoid private `nni_*` symbols or a fabricated
> private `nng_stream`; that stream layout has changed in NNG 2.0.
>
> Raw HTTP reads do not provide an incremental decoded entity body, so nanonext
> still needs its small fixed-length/chunked/connection-ended state machine. The
> existing NNG chunk helper is private and assembles the complete body.
>
> The details I would like to confirm are whether the new constructor should
> preserve the ncurl `response` argument, whether cancellation or timeout makes
> the stream terminal, and whether repeated receives after EOF should continue
> returning `raw(0)`.
