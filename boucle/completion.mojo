"""Completion-based I/O — submit work, get notified when done.

Best for:
  - Bulk data transfer (file serving, streaming)
  - Batching many operations (database engines, storage)
  - Workloads where cancellation is rare

The kernel performs I/O on your behalf. You hand over buffer
ownership and get it back on completion.

See `boucle.readiness` for the alternative model.
"""

from boucle._sys.linux.io_uring import IoUring
from boucle._sys.linux.io_uring.op import Nop, Read, Write, Recv, Send, Accept, Connect, RecvMsg, SendMsg, Timeout, ProvideBuffers
from boucle._sys.linux.io_uring.types import IoUringAcceptFlags, IoUringSqeFlags
from boucle._sys.linux.raw.ctypes import c_void
from boucle._sys.linux.raw.x86_64.io_uring import IORING_RECV_MULTISHOT
from boucle.handle import RawHandle
from std.memory import UnsafePointer


trait CompletionHandler(Movable, ImplicitlyDestructible):
    fn on_complete(mut self, token: UInt64, result: Int32, flags: UInt32):
        ...


struct CompletionLoop[Handler: CompletionHandler]:
    """Event loop driven by kernel completions (io_uring on Linux).

    Submit I/O operations and poll for completions. Each completed
    operation invokes `Handler.on_complete` with the token, result,
    and flags from the kernel.
    """

    var _ring: IoUring[]
    var _pending: UInt32
    var _handler: Self.Handler

    fn __init__(out self, var handler: Self.Handler, sq_entries: UInt32 = 64) raises:
        self._ring = IoUring[](sq_entries=sq_entries)
        self._pending = 0
        self._handler = handler^

    fn submit_nop(mut self, token: UInt64 = 0) raises:
        """Queue a no-op. Useful for testing and drain synchronisation."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (nop)"
        _ = Nop(sq.__next__()).user_data(token)
        self._pending += 1

    fn submit_read(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
        offset: UInt64 = 0,
    ) raises:
        """Queue a read from `fd` into `buf`."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (read)"
        _ = Read(sq.__next__(), fd, buf, len).user_data(token).offset(offset)
        self._pending += 1

    fn submit_write(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
        offset: UInt64 = 0,
    ) raises:
        """Queue a write from `buf` to `fd`."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (write)"
        _ = Write(sq.__next__(), fd, buf, len).user_data(token).offset(offset)
        self._pending += 1

    fn submit_recv(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
    ) raises:
        """Queue a recv from socket `fd` into `buf`."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recv)"
        _ = Recv(sq.__next__(), fd, buf, len).user_data(token)
        self._pending += 1

    fn submit_send(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
    ) raises:
        """Queue a send on socket `fd` from `buf`."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (send)"
        _ = Send(sq.__next__(), fd, buf, len).user_data(token)
        self._pending += 1

    fn submit_accept(mut self, fd: RawHandle, token: UInt64) raises:
        """Queue an accept on listening socket `fd`."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (accept)"
        _ = Accept(sq.__next__(), fd).user_data(token)
        self._pending += 1

    fn submit_accept_multishot(mut self, fd: RawHandle, token: UInt64) raises:
        """Queue a multishot accept on listening socket `fd`.

        Produces one CQE per accepted connection. Re-submit only when
        CQE flags lack IORING_CQE_F_MORE (multishot ended).
        Requires kernel >= 5.19.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (accept_multishot)"
        _ = Accept(sq.__next__(), fd).ioprio(IoUringAcceptFlags.MULTISHOT.value).user_data(token)
        self._pending += 1

    fn submit_connect(
        mut self,
        fd: RawHandle,
        addr_unsafe_ptr: UnsafePointer[Int8, StaticConstantOrigin],
        addr_len: UInt64,
        token: UInt64,
    ) raises:
        """Queue a connect on socket `fd` to the given address.

        The memory pointed to by `addr_unsafe_ptr` must remain valid
        until the completion fires.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (connect)"
        _ = Connect(sq.__next__(), fd, addr_unsafe_ptr, addr_len).user_data(
            token
        )
        self._pending += 1

    fn submit_recvmsg(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
        flags: UInt32 = 0,
    ) raises:
        """Queue a recvmsg on socket `fd`.

        The memory pointed to by `msghdr_ptr` (and all buffers it
        references) must remain valid until the completion fires.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recvmsg)"
        _ = RecvMsg(sq.__next__(), fd, msghdr_ptr).recv_flags(flags).user_data(
            token
        )
        self._pending += 1

    fn submit_sendmsg(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
        flags: UInt32 = 0,
    ) raises:
        """Queue a sendmsg on socket `fd`.

        The memory pointed to by `msghdr_ptr` (and all buffers it
        references) must remain valid until the completion fires.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (sendmsg)"
        _ = SendMsg(sq.__next__(), fd, msghdr_ptr).send_flags(flags).user_data(
            token
        )
        self._pending += 1

    fn submit_timeout(
        mut self,
        ts_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
    ) raises:
        """Queue a timeout. `ts_ptr` points to a 16-byte kernel_timespec.

        CQE result is -ETIME on normal expiry, 0 if canceled.
        The memory pointed to by `ts_ptr` must remain valid until
        the completion fires.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (timeout)"
        _ = Timeout(sq.__next__(), ts_ptr).user_data(token)
        self._pending += 1

    fn provide_buffers(
        mut self,
        buf_base: UnsafePointer[UInt8, MutAnyOrigin],
        buf_size: Int,
        count: Int,
        group_id: UInt16,
        base_buf_id: UInt16,
        token: UInt64 = 0,
    ) raises:
        """Register count contiguous buffers with io_uring.

        Buffers are contiguous: buf_base[i * buf_size .. (i+1) * buf_size].
        Each buffer gets ID base_buf_id + i.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (provide_buffers)"
        var buf_ptr = UnsafePointer[c_void, StaticConstantOrigin](
            unsafe_from_address=Int(buf_base)
        )
        _ = ProvideBuffers(
            sq.__next__(),
            buf_ptr,
            UInt32(buf_size),
            UInt32(count),
            group_id,
            base_buf_id,
        ).user_data(token)
        self._pending += 1

    fn reprovide_buffer(
        mut self,
        buf_ptr: UnsafePointer[UInt8, MutAnyOrigin],
        buf_size: Int,
        group_id: UInt16,
        buf_id: UInt16,
        token: UInt64 = 0,
    ) raises:
        """Re-provide a single buffer after processing its data."""
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (reprovide_buffer)"
        var ptr = UnsafePointer[c_void, StaticConstantOrigin](
            unsafe_from_address=Int(buf_ptr)
        )
        _ = ProvideBuffers(
            sq.__next__(),
            ptr,
            UInt32(buf_size),
            UInt32(1),
            group_id,
            buf_id,
        ).user_data(token)
        self._pending += 1

    fn submit_recvmsg_multishot(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        buf_group: UInt16,
        token: UInt64,
    ) raises:
        """Queue a multishot recvmsg with provided buffer selection.

        Produces one CQE per received message. The buffer ID is in
        CQE.flags >> 16 when IORING_CQE_F_BUFFER is set.
        Re-submit when CQE flags lack IORING_CQE_F_MORE.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recvmsg_multishot)"
        _ = RecvMsg(sq.__next__(), fd, msghdr_ptr)
            .ioprio(UInt16(IORING_RECV_MULTISHOT))
            .sqe_flags(IoUringSqeFlags.BUFFER_SELECT)
            .buf_group(buf_group)
            .user_data(token)
        self._pending += 1

    fn submit_recv_multishot(
        mut self,
        fd: RawHandle,
        buf_group: UInt16,
        token: UInt64,
    ) raises:
        """Queue a multishot recv with provided buffer selection (TCP).

        Like submit_recv but the kernel selects a buffer from `buf_group`
        per arrival and produces one CQE per chunk. Unlike recvmsg, the
        payload begins at offset 0 of the chosen buffer (no
        io_uring_recvmsg_out header). The buffer ID is in
        CQE.flags >> 16 when IORING_CQE_F_BUFFER is set; re-submit when
        CQE flags lack IORING_CQE_F_MORE.

        Buffer pointer (NULL) and length (0) are placeholders — the
        kernel ignores them when BUFFER_SELECT is set.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recv_multishot)"
        var null_ptr = UnsafePointer[c_void, StaticConstantOrigin]()
        _ = Recv(sq.__next__(), fd, null_ptr, UInt(0))
            .ioprio(UInt16(IORING_RECV_MULTISHOT))
            .sqe_flags(IoUringSqeFlags.BUFFER_SELECT)
            .buf_group(buf_group)
            .user_data(token)
        self._pending += 1

    fn poll(mut self, *, wait_nr: UInt32 = 1) raises:
        """Submit queued SQEs and drain available completions.

        Calls `Handler.on_complete` for each completed operation.
        """
        _ = self._ring.submit_and_wait(wait_nr=wait_nr)
        var cq = self._ring.cq(wait_nr=0)
        while cq:
            var cqe = cq.__next__()
            self._handler.on_complete(
                cqe.user_data, cqe.res, UInt32(cqe.flags.value)
            )
            self._pending -= 1
        cq^.__del__()

    fn run(mut self) raises:
        """Run until all pending operations complete."""
        while self._pending > 0:
            self.poll(wait_nr=1)


trait BatchCompletionHandler(CompletionHandler):
    """Extension of CompletionHandler with batch flush notification.

    After all available CQEs are dispatched via on_complete(), the loop
    calls on_flush() once, allowing the handler to process buffered work
    as a batch.
    """
    fn on_flush(mut self):
        ...


struct BatchCompletionLoop[Handler: BatchCompletionHandler]:
    """Event loop that drains all available completions before flushing.

    Same submit API as CompletionLoop. The poll() method waits for at
    least 1 CQE, drains all available CQEs via on_complete(), then
    calls on_flush() once for batch processing.
    """

    var _ring: IoUring[]
    var _pending: UInt32
    var _handler: Self.Handler

    fn __init__(out self, var handler: Self.Handler, sq_entries: UInt32 = 64) raises:
        self._ring = IoUring[](sq_entries=sq_entries)
        self._pending = 0
        self._handler = handler^

    fn submit_nop(mut self, token: UInt64 = 0) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (nop)"
        _ = Nop(sq.__next__()).user_data(token)
        self._pending += 1

    fn submit_read(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
        offset: UInt64 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (read)"
        _ = Read(sq.__next__(), fd, buf, len).user_data(token).offset(offset)
        self._pending += 1

    fn submit_write(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
        offset: UInt64 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (write)"
        _ = Write(sq.__next__(), fd, buf, len).user_data(token).offset(offset)
        self._pending += 1

    fn submit_recv(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recv)"
        _ = Recv(sq.__next__(), fd, buf, len).user_data(token)
        self._pending += 1

    fn submit_send(
        mut self,
        fd: RawHandle,
        buf: UnsafePointer[Int8, StaticConstantOrigin],
        len: UInt,
        token: UInt64,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (send)"
        _ = Send(sq.__next__(), fd, buf, len).user_data(token)
        self._pending += 1

    fn submit_accept(mut self, fd: RawHandle, token: UInt64) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (accept)"
        _ = Accept(sq.__next__(), fd).user_data(token)
        self._pending += 1

    fn submit_accept_multishot(mut self, fd: RawHandle, token: UInt64) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (accept_multishot)"
        _ = Accept(sq.__next__(), fd).ioprio(IoUringAcceptFlags.MULTISHOT.value).user_data(token)
        self._pending += 1

    fn submit_connect(
        mut self,
        fd: RawHandle,
        addr_unsafe_ptr: UnsafePointer[Int8, StaticConstantOrigin],
        addr_len: UInt64,
        token: UInt64,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (connect)"
        _ = Connect(sq.__next__(), fd, addr_unsafe_ptr, addr_len).user_data(token)
        self._pending += 1

    fn submit_recvmsg(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
        flags: UInt32 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recvmsg)"
        _ = RecvMsg(sq.__next__(), fd, msghdr_ptr).recv_flags(flags).user_data(token)
        self._pending += 1

    fn submit_sendmsg(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
        flags: UInt32 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (sendmsg)"
        _ = SendMsg(sq.__next__(), fd, msghdr_ptr).send_flags(flags).user_data(token)
        self._pending += 1

    fn submit_timeout(
        mut self,
        ts_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        token: UInt64,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (timeout)"
        _ = Timeout(sq.__next__(), ts_ptr).user_data(token)
        self._pending += 1

    fn provide_buffers(
        mut self,
        buf_base: UnsafePointer[UInt8, MutAnyOrigin],
        buf_size: Int,
        count: Int,
        group_id: UInt16,
        base_buf_id: UInt16,
        token: UInt64 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (provide_buffers)"
        var buf_ptr = UnsafePointer[c_void, StaticConstantOrigin](
            unsafe_from_address=Int(buf_base)
        )
        _ = ProvideBuffers(
            sq.__next__(), buf_ptr, UInt32(buf_size), UInt32(count),
            group_id, base_buf_id,
        ).user_data(token)
        self._pending += 1

    fn reprovide_buffer(
        mut self,
        buf_ptr: UnsafePointer[UInt8, MutAnyOrigin],
        buf_size: Int,
        group_id: UInt16,
        buf_id: UInt16,
        token: UInt64 = 0,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (reprovide_buffer)"
        var ptr = UnsafePointer[c_void, StaticConstantOrigin](
            unsafe_from_address=Int(buf_ptr)
        )
        _ = ProvideBuffers(
            sq.__next__(), ptr, UInt32(buf_size), UInt32(1),
            group_id, buf_id,
        ).user_data(token)
        self._pending += 1

    fn submit_recvmsg_multishot(
        mut self,
        fd: RawHandle,
        msghdr_ptr: UnsafePointer[c_void, StaticConstantOrigin],
        buf_group: UInt16,
        token: UInt64,
    ) raises:
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recvmsg_multishot)"
        _ = RecvMsg(sq.__next__(), fd, msghdr_ptr)
            .ioprio(UInt16(IORING_RECV_MULTISHOT))
            .sqe_flags(IoUringSqeFlags.BUFFER_SELECT)
            .buf_group(buf_group)
            .user_data(token)
        self._pending += 1

    fn submit_recv_multishot(
        mut self,
        fd: RawHandle,
        buf_group: UInt16,
        token: UInt64,
    ) raises:
        """Queue a multishot recv with provided buffer selection (TCP).

        Like submit_recv but the kernel selects a buffer from `buf_group`
        per arrival and produces one CQE per chunk. The payload begins at
        offset 0 of the chosen buffer (no io_uring_recvmsg_out header).
        Re-submit when CQE flags lack IORING_CQE_F_MORE.
        """
        var sq = self._ring.sq()
        if not sq:
            raise "submission queue full (recv_multishot)"
        var null_ptr = UnsafePointer[c_void, StaticConstantOrigin]()
        _ = Recv(sq.__next__(), fd, null_ptr, UInt(0))
            .ioprio(UInt16(IORING_RECV_MULTISHOT))
            .sqe_flags(IoUringSqeFlags.BUFFER_SELECT)
            .buf_group(buf_group)
            .user_data(token)
        self._pending += 1

    fn poll(mut self, *, wait_nr: UInt32 = 1) raises:
        """Submit queued SQEs, drain all available completions, then flush.

        Calls Handler.on_complete for each completed operation,
        then Handler.on_flush once after all CQEs are drained.
        """
        _ = self._ring.submit_and_wait(wait_nr=wait_nr)
        var cq = self._ring.cq(wait_nr=0)
        while cq:
            var cqe = cq.__next__()
            self._handler.on_complete(
                cqe.user_data, cqe.res, UInt32(cqe.flags.value)
            )
            self._pending -= 1
        cq^.__del__()
        self._handler.on_flush()

    fn run(mut self) raises:
        while self._pending > 0:
            self.poll(wait_nr=1)
