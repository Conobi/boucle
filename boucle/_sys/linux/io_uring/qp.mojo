from .cq import Cq, CqPtr
from .sq import Sq, SqPtr
from .modes import PollingMode, NOPOLL, IOPOLL, SQPOLL
from .mm import MemoryMapping, Region
from .params import Params
from boucle._sys.linux.io_uring.types import (
    Sqe,
    SQE,
    SQE64,
    Cqe,
    CQE,
    CQE16,
    IoUringParams,
    IoUringSetupFlags,
    IoUringFeatureFlags,
    IoUringSqFlags,
    IoUringEnterFlags,
    OwnedFd,
    EnterArg,
    NO_ENTER_ARG,
    RegisterArg,
    io_uring_setup,
    io_uring_register,
    io_uring_enter,
)
from boucle._sys.linux.raw.x86_64.io_uring import (
    IORING_OFF_SQ_RING,
    IORING_OFF_SQES,
)
from std.sys.info import size_of
from std.sys.intrinsics import unlikely


struct IoUring[
    sqe: SQE = SQE64,
    cqe: CQE = CQE16,
    polling: PollingMode = NOPOLL,
    *,
    is_registered: Bool = True,
](Movable):
    var _sq: Sq[Self.sqe, Self.polling]
    var _cq: Cq[Self.cqe]
    var fd: OwnedFd[Self.is_registered]
    var mem: MemoryMapping[Self.sqe, Self.cqe]

    # ===------------------------------------------------------------------=== #
    # Life cycle methods
    # ===------------------------------------------------------------------=== #

    fn __init__(out self, *, sq_entries: UInt32) raises:
        self = Self(sq_entries=sq_entries, params=Params())

    fn __init__(out self, *, sq_entries: UInt32, params: Params) raises:
        io_uring_params = IoUringParams()
        io_uring_params.cq_entries = params._cq_entries
        io_uring_params.flags = params.flags
        io_uring_params.sq_thread_cpu = params.sq_thread_cpu
        io_uring_params.sq_thread_idle = params.sq_thread_idle
        io_uring_params.wq_fd = params.wq_fd
        self = Self(sq_entries=sq_entries, params=io_uring_params)
        if params.is_dontfork():
            self.mem.dontfork()

    fn __init__(
        out self, *, sq_entries: UInt32, mut params: IoUringParams
    ) raises:
        constrained[
            Self.polling is not SQPOLL,
            "SQPOLL mode is disabled because Mojo does not have atomic fence",
        ]()
        comptime flags = Self.sqe.setup_flags | Self.cqe.setup_flags | Self.polling.setup_flags
        params.flags |= flags

        comptime if Self.is_registered:
            self.mem = MemoryMapping[Self.sqe, Self.cqe](sq_entries, params)
            self.fd = io_uring_setup[Self.is_registered](sq_entries, params)
        else:
            fd = io_uring_setup[Self.is_registered](sq_entries, params)
            if not params.features & IoUringFeatureFlags.SINGLE_MMAP:
                raise "system outdated"
            sq_len = params.sq_off.array + params.sq_entries * size_of[UInt32]()
            cq_len = params.cq_off.cqes + params.cq_entries * Self.cqe.size
            sq_cq_mem = Region(
                fd=fd.unsafe_fd(),
                offset=IORING_OFF_SQ_RING,
                len=Int(max(sq_len, cq_len)),
            )
            sqes_mem = Region(
                fd=fd.unsafe_fd(),
                offset=IORING_OFF_SQES,
                len=Int(params.sq_entries * Self.sqe.size),
            )
            self.fd = fd^
            self.mem = MemoryMapping[Self.sqe, Self.cqe](
                sqes_mem=sqes_mem^, sq_cq_mem=sq_cq_mem^
            )

        self._sq = Sq[Self.sqe, Self.polling](
            params,
            sq_cq_mem=self.mem.sq_cq_mem,
            sqes_mem=self.mem.sqes_mem,
        )
        self._cq = Cq[Self.cqe](params, sq_cq_mem=self.mem.sq_cq_mem)

    fn __del__(deinit self):
        # Ensure that `MemoryMapping` is released before `self.fd`
        # as it may depend on it.
        self.mem^.__del__()
        self.fd^.__del__()

    @always_inline
    fn __moveinit__(out self, deinit take: Self):
        """Moves data of an existing IoUring into a new one.

        Args:
            take: The existing IoUring.
        """
        self._sq = take._sq^
        self._cq = take._cq^
        self.fd = take.fd^
        self.mem = take.mem^

    # ===-------------------------------------------------------------------===#
    # Methods
    # ===-------------------------------------------------------------------===#

    @always_inline
    fn sq(
        mut self,
    ) -> SqPtr[Self.sqe, Self.polling, origin_of(self._sq)]:
        self.sync_sq_head()
        return self.unsynced_sq()

    @always_inline
    fn unsynced_sq(
        mut self,
    ) -> SqPtr[Self.sqe, Self.polling, origin_of(self._sq)]:
        return self._sq

    @always_inline
    fn sync_sq_head(mut self):
        self._sq.sync_head()

    @always_inline
    fn submit_and_wait(mut self, *, wait_nr: UInt32) raises -> UInt32:
        return self.submit_and_wait(wait_nr=wait_nr, arg=NO_ENTER_ARG)

    @always_inline
    fn submit_and_wait(
        mut self, *, wait_nr: UInt32, arg: EnterArg
    ) raises -> UInt32:
        submitted = self._sq.flush()
        flags = IoUringEnterFlags()

        cq_needs_enter = wait_nr > 0 or self.cq_needs_enter()

        if self.sq_needs_enter(submitted, flags) or cq_needs_enter:
            if cq_needs_enter:
                flags |= IoUringEnterFlags.GETEVENTS
            return self.enter(
                to_submit=submitted, min_complete=wait_nr, flags=flags, arg=arg
            )

        return submitted

    @always_inline
    fn sq_needs_enter(
        self, submitted: UInt32, mut flags: IoUringEnterFlags
    ) -> Bool:
        comptime if Self.polling is not SQPOLL:
            return True

        if submitted == 0:
            return False

        # FIXME: Need to use atomic fence here to ensure the kernel
        # can see the store to the `self._sq._tail` before we read the flags.
        # [Reference]: https://github.com/modularml/mojo/issues/3162.

        if unlikely(Bool(self._sq.flags() & IoUringSqFlags.NEED_WAKEUP)):
            flags |= IoUringEnterFlags.SQ_WAKEUP
            return True

        return False

    @always_inline
    fn cq(
        mut self, *, wait_nr: UInt32
    ) raises -> CqPtr[Self.cqe, origin_of(self._cq)]:
        return self.cq(wait_nr=wait_nr, arg=NO_ENTER_ARG)

    @always_inline
    fn cq(
        mut self, *, wait_nr: UInt32, arg: EnterArg
    ) raises -> CqPtr[Self.cqe, origin_of(self._cq)]:
        self.flush_cq(wait_nr, arg)
        return self._cq

    @always_inline
    fn flush_cq(mut self, wait_nr: UInt32, arg: EnterArg) raises:
        self._cq.sync_tail()
        if not self._cq and (wait_nr > 0 or self.cq_needs_flush()):
            _ = self.enter(
                to_submit=0,
                min_complete=wait_nr,
                flags=IoUringEnterFlags.GETEVENTS,
                arg=arg,
            )
            self._cq.sync_tail()

    @always_inline
    fn cq_needs_flush(self) -> Bool:
        return Bool(
            self._sq.flags()
            & (IoUringSqFlags.CQ_OVERFLOW | IoUringSqFlags.TASKRUN)
        )

    @always_inline
    fn cq_needs_enter(self) -> Bool:
        comptime if Self.polling is IOPOLL:
            return True
        else:
            return self.cq_needs_flush()

    @always_inline
    fn register(self, arg: RegisterArg) raises -> UInt32:
        return io_uring_register(self.fd, arg)

    @always_inline
    fn enter(
        self,
        *,
        to_submit: UInt32,
        min_complete: UInt32,
        flags: IoUringEnterFlags,
        arg: EnterArg,
    ) raises -> UInt32:
        return io_uring_enter(
            self.fd,
            to_submit=to_submit,
            min_complete=min_complete,
            flags=flags,
            arg=arg,
        )
