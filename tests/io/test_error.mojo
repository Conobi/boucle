from boucle.error import IOError
from std.testing import assert_true, assert_false


fn main() raises:
    # Construct IOError via negated_errno to avoid cross-submodule
    # mojopkg crash (Mojo 0.26.2 bug when importing from both
    # boucle.error and boucle._sys.linux.errno in the same file).

    # EAGAIN = 11, negated = -11
    var would_block = IOError(negated_errno=-11)
    assert_true(would_block.is_would_block())
    assert_false(would_block.is_connection_reset())
    assert_false(would_block.is_timed_out())

    # EWOULDBLOCK = EAGAIN = 11 on Linux x86_64, negated = -11
    var would_block2 = IOError(negated_errno=-11)
    assert_true(would_block2.is_would_block())

    # ECONNRESET = 104, negated = -104
    var conn_reset = IOError(negated_errno=-104)
    assert_true(conn_reset.is_connection_reset())
    assert_false(conn_reset.is_would_block())

    # ECONNREFUSED = 111, negated = -111
    var conn_refused = IOError(negated_errno=-111)
    assert_true(conn_refused.is_connection_refused())

    # EPIPE = 32, negated = -32
    var broken_pipe = IOError(negated_errno=-32)
    assert_true(broken_pipe.is_broken_pipe())

    # ETIMEDOUT = 110, negated = -110
    var timed_out = IOError(negated_errno=-110)
    assert_true(timed_out.is_timed_out())

    # EINTR = 4, negated = -4
    var interrupted = IOError(negated_errno=-4)
    assert_true(interrupted.is_interrupted())

    print("All error tests passed.")
