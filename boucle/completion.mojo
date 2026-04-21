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
from boucle._sys.linux.io_uring.op import Nop, Read, Write, Recv, Send, Accept, Connect, RecvMsg, SendMsg
from boucle._sys.linux.raw.ctypes import c_void
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
