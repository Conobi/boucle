"""Ergonomic socket operation wrappers.

Provides overloaded `socket`, `bind`, and `listen` functions that
accept the portable option types and delegate to the raw syscall
wrappers in `syscalls.mojo`.
"""

from boucle.handle import OwnedHandle
from boucle.net.addr import SocketAddr, SocketAddrStor
from boucle.net.options import AddrFamily, SocketType, SocketFlags, Protocol, Backlog
from boucle._sys.linux.net.syscalls import _socket, _bind, _listen


@always_inline
fn socket(domain: AddrFamily, type: SocketType) raises -> OwnedHandle:
    """Creates a socket with default flags and protocol."""
    return _socket(domain, type, SocketFlags(), Protocol())


@always_inline
fn socket(
    domain: AddrFamily, type: SocketType, protocol: Protocol
) raises -> OwnedHandle:
    """Creates a socket with the given protocol and default flags."""
    return _socket(domain, type, SocketFlags(), protocol)


@always_inline
fn socket(
    domain: AddrFamily,
    type: SocketType,
    flags: SocketFlags,
    protocol: Protocol,
) raises -> OwnedHandle:
    """Creates a socket with explicit flags and protocol."""
    return _socket(domain, type, flags, protocol)


@always_inline
fn bind[Addr: SocketAddrStor](ref handle: OwnedHandle, ref addr: Addr) raises:
    """Binds a socket to the given address (SocketAddrStor variant)."""
    var stor = addr.addr_stor()
    _bind(handle, stor)


@always_inline
fn bind[Addr: SocketAddr](ref handle: OwnedHandle, ref addr: Addr) raises:
    """Binds a socket to the given address (SocketAddr variant)."""
    _bind(handle, addr)


@always_inline
fn listen(ref handle: OwnedHandle, backlog: Backlog) raises:
    """Marks the socket as a passive socket for accepting connections."""
    _listen(handle, backlog)
