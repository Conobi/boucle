# Runtime Evidence

Out-of-band record of real-traffic verification against this repository.
Boucle's automated test suite covers the I/O primitives but does not by
itself serve HTTP. The end-to-end proof points captured here come from
driving Boucle-backed servers (in companion repos / one-off harnesses)
with off-the-shelf clients (curl, hyper-h2, aioquic).

This file exists so the proof is durable inside this repo, not stranded
in a reviewer's notes.

## HTTP/1.1 — completion model

Server: a minimal `hello_h1_server` running on the `CompletionLoop`
accept/recv/send path, bound to `[::]:18080`.

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

Build: navette `hello_h1_server` built inside the VM as a native aarch64 ELF.
`boucle/socle/linux/raw/` auto-detects `uname -m == aarch64` via comptime
arch dispatch.

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

`navette/lib/librustls_mojo.so` and `libcompress_mojo.so` are pre-built
x86_64 only. Arm64 variants require `cargo build --target
aarch64-unknown-linux-gnu` on the navette Rust crates — orthogonal to
Boucle's I/O surface. The Boucle aarch64 dispatch is comprehensively
exercised by the h1 case above (io_uring + sockaddr + syscall ABI);
extending to h2/h3 is navette-side cross-compilation work.

## How to reproduce

These transcripts come from the companion `navette` / harness work that
sits on top of Boucle. They should be re-run whenever the public Boucle
surface area changes in a way that could affect h1/h2/h3 server bring-up.
The boucle examples in `examples/` exercise the lower-level
send/recv/accept/connect paths in a single process — they are not enough
to anchor "real client speaks to real server" evidence on their own.
