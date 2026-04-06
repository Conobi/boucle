"""Linux epoll syscall wrappers."""

from ffi import external_call
from boucle._sys.linux.raw.x86_64.epoll import epoll_event


@fieldwise_init
struct EpollOp(ImplicitlyCopyable, Movable):
    """epoll_ctl operation constants."""
    comptime ADD = Self(1)
    comptime DEL = Self(2)
    comptime MOD = Self(3)

    var value: Int32


@always_inline
fn epoll_create() raises -> Int32:
    """Creates an epoll instance with CLOEXEC flag."""
    var res = external_call["epoll_create1", Int32](Int32(0x80000))  # O_CLOEXEC
    if res < 0:
        raise "epoll_create1 failed"
    return res


@always_inline
fn epoll_ctl(
    epfd: Int32, op: EpollOp, fd: Int32, ref event: epoll_event
) raises:
    """Add, modify, or remove a file descriptor from the epoll interest list."""
    var res = external_call["epoll_ctl", Int32](
        epfd,
        op.value,
        fd,
        UnsafePointer(to=event).bitcast[epoll_event](),
    )
    if res < 0:
        raise "epoll_ctl failed"


@always_inline
fn epoll_wait(
    epfd: Int32,
    events: UnsafePointer[epoll_event, ...],
    *,
    max_events: Int32,
    timeout: Int32 = -1,
) raises -> Int32:
    """Wait for events on the epoll instance.

    Returns the number of ready file descriptors.
    """
    var res = external_call["epoll_wait", Int32](
        epfd, events, max_events, timeout
    )
    if res < 0:
        raise "epoll_wait failed"
    return res
