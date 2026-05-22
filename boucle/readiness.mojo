"""Readiness-based I/O — get notified when I/O is possible, then do it yourself.

Best for:
  - Multiplexed connections (HTTP/2, HTTP/3, QUIC)
  - Frequent cancellation (timeouts, request racing)
  - Fine-grained scheduling (stream prioritization)

You retain buffer ownership at all times. Cancel by simply
stopping to poll.

See `boucle.completion` for the alternative model.
"""

from boucle._sys.linux.epoll.syscalls import (
    epoll_create,
    epoll_ctl,
    epoll_wait,
    EpollOp,
)
from boucle._sys.linux.raw import epoll_event, EPOLLRDHUP
from boucle._sys.linux.fd import close
from boucle.interest import Interest
from boucle.readiness_state import Readiness
from boucle.token import Token
from std.memory import UnsafePointer
from std.memory.unsafe_pointer import alloc


trait ReadinessHandler(Movable, ImplicitlyDestructible):
    """Callback interface for readiness events."""

    def on_ready(mut self, token: Token, readiness: Readiness):
        ...


struct ReadinessLoop[Handler: ReadinessHandler]:
    """Event loop driven by epoll readiness notifications.

    Register file descriptors with interest flags, then poll to
    discover which ones are ready for I/O. You perform the actual
    I/O yourself after being notified.
    """

    var _epfd: Int32
    var _events: UnsafePointer[epoll_event, MutExternalOrigin]
    var _max_events: Int32
    var _handler: Self.Handler

    def __init__(
        out self, var handler: Self.Handler, *, max_events: Int32 = 64
    ) raises:
        self._epfd = epoll_create()
        self._max_events = max_events
        self._events = alloc[epoll_event](Int(max_events))
        self._handler = handler^

    def __del__(deinit self):
        self._events.free()
        close(unsafe_fd=self._epfd)

    def register(self, fd: Int32, interest: Interest, token: Token) raises:
        """Add a file descriptor to the interest list."""
        var ev = epoll_event(
            events=interest.value | EPOLLRDHUP,
            data=token.value,
        )
        epoll_ctl(self._epfd, EpollOp.ADD, fd, ev)

    def modify(self, fd: Int32, interest: Interest, token: Token) raises:
        """Modify the interest flags for a registered file descriptor."""
        var ev = epoll_event(
            events=interest.value | EPOLLRDHUP,
            data=token.value,
        )
        epoll_ctl(self._epfd, EpollOp.MOD, fd, ev)

    def deregister(self, fd: Int32) raises:
        """Remove a file descriptor from the interest list."""
        var ev = epoll_event()
        epoll_ctl(self._epfd, EpollOp.DEL, fd, ev)

    def poll(mut self, *, timeout_ms: Int32 = -1) raises:
        """Wait for readiness events and invoke handler for each."""
        var n = epoll_wait(
            self._epfd,
            self._events,
            max_events=self._max_events,
            timeout=timeout_ms,
        )
        for i in range(Int(n)):
            var ev = self._events[i]
            self._handler.on_ready(
                Token(ev.data),
                Readiness(ev.events),
            )
