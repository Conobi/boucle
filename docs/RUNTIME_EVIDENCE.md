# Runtime Evidence

Out-of-band record of real-traffic verification against this repository.
Boucle's automated test suite covers the I/O primitives but does not by
itself serve HTTP. The end-to-end proof points captured here come from
driving Boucle-backed servers (in companion repos / one-off harnesses)
with off-the-shelf clients (curl, hyper-h2, aioquic).

This file exists so the proof is durable inside this repo, not stranded
in a reviewer's report.

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

## How to reproduce

These transcripts come from the companion `navette` / harness work that
sits on top of Boucle. They were captured live during pass-2 review and
should be re-run whenever the public Boucle surface area changes in a
way that could affect h1/h2/h3 server bring-up. The boucle examples in
`examples/` exercise the lower-level send/recv/accept/connect paths in
a single process — they are not enough to anchor "real client speaks to
real server" evidence on their own.
