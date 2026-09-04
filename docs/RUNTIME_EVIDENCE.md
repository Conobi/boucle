# Runtime Evidence

Out-of-band record of real-traffic verification against this repository.
Boucle's automated test suite covers the I/O primitives but does not by
itself serve HTTP. The end-to-end proof points below came from driving
Boucle-backed servers (in the companion `navette` repo and one-off
harnesses, both outside this tree) with off-the-shelf clients.

This file exists so the proof is durable inside this repo, not stranded
in a reviewer's notes. It records **transcripts**, not tests: nothing
here is re-run by `mojox test`, and the harnesses that produced it live
elsewhere and are not pinned to a commit.

> [!IMPORTANT]
> These transcripts predate the 2026-09-04 API changes (owned `recv`/`send`
> buffers with `TransferResult`, `IOError` on every socket call, the
> `ReadinessRegistry` split, `CompletionLoop` moving to `boucle.proactor`).
> The *transport* claims below still hold — they are about syscalls and
> kernels — but the harness sources that produced them no longer compile
> against the current public API and must be updated before re-running.

## What is still verifiable in this tree

| Claim below | Where it lives now |
|---|---|
| completion path (`accept`/`recv`/`send`) | `boucle/proactor/completion_loop.mojo`, wrapped by `boucle/watch/loop.mojo` |
| readiness path | `boucle/readiness.mojo` |
| io_uring syscall entry | `boucle/socle/linux/raw/io_uring.mojo`, `__NR_io_uring_enter == 426` in `boucle/socle/linux/raw/general.mojo` |
| arch dispatch (x86_64 `syscall`, aarch64 `svc #0`) | `boucle/socle/linux/raw/syscall.mojo`, `boucle/socle/linux/abi.mojo` |

Arch selection is **comptime**, via `CompilationTarget` predicates re-exported
as `is_x86_64` / `is_aarch64` from `boucle/socle/__init__.mojo`. It is not a
runtime `uname` probe, contrary to how an earlier version of this file put it.

## HTTP/1.1 — completion model

Server: a minimal `hello_h1_server` on the completion accept/recv/send
path, bound to `[::]:18080`.

```
hello_h1_server: binding [::]:18080
hello_h1_server: listening (fd=...)
```

```
$ curl http://127.0.0.1:18080/
HTTP/1.1 200 OK
Hello, H1!
```

## HTTP/2 over TLS — completion model + ALPN=h2

Server: `hello_h2_server` (TLS termination + ALPN negotiation for `h2`),
client a small Python hyper-h2 harness.

```
hello_h2_server (TLS+ALPN=h2):
STATUS: 200
body: Hello, H2!
```

## HTTP/3 over QUIC — readiness model + aioquic

Server: `hello_h3_server` (QUIC datagrams on `ReadinessLoop`),
client `aioquic`.

```
hello_h3_server (aioquic over QUIC):
STATUS: 200
body: Hello, H3!
```

## Linux aarch64 — qemu-system + real arm64 kernel

Host x86_64 Manjaro, `qemu-system-aarch64` 11.0.0, TCG (no KVM cross-arch).

VM: Ubuntu 24.04.4 arm64, kernel `Linux 6.8.0-117-generic aarch64 GNU/Linux`,
native arm64 syscall ABI, full io_uring support.

Build: navette `hello_h1_server` built inside the VM as a native aarch64 ELF,
with Boucle's comptime arch dispatch resolving to the aarch64 branch.

Transport proof — `strace` on the running server:

```
io_uring_enter(0, 0, 1, IORING_ENTER_GETEVENTS|IORING_ENTER_REGISTERED_RING, NULL, 0)
```

That's `__NR_io_uring_enter == 426` on aarch64 (asm-generic UAPI),
dispatched via Boucle's `svc #0` path with `x8` carrying the syscall
number. Real io_uring on a real arm64 kernel.

Host-side `curl` through qemu user-mode hostfwd:

```
$ curl -si http://127.0.0.1:18080/
HTTP/1.1 200
content-type: text/plain
content-length: 11

Hello, H1!
```

Stable across 5 consecutive requests, ~2-5 ms each.

### h2 / h3 on aarch64

The navette Rust FFI shared objects are pre-built x86_64 only; arm64
variants need `cargo build --target aarch64-unknown-linux-gnu` on the
navette crates — orthogonal to Boucle's I/O surface. The Boucle aarch64
dispatch is exercised by the h1 case above (io_uring + sockaddr +
syscall ABI); extending to h2/h3 is navette-side cross-compilation work.

## How to reproduce

These transcripts come from companion work that sits on top of Boucle.
They should be re-run whenever the public Boucle surface changes in a way
that could affect h1/h2/h3 server bring-up — which it has, so the next
run needs the harnesses ported first. The examples in `examples/`
exercise the send/recv/accept/connect paths in a single process; they are
not enough to anchor "real client speaks to real server" evidence on
their own.
