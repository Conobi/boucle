from boucle.completion import CompletionLoop, CompletionHandler
from boucle.handle import RawHandle
from std.ffi import external_call
from std.testing import assert_equal, assert_true


struct Counter(CompletionHandler):
    var count: Int
    var last_token: UInt64
    var last_result: Int32

    def __init__(out self):
        self.count = 0
        self.last_token = 0
        self.last_result = 0

    def __init__(out self, *, deinit take: Self):
        self.count = take.count
        self.last_token = take.last_token
        self.last_result = take.last_result

    def on_complete(mut self, token: UInt64, result: Int32, flags: UInt32):
        self.count += 1
        self.last_token = token
        self.last_result = result


def test_nop_single() raises:
    var loop = CompletionLoop(Counter(), sq_entries=8)
    loop.submit_nop(token=42)
    loop.run()
    assert_equal(loop._handler.count, 1)
    assert_equal(loop._handler.last_token, UInt64(42))
    assert_equal(loop._handler.last_result, Int32(0))


def test_nop_multiple() raises:
    var loop = CompletionLoop(Counter(), sq_entries=8)
    for i in range(5):
        loop.submit_nop(token=UInt64(i))
    loop.run()
    assert_equal(loop._handler.count, 5)


def test_nop_batched() raises:
    var loop = CompletionLoop(Counter(), sq_entries=4)
    for i in range(12):
        if i > 0 and i % 4 == 0:
            loop.poll(wait_nr=1)
        loop.submit_nop(token=UInt64(i))
    loop.run()
    assert_equal(loop._handler.count, 12)


struct CqeRecorder(CompletionHandler):
    """Records up to 4 CQEs as (token, result) pairs for unordered assertions."""
    var tokens: InlineArray[UInt64, 4]
    var results: InlineArray[Int32, 4]
    var count: Int

    def __init__(out self):
        self.tokens = InlineArray[UInt64, 4](fill=0)
        self.results = InlineArray[Int32, 4](fill=0)
        self.count = 0

    def __init__(out self, *, deinit take: Self):
        self.tokens = take.tokens
        self.results = take.results
        self.count = take.count

    def on_complete(mut self, token: UInt64, result: Int32, flags: UInt32):
        if self.count < 4:
            self.tokens[self.count] = token
            self.results[self.count] = result
        self.count += 1


def test_submit_cancel_cancels_pending_recv() raises:
    # Open a connected AF_UNIX socketpair; one side has no data, so a recv
    # there will park in the kernel waiting for bytes.
    # socketpair(AF_UNIX=1, SOCK_STREAM=1, protocol=0, sv).
    var sv = InlineArray[Int32, 2](fill=0)
    var rc = external_call["socketpair", Int32](
        Int32(1),  # AF_UNIX
        Int32(1),  # SOCK_STREAM
        Int32(0),
        UnsafePointer(to=sv).bitcast[Int32](),
    )
    assert_equal(Int(rc), 0)
    var read_fd: RawHandle = sv[0]
    var write_fd: RawHandle = sv[1]

    var loop = CompletionLoop(CqeRecorder(), sq_entries=8)

    # Submit a recv that will park in the kernel.
    var buf = List[UInt8](length=16, fill=0)
    var buf_ptr = UnsafePointer[Int8, StaticConstantOrigin](
        unsafe_from_address=Int(buf.unsafe_ptr())
    )
    loop.submit_recv(read_fd, buf_ptr, 16, token=42)

    # Cancel it by user_data. The cancel CQE carries token=99.
    loop.submit_cancel(token=99, target_user_data=42)

    # Drain until both CQEs arrive (order is not guaranteed).
    while loop._handler.count < 2:
        loop.poll(wait_nr=1)

    assert_equal(loop._handler.count, 2)

    # Find the recv's CQE (token 42) and the cancel's CQE (token 99).
    var recv_idx = -1
    var cancel_idx = -1
    for i in range(2):
        if loop._handler.tokens[i] == UInt64(42):
            recv_idx = i
        elif loop._handler.tokens[i] == UInt64(99):
            cancel_idx = i
    assert_true(recv_idx >= 0, "recv CQE (token=42) missing")
    assert_true(cancel_idx >= 0, "cancel CQE (token=99) missing")

    # Recv must report -ECANCELED (-125 on x86_64).
    assert_equal(loop._handler.results[recv_idx], Int32(-125))
    # Cancel itself reports 0 (cancelled in flight) or -ENOENT/-EALREADY if the
    # target raced to completion. We never wrote anything, so 0 is expected, but
    # accept the other valid outcomes to stay robust against kernel scheduling.
    var cr = loop._handler.results[cancel_idx]
    assert_true(
        cr == Int32(0) or cr == Int32(-2) or cr == Int32(-114),
        "cancel CQE result must be 0, -ENOENT (-2), or -EALREADY (-114)",
    )

    _ = external_call["close", Int32](read_fd)
    _ = external_call["close", Int32](write_fd)


def main() raises:
    test_nop_single()
    test_nop_multiple()
    test_nop_batched()
    test_submit_cancel_cancels_pending_recv()
    print("All completion loop tests passed.")
