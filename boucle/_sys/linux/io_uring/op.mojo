from boucle._sys.linux.io_uring.types import (
    Sqe,
    SQE,
    SQE128,
    addr3_struct,
    IoUringOp,
    IoUringSqeFlags,
    IoUringFileDescriptor,
    IoUringFd,
)
from boucle._sys.linux.fd import NoFd
from memory import UnsafePointer


@always_inline
fn _prep_rw[
    Fd: IoUringFileDescriptor
](mut sqe: Sqe, op: IoUringOp, fd: Fd, addr: UInt64, len: UInt32):
    sqe.opcode = op
    sqe.flags = Fd.SQE_FLAGS
    sqe.ioprio = 0
    sqe.fd = fd.unsafe_fd()
    sqe.off_or_addr2_or_cmd_op = 0
    sqe.addr_or_splice_off_in_or_msgring_cmd = addr
    sqe.len_or_poll_flags = len
    sqe.op_flags = 0
    sqe.user_data = 0
    sqe.buf_index_or_buf_group = 0
    sqe.personality = 0
    sqe.splice_fd_in_or_file_index_or_optlen_or_addr_len = 0
    sqe.addr3_or_optval_or_cmd = addr3_struct()

    comptime if sqe.type is SQE128:
        sqe._big_sqe = sqe.Array(0)


trait SqeAttrs:
    fn user_data(var self, value: UInt64) -> Self:
        ...

    fn personality(var self, value: UInt16) -> Self:
        ...

    fn sqe_flags(var self, flags: IoUringSqeFlags) -> Self:
        ...


trait Operation(SqeAttrs, Movable):
    ...


struct Nop[type: SQE, origin: MutOrigin](RegisterPassable, Operation):
    """Do not perform any I/O.
    A no-op is more useful than may appear at first glance.
    For example, you could set `IOSQE_IO_DRAIN_BIT` using `sqe_flags()`,
    to use the no-op to know when the ring is idle before acting
    on a kill signal. Also this is useful for testing the performance
    of the `io_uring` implementation itself.
    """

    comptime SINCE = 5.1

    var sqe: Pointer[Sqe[Self.type], Self.origin]

    @always_inline
    fn __init__(out self, ref [Self.origin]sqe: Sqe[Self.type]):
        _prep_rw(
            sqe,
            IoUringOp.NOP,
            IoUringFd[False](unsafe_fd=NoFd),
            0,
            0,
        )
        self.sqe = Pointer(to=sqe)

    @always_inline("nodebug")
    fn user_data(var self, value: UInt64) -> Self:
        self.sqe[].user_data = value
        return self^

    @always_inline("nodebug")
    fn personality(var self, value: UInt16) -> Self:
        self.sqe[].personality = value
        return self^

    @always_inline("nodebug")
    fn sqe_flags(var self, flags: IoUringSqeFlags) -> Self:
        self.sqe[].flags |= flags
        return self^
