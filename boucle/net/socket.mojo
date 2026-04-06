"""A platform-agnostic, non-blocking socket.

Wraps an OwnedHandle and provides convenience constructors for common
socket configurations. All sockets are created with NONBLOCK and
CLOEXEC flags by default.
"""

from boucle.handle import RawHandle, OwnedHandle
from boucle.net.addr import SocketAddrStor
from boucle.net.options import (
    AddrFamily,
    SocketType,
    SocketFlags,
    Protocol,
    Backlog,
)
from boucle._sys.linux.net.socket import (
    socket as _sys_socket,
    bind as _sys_bind,
    listen as _sys_listen,
)


struct Socket:
    """A platform-agnostic, non-blocking socket."""

    var _handle: OwnedHandle

    @always_inline
    fn __init__(out self, var handle: OwnedHandle):
        self._handle = handle^

    @staticmethod
    fn tcp_v4() raises -> Self:
        """Creates a non-blocking TCP IPv4 socket."""
        return Self(
            _sys_socket(
                AddrFamily.INET,
                SocketType.STREAM,
                SocketFlags.NONBLOCK | SocketFlags.CLOEXEC,
                Protocol.TCP,
            )
        )

    @staticmethod
    fn tcp_v6() raises -> Self:
        """Creates a non-blocking TCP IPv6 socket."""
        return Self(
            _sys_socket(
                AddrFamily.INET6,
                SocketType.STREAM,
                SocketFlags.NONBLOCK | SocketFlags.CLOEXEC,
                Protocol.TCP,
            )
        )

    @staticmethod
    fn udp_v4() raises -> Self:
        """Creates a non-blocking UDP IPv4 socket."""
        return Self(
            _sys_socket(
                AddrFamily.INET,
                SocketType.DGRAM,
                SocketFlags.NONBLOCK | SocketFlags.CLOEXEC,
                Protocol.UDP,
            )
        )

    @staticmethod
    fn udp_v6() raises -> Self:
        """Creates a non-blocking UDP IPv6 socket."""
        return Self(
            _sys_socket(
                AddrFamily.INET6,
                SocketType.DGRAM,
                SocketFlags.NONBLOCK | SocketFlags.CLOEXEC,
                Protocol.UDP,
            )
        )

    fn bind[Addr: SocketAddrStor](self, ref addr: Addr) raises:
        """Binds the socket to the given address."""
        _sys_bind(self._handle, addr)

    fn listen(self, backlog: Backlog) raises:
        """Marks the socket as passive for accepting connections."""
        _sys_listen(self._handle, backlog)

    @always_inline
    fn raw(self) -> RawHandle:
        """Returns the underlying raw handle value."""
        return self._handle.raw()
