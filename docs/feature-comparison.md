# Feature comparison: Boucle and its siblings

A comparison of *what each library does*, not how fast it does it. It covers
Boucle and the six libraries that shaped its design:

| Library | Language | What it is |
|---|---|---|
| [mio](https://github.com/tokio-rs/mio) | Rust | Readiness-only foundation under Tokio |
| [libuv](https://github.com/libuv/libuv) | C | Unified callback loop under Node.js |
| [compio](https://github.com/compio-rs/compio) | Rust | Completion-only runtime, io_uring / IOCP first |
| [monoio](https://github.com/bytedance/monoio) | Rust | Thread-per-core completion runtime |
| [libxev](https://github.com/mitchellh/libxev) | Zig | Cross-platform proactor loop, io_uring-shaped |
| [TigerBeetle `src/io`](https://github.com/tigerbeetle/tigerbeetle/tree/main/src/io) | Zig | Internal completion layer of the TigerBeetle database |

Boucle's column was verified against the code in this repository. The other
columns come from each project's documentation, source and release pages as of
**2026-09-05**; links are in the notes at the end. Corrections welcome.

Boucle is at version 0.1.0, Linux-only, and not production-ready. Every other
library here is older, has more users, and runs on more platforms. The tables
below make that visible rather than hiding it.

Legend: ✅ available on the public API · ◐ partial (see note) · ❌ absent ·
— not applicable.

## 1. Identity and maturity

| | Boucle | mio | libuv | compio | monoio | libxev | TigerBeetle io |
|---|---|---|---|---|---|---|---|
| License | MIT | MIT | MIT | MIT | MIT / Apache-2.0 | MIT | Apache-2.0 |
| First release | 2026 | 2014 | 2011 | 2023 | 2021 | 2023 | 2020 |
| Latest release | 0.1.0 | 1.2.3 (2026-09) | 1.52.1 (2026-03) | 0.19.2 (2026-08) | 0.2.4 (2024-08) | untagged HEAD | 0.17.9 (2026-07) |
| Published as a library | yes | yes | yes | yes | yes | yes | no (internal) |
| Notable users | none yet | Tokio | Node.js, Julia, CMake, BIND 9 | ntex, cyper | ByteDance, monolake | Ghostty, zml | TigerBeetle |
| CI | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Self-declared status | "not production-ready" | stable | stable | active, pre-1.0 | active, pre-1.0 | "stable for most use cases" | production |

## 2. I/O model, backends, platforms

| | Boucle | mio | libuv | compio | monoio | libxev | TigerBeetle io |
|---|---|---|---|---|---|---|---|
| Model exposed | readiness **and** completion, separate APIs | readiness | hidden behind callbacks | completion | completion | completion | completion |
| Readiness escape hatch on a completion API | — | — | `uv_poll_t` | `PollOnce` op | `readable()` / `poll-io` | `poll` op | ❌ |
| io_uring | ✅ | ❌ | file ops only, opt-in | ✅ | ✅ | ✅ | ✅ |
| epoll | ✅ | ✅ | ✅ | via `polling` | via mio | ✅ (self-described "a bit of a mess") | ❌ |
| kqueue | ❌ | ✅ | ✅ | via `polling` | via mio | ✅ (needs mach ports) | ✅ |
| IOCP | ❌ | readiness emulation (AFD) | ✅ | ✅ | readiness emulation, unstable | ✅ (README still says "planned") | ✅ |
| Other backends | — | event ports, poll(2), WASI | event ports | AIO on BSD/illumos | — | WASI poll | — |
| Completion emulated over readiness | ✅ (`EpollCompletionDriver`) | — | writes only | ✅ | ✅ | ✅ | ✅ (kqueue) |
| Backend selection | runtime probe, io_uring → epoll; `Backend` enum override | compile-time only | compile-time, env opt-in | compile-time + runtime probe + override | compile-time + runtime probe + env override | compile-time default, optional runtime `Dynamic` | compile-time only |
| Linux | ✅ (x86_64 tested, aarch64 compiled, untested) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (kernel ≥ 5.11) |
| macOS | ❌ | ✅ | ✅ | ✅ | ✅ (legacy driver only) | ✅ | ✅ |
| Windows | ❌ | ✅ | ✅ | ✅ | experimental | ✅ | ✅ |
| BSDs, illumos, WASI, mobile | ❌ | ✅ broad | ✅ tiers | CI for BSD/illumos/Android/iOS | ❌ | WASI; FreeBSD partial | ❌ |

## 3. Operations

"Public" means reachable from the portable API. Boucle has several io_uring
features that exist only on the driver struct, behind an explicit
`boucle.drivers.io_uring` import that also gives up the epoll fallback; those
are marked ◐.

| | Boucle | mio | libuv | compio | monoio | libxev | TigerBeetle io |
|---|---|---|---|---|---|---|---|
| TCP accept / connect / recv / send | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Connect with timeout | ✅ | — | ✅ | ✅ (`timeout` combinator) | ✅ (`timeout` combinator) | ✅ (compose timer + cancel) | ❌ |
| UDP send_to / recv_from | ✅ `WatchLoop.send_to` / `recv_from` (completion), plus blocking `Socket` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| sendmsg / recvmsg | ✅ `WatchLoop.send_msg` / `recv_msg` (`Message`, cmsg walker, ECN, GSO/GRO records); raw `CompletionLoop` too | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Vectored I/O | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Unix domain sockets | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Pipes as sources | ✅ (readiness, raw fd) | ✅ | ✅ | ✅ | ✅ | ✅ (generic stream) | ❌ |
| File open / read / write / fsync | ◐ read/write/fsync (no open); io_uring native, epoll via thread pool | ❌ by design | ✅ (thread pool) | ✅ | ✅ | ◐ read/write only, thread pool on epoll/kqueue | ✅ |
| Timers | ✅ | ❌ by design | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cancel an in-flight op | ◐ timers on `WatchLoop`: cancel and reset; other ops on raw `CompletionLoop` only | deregister | subset of request types | ✅ (best effort) | ✅ | ✅ | ❌ |
| Multishot accept / recv | ◐ multishot recvmsg on `WatchLoop` (`recv_msg_multishot`, epoll-emulated); multishot accept driver only | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Provided buffers / buffer rings | ✅ `WatchLoop.buffer_pool` (buffer ring on io_uring, free list on epoll) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Zero-copy send | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Splice / sendfile | ❌ | ❌ | sendfile | ✅ | ✅ | ❌ | ❌ |
| Signals | ❌ | ❌ | ✅ | ✅ | ✅ (ctrlc) | ❌ roadmap | ❌ |
| Child processes | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Filesystem events | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ roadmap | ❌ |
| TTY | ❌ | ❌ | ✅ | ❌ | ❌ | ◐ generic stream | ❌ |
| DNS resolution | ❌ | ❌ | ✅ (thread pool) | ✅ (thread pool) | ❌ | ❌ | ❌ |
| Thread pool for blocking work | ✅ `WorkerPool` (pthread, eventfd wakeup) | ❌ by design | ✅ | ✅ | ✅ | ✅ optional | ❌ |
| Cross-thread wakeup | ✅ eventfd (`WorkerPool` wakeup) | ✅ `Waker` | ✅ `uv_async_t` | ✅ | ✅ | ✅ `Async` | ✅ eventfd / EVFILT_USER |

## 4. Sockets, buffers, concurrency, errors, extensibility

| | Boucle | mio | libuv | compio | monoio | libxev | TigerBeetle io |
|---|---|---|---|---|---|---|---|
| IPv6 | ✅ every address-taking call accepts `SocketAddrV4` or `SocketAddrV6` | ✅ | ✅ | ✅ | ✅ | ✅ | likely |
| `SO_REUSEADDR` / `SO_REUSEPORT` | ✅ / ✅ | via socket2 | ✅ / ✅ | ✅ | ✅ | reuseaddr only | ✅ |
| `TCP_NODELAY` | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Keepalive | ❌ | via socket2 | ✅ | via socket2 | ✅ | ❌ | ✅ |
| Buffer size, multicast, TTL | ✅ buffer size (`SO_RCVBUF`/`SO_SNDBUF`), UDP GSO/GRO (`UDP_SEGMENT`/`UDP_GRO`); no multicast or TTL | multicast, TTL | ✅ | ✅ | buffer size | ❌ | buffer size |
| Buffer ownership (completion path) | owned, moved into loop, returned by `result()` | — | caller-owned, alive until callback | owned, returned in `BufResult` | owned, returned in `BufResult` | caller-owned, alive until callback | caller-owned, alive until callback |
| Buffer ownership (readiness path) | caller-owned slices | caller-owned slices | `alloc_cb` per read | — | — | — | — |
| Allocation per submitted operation | none steady-state: per-kind chunked slab, one settle-queue push per op | none (caller allocates) | none (caller allocates) | one heap cell per op (`RawOp` behind `Key<T>`) | slab of lifecycles, op data lives in the future | none (caller allocates) | none (caller allocates) |
| Programming style | futures resolved by `run()`; callbacks on raw loop; stackful coroutines | sync poll loop | callbacks | async/await | async/await | callbacks | callbacks |
| Executor bundled | ❌ | ❌ | loop only | ✅ | ✅ | ❌ | ❌ |
| Threading | single-threaded; enforced by the kernel on io_uring via `SINGLE_ISSUER` (EEXIST from any other thread), unenforced on epoll | one `Poll` per thread, user's job | one loop per thread | thread-per-core dispatcher | thread-per-core | one loop per thread | single-threaded |
| Drop a future / completion mid-op | safe; loop keeps state until completion | — | — | cancels, best effort | async-cancel, buffer held | UB (plain memory) | — |
| Loop destroyed with ops in flight | buffers leaked on purpose (bounded); slab chunks too if a future is still held | — | must `uv_close` first | ring closed before freeing keys | — | — | — |
| Error type | `IOError` (errno), typed `raises` | `io::Error` | negative int codes | `io::Error` | `io::Error` | per-op error sets | per-op error sets |
| Custom event source / fd | ✅ readiness `register_raw` | ✅ `Source` trait | `uv_poll_t` | ✅ | — | generic stream | — |
| User-defined operations | ❌ closed `IoDriver` trait | — | — | ✅ `OpCode` trait | ❌ crate-private | ❌ | ❌ |
| User-supplied backend | ◐ `EventLoop[D: IoDriver]` only; ergonomic loops are hard-wired | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Two-level API (portable + raw) | ✅ `WatchLoop` over `CompletionLoop` over drivers | `net` + `os-ext` | portable + backend fds | high-level crates over `Proactor` | ❌ | ✅ explicit | ❌ |
| Protocol / TLS stack | none by design (sans-I/O) | none | none | TLS, QUIC, WS crates | none | none | — |

## 5. Reading the tables

**What Boucle does that the others don't.** It is the only library here that
exposes readiness and completion as two first-class, separately importable APIs
over the same socket and error types. mio is readiness-only, compio and monoio
are completion-only, libuv and libxev hide the distinction. The others do offer
a readiness escape hatch on top of a completion API, which covers some of the
same ground with less ceremony.

**Where Boucle is at parity.** Runtime io_uring probing with epoll fallback
matches compio and monoio. Completion emulated over epoll is a real driver,
comparable in intent to libxev's and compio's polling paths. Moving buffers
into the loop and handing them back with the result is the same rule compio and
monoio use. Typed `IOError` with errno predicates is comparable to `io::Error`.
Per-operation state lives in loop-owned slabs whose chunks never move, so
submitting an operation is a free-list pop and completing one is an index
lookup plus one queue push, the same shape as monoio's lifecycle slab and
tokio-uring's; libxev and TigerBeetle still do strictly less by making the
caller own the completion. The receive buffer is the one allocation left on
the path, and it is the caller's: reuse it via `take_buffer()`.

**Where Boucle is behind, by a lot.**

- **Platforms.** Linux only. Every other library runs on macOS, and all but
  monoio's stable line run on Windows. mio and libuv cover a dozen more.
- **Operation surface.** File read/write/fsync landed (io_uring native, epoll via
  thread pool); no file open, no vectored I/O, no Unix domain sockets, no
  signals, processes, filesystem events or DNS. libuv and compio have all of
  these. Boucle's public completion API: accept, connect, connect with
  timeout, recv, send, send_msg/recv_msg, send_to/recv_from, file read/write/
  fsync, buffer pools and a multishot recvmsg stream.
- **io_uring depth.** Multishot recvmsg and provided buffers are on
  `WatchLoop` and `CompletionLoop` on both backends. Multishot accept and
  multishot TCP recv remain driver-only. compio also ships zero-copy send and
  splice on its public API.
- **Cancellation.** `WatchLoop` cancels and resets timers only (plus the
  built-in connect timeout); every other operation can be cancelled on the
  raw `CompletionLoop` alone. Every other library except TigerBeetle cancels
  any operation.
- **Concurrency.** Cross-thread wakeup exists only as the `WorkerPool`'s
  eventfd path; there is no general-purpose `Waker` a user thread can fire to
  unblock `run()`. Every other library except TigerBeetle provides one.
- **Socket options.** No `TCP_NODELAY`, no keepalive. These are table stakes
  in mio, libuv, compio, monoio and TigerBeetle.
- **Async integration.** No async/await, no executor, no waker. compio and
  monoio are full runtimes. Boucle offers `run()` plus futures you read
  afterwards, and a stackful coroutine bridge on ucontext.
- **Process.** No CI, one contributor, no external users, an unsettled API.

**Things to be careful about when comparing.**

- TigerBeetle's I/O layer is not a library. It is tuned for one database and
  omits cancellation and UDP on purpose.
- libxev's Windows support is present in source but its README still lists it
  as planned. Its epoll backend is described by its author as lower quality
  than the others.
- monoio's last tagged release is from 2024, although the branch is active.
- libuv uses io_uring only for file operations, and turned it off by default
  again in 1.49.
- "Vectored I/O" in mio means the standard library `read_vectored` traits over a
  readiness socket, not a submitted operation.

## Sources

Boucle: this repository at the commit that added this file. Readiness API in
`boucle/readiness.mojo`, completion API in `boucle/watch/loop.mojo`, driver
trait in `boucle/drivers/driver.mojo`, io_uring-only methods in
`boucle/drivers/io_uring.mojo`, socket options in `boucle/net/socket.mojo`,
aligned buffers in `boucle/buffer/aligned.mojo`, file I/O futures in
`boucle/watch/read_file.mojo` / `write_file.mojo` / `fsync.mojo`, worker pool
in `boucle/pool/pool.mojo`.

mio: [README](https://github.com/tokio-rs/mio), [crates.io](https://crates.io/crates/mio),
[`Poll`](https://docs.rs/mio/latest/mio/struct.Poll.html),
[`Waker`](https://docs.rs/mio/latest/mio/struct.Waker.html),
[`Source`](https://docs.rs/mio/latest/mio/event/trait.Source.html),
[`TcpStream`](https://docs.rs/mio/latest/mio/net/struct.TcpStream.html),
[io_uring issue #1591](https://github.com/tokio-rs/mio/issues/1591).

libuv: [design overview](https://docs.libuv.org/en/v1.x/design.html),
[fs](https://docs.libuv.org/en/v1.x/fs.html), [request / `uv_cancel`](https://docs.libuv.org/en/v1.x/request.html),
[tcp](https://docs.libuv.org/en/v1.x/tcp.html), [udp](https://docs.libuv.org/en/v1.x/udp.html),
[supported platforms](https://github.com/libuv/libuv/blob/v1.x/SUPPORTED_PLATFORMS.md),
[releases](https://github.com/libuv/libuv/releases).

compio: [repository](https://github.com/compio-rs/compio), [crates.io](https://crates.io/crates/compio),
[`op` module](https://docs.rs/compio-driver/latest/compio_driver/op/index.html),
[`ProactorBuilder`](https://docs.rs/compio-driver/latest/compio_driver/struct.ProactorBuilder.html),
[compio-buf](https://docs.rs/compio-buf/latest/compio_buf/),
[fusion driver](https://github.com/compio-rs/compio/tree/master/compio-driver/src/sys/driver/fusion),
[future cancellation](https://github.com/compio-rs/compio/blob/master/compio-runtime/src/future/future.rs).

monoio: [repository](https://github.com/bytedance/monoio), [docs.rs](https://docs.rs/monoio/latest/monoio/),
[`op.rs`](https://github.com/bytedance/monoio/blob/master/monoio/src/driver/op.rs),
[uring detection](https://github.com/bytedance/monoio/blob/master/monoio/src/utils/uring_detect.rs),
[releases](https://github.com/bytedance/monoio/releases).

libxev: [README](https://github.com/mitchellh/libxev),
[`dynamic.zig`](https://github.com/mitchellh/libxev/blob/main/src/dynamic.zig),
[`backend/io_uring.zig`](https://github.com/mitchellh/libxev/blob/main/src/backend/io_uring.zig),
[`backend/epoll.zig`](https://github.com/mitchellh/libxev/blob/main/src/backend/epoll.zig),
[`watcher/`](https://github.com/mitchellh/libxev/tree/main/src/watcher).

TigerBeetle: [`src/io.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/io.zig),
[`src/io/linux.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/io/linux.zig),
[`src/io/darwin.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/io/darwin.zig),
[`src/io/common.zig`](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/io/common.zig),
[blog post](https://tigerbeetle.com/blog/2022-11-23-a-friendly-abstraction-over-iouring-and-kqueue/).
