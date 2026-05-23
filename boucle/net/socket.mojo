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
from boucle._sys.linux.net.syscalls import _setsockopt, _connect
from boucle._sys.linux.raw import (
    SOL_SOCKET,
    SO_REUSEADDR,
    SO_REUSEPORT,
    IPPROTO_IPV6,
    IPV6_V6ONLY,
)


struct Socket:
    """A platform-agnostic, non-blocking socket."""

    var _handle: OwnedHandle

    @always_inline
    def __init__(out self, var handle: OwnedHandle):
        self._handle = handle^

    @staticmethod
    def tcp_v4() raises -> Self:
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
    def tcp_v6() raises -> Self:
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
    def udp_v4() raises -> Self:
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
    def udp_v6() raises -> Self:
        """Creates a non-blocking UDP IPv6 socket."""
        return Self(
            _sys_socket(
                AddrFamily.INET6,
                SocketType.DGRAM,
                SocketFlags.NONBLOCK | SocketFlags.CLOEXEC,
                Protocol.UDP,
            )
        )

    def bind[Addr: SocketAddrStor](self, ref addr: Addr) raises:
        """Binds the socket to the given address."""
        _sys_bind(self._handle, addr)

    def listen(self, backlog: Backlog) raises:
        """Marks the socket as passive for accepting connections."""
        _sys_listen(self._handle, backlog)

    def set_reuse_addr(self, value: Bool = True) raises:
        """Sets `SO_REUSEADDR` on the socket."""
        _setsockopt(
            self._handle, Int32(SOL_SOCKET), Int32(SO_REUSEADDR),
            Int32(1) if value else Int32(0),
        )

    def set_reuse_port(self, value: Bool = True) raises:
        """Sets `SO_REUSEPORT` on the socket."""
        _setsockopt(
            self._handle, Int32(SOL_SOCKET), Int32(SO_REUSEPORT),
            Int32(1) if value else Int32(0),
        )

    def set_v6only(self, value: Bool) raises:
        """Sets `IPV6_V6ONLY` on an IPv6 socket. `False` enables dual-stack."""
        _setsockopt(
            self._handle, Int32(IPPROTO_IPV6), Int32(IPV6_V6ONLY),
            Int32(1) if value else Int32(0),
        )

    @always_inline
    def raw(self) -> RawHandle:
        """Returns the underlying raw handle value."""
        return self._handle.raw()
