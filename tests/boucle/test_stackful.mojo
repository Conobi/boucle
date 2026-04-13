from boucle.stackful import CoroHandle, CoroYielder
from std.memory import UnsafePointer
from std.testing import assert_equal, assert_true


# ── Shared state structs ──────────────────────────────────────────────────


struct _CreateDestroyState:
    var checked: Bool

    fn __init__(out self):
        self.checked = False


struct _SingleYieldState:
    var step: Int

    fn __init__(out self, step: Int):
        self.step = step


struct _RunToCompletionState:
    var value: Int

    fn __init__(out self, value: Int):
        self.value = value


struct _CounterState:
    var counter: Int

    fn __init__(out self, counter: Int):
        self.counter = counter


struct _CumulativeState:
    var total: Int

    fn __init__(out self, total: Int):
        self.total = total


struct _ErrorAfterYieldState:
    var step: Int

    fn __init__(out self, step: Int):
        self.step = step


# ── Body functions ────────────────────────────────────────────────────────


fn _single_yield_body(mut y: CoroYielder) raises:
    var state = y.user_data().bitcast[_SingleYieldState]()
    state[].step = 1
    y.yield_to_caller()
    state[].step = 2


fn _run_to_completion_body(mut y: CoroYielder) raises:
    var state = y.user_data().bitcast[_RunToCompletionState]()
    state[].value = 42


fn _multiple_yields_body(mut y: CoroYielder) raises:
    var state = y.user_data().bitcast[_CounterState]()
    for _ in range(5):
        state[].counter += 1
        y.yield_to_caller()


fn _cumulative_body(mut y: CoroYielder) raises:
    var state = y.user_data().bitcast[_CumulativeState]()
    state[].total += 10
    y.yield_to_caller()
    state[].total += 20
    y.yield_to_caller()
    state[].total += 30


fn _error_immediate_body(mut y: CoroYielder) raises:
    raise "coroutine error"


fn _error_after_yield_body(mut y: CoroYielder) raises:
    var state = y.user_data().bitcast[_ErrorAfterYieldState]()
    state[].step = 1
    y.yield_to_caller()
    state[].step = 2
    raise "delayed error"


# ── Tests ─────────────────────────────────────────────────────────────────


fn test_create_destroy() raises:
    var coro = CoroHandle(_run_to_completion_body)
    assert_true(coro.can_resume())
    assert_true(not coro.is_done())
    # coro goes out of scope in CREATED state -- __del__ should handle it


fn test_single_yield() raises:
    var state = _SingleYieldState(0)
    var state_ptr = UnsafePointer[NoneType, MutExternalOrigin](
        unsafe_from_address=Int(UnsafePointer(to=state))
    )
    var coro = CoroHandle(_single_yield_body, user_data=state_ptr)
    coro.resume()
    assert_equal(state.step, 1)
    coro.resume()
    assert_equal(state.step, 2)
    assert_true(coro.is_done())


fn test_run_to_completion() raises:
    var state = _RunToCompletionState(0)
    var state_ptr = UnsafePointer[NoneType, MutExternalOrigin](
        unsafe_from_address=Int(UnsafePointer(to=state))
    )
    var coro = CoroHandle(_run_to_completion_body, user_data=state_ptr)
    coro.resume()
    assert_equal(state.value, 42)
    assert_true(coro.is_done())


fn test_multiple_yields() raises:
    var state = _CounterState(0)
    var state_ptr = UnsafePointer[NoneType, MutExternalOrigin](
        unsafe_from_address=Int(UnsafePointer(to=state))
    )
    var coro = CoroHandle(_multiple_yields_body, user_data=state_ptr)
    for i in range(1, 6):
        coro.resume()
        assert_equal(state.counter, i)
    coro.resume()
    assert_true(coro.is_done())


fn test_shared_state() raises:
    var state = _CumulativeState(0)
    var state_ptr = UnsafePointer[NoneType, MutExternalOrigin](
        unsafe_from_address=Int(UnsafePointer(to=state))
    )
    var coro = CoroHandle(_cumulative_body, user_data=state_ptr)
    coro.resume()
    assert_equal(state.total, 10)
    coro.resume()
    assert_equal(state.total, 30)
    coro.resume()
    assert_equal(state.total, 60)
    assert_true(coro.is_done())


fn test_error_propagation() raises:
    var coro = CoroHandle(_error_immediate_body)
    var caught = False
    try:
        coro.resume()
    except e:
        caught = "coroutine error" in String(e)
    assert_true(caught)
    assert_true(coro.is_done())


fn test_error_after_yield() raises:
    var state = _ErrorAfterYieldState(0)
    var state_ptr = UnsafePointer[NoneType, MutExternalOrigin](
        unsafe_from_address=Int(UnsafePointer(to=state))
    )
    var coro = CoroHandle(_error_after_yield_body, user_data=state_ptr)
    coro.resume()
    assert_equal(state.step, 1)
    var caught = False
    try:
        coro.resume()
    except e:
        caught = "delayed error" in String(e)
    assert_equal(state.step, 2)
    assert_true(caught)
    assert_true(coro.is_done())


fn main() raises:
    test_create_destroy()
    test_single_yield()
    test_run_to_completion()
    test_multiple_yields()
    test_shared_state()
    test_error_propagation()
    test_error_after_yield()
    print("All stackful tests passed.")
