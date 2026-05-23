"""Sanity test: representative symbols are re-exported via the raw facade.

Touches one symbol per source module under `boucle._sys.linux.raw.x86_64`
to force name resolution through the facade in
`boucle/_sys/linux/raw/__init__.mojo`. If any source module is dropped
from the facade's re-export list, this test fails to compile.
"""

from boucle._sys.linux.raw import syscall  # syscall.mojo
from boucle._sys.linux.raw import __NR_close, __kernel_timespec  # general.mojo
from boucle._sys.linux.raw import EPOLLIN, epoll_event  # epoll.mojo
from boucle._sys.linux.raw import EAGAIN, EINTR, EBADF  # errno.mojo
from boucle._sys.linux.raw import IORING_OP_NOP, IORING_OP_RECV, io_uring_buf  # io_uring.mojo
from boucle._sys.linux.raw import AF_INET, sockaddr_in, msghdr  # net.mojo
from boucle._sys.linux.raw import UCONTEXT_SIZE, REG_RIP  # ucontext.mojo


def main():
    # Touch a representative symbol per category to force resolution.
    comptime assert __NR_close == 3, "general.mojo: __NR_close == 3"
    comptime assert EPOLLIN == 0x001, "epoll.mojo: EPOLLIN == 0x001"
    comptime assert EAGAIN == 11, "errno.mojo: EAGAIN == 11"
    comptime assert EBADF == 9, "errno.mojo: EBADF == 9"
    comptime assert IORING_OP_NOP == 0, "io_uring.mojo: IORING_OP_NOP == 0"
    comptime assert IORING_OP_RECV == 27, "io_uring.mojo: IORING_OP_RECV == 27"
    comptime assert AF_INET == 2, "net.mojo: AF_INET == 2"
    comptime assert UCONTEXT_SIZE == 968, "ucontext.mojo: UCONTEXT_SIZE == 968"
    comptime assert REG_RIP == 16, "ucontext.mojo: REG_RIP == 16"

    # Construct one re-exported struct from each struct-bearing module to
    # confirm the type itself (not just the bare name) is reachable.
    var ev = epoll_event(events=0, data=0)
    _ = ev
    var buf = io_uring_buf()
    _ = buf
    var ts = __kernel_timespec(0, 0)
    _ = ts

    print("PASS")
