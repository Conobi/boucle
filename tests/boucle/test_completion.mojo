from boucle.completion import CompletionLoop, CompletionHandler
from std.testing import assert_equal


struct Counter(CompletionHandler):
    var count: Int
    var last_token: UInt64
    var last_result: Int32

    fn __init__(out self):
        self.count = 0
        self.last_token = 0
        self.last_result = 0

    fn __moveinit__(out self, deinit take: Self):
        self.count = take.count
        self.last_token = take.last_token
        self.last_result = take.last_result

    fn on_complete(mut self, token: UInt64, result: Int32, flags: UInt32):
        self.count += 1
        self.last_token = token
        self.last_result = result


fn test_nop_single() raises:
    var loop = CompletionLoop(Counter(), sq_entries=8)
    loop.submit_nop(token=42)
    loop.run()
    assert_equal(loop._handler.count, 1)
    assert_equal(loop._handler.last_token, UInt64(42))
    assert_equal(loop._handler.last_result, Int32(0))


fn test_nop_multiple() raises:
    var loop = CompletionLoop(Counter(), sq_entries=8)
    for i in range(5):
        loop.submit_nop(token=UInt64(i))
    loop.run()
    assert_equal(loop._handler.count, 5)


fn test_nop_batched() raises:
    var loop = CompletionLoop(Counter(), sq_entries=4)
    for i in range(12):
        if i > 0 and i % 4 == 0:
            loop.poll(wait_nr=1)
        loop.submit_nop(token=UInt64(i))
    loop.run()
    assert_equal(loop._handler.count, 12)


fn main() raises:
    test_nop_single()
    test_nop_multiple()
    test_nop_batched()
    print("All completion loop tests passed.")
