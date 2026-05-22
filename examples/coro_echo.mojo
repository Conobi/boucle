"""Stackful coroutine example: yield/resume between caller and coroutine.

Demonstrates the CoroHandle / CoroYielder API. The coroutine runs on its
own stack and suspends via `y.yield_to_caller()`; the caller drives it
forward with `coro.resume()`. Real yield/resume semantics, no state
machine transform.

Run:
    uv run -- mojo run -I . -D ASSERT=all examples/coro_echo.mojo
"""

from boucle.stackful import CoroHandle, CoroYielder
from std.testing import assert_true


def _echo_body(mut y: CoroYielder) raises:
    print("in coro")
    y.yield_to_caller()
    print("resumed")


def main() raises:
    var coro = CoroHandle(_echo_body)

    print("before resume")
    coro.resume()
    print("after first resume")
    coro.resume()
    print("done")

    assert_true(coro.is_done())
    print("OK")
