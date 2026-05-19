from boucle._sys.linux.errno import Errno, _check_for_errors
from std.testing import assert_true, assert_false


def main() raises:
    # Construction from raw errno number
    var e = Errno(errno=13)
    assert_true(e is Errno.EACCES)
    assert_false(e is Errno.EPERM)

    # EAGAIN and EWOULDBLOCK are the same on Linux
    assert_true(Errno.EAGAIN is Errno.EWOULDBLOCK)

    # Different errors are not equal
    assert_false(Errno.EINVAL is Errno.ENOENT)

    # _check_for_errors passes on non-negative values
    _check_for_errors(Scalar[DType.int64](0))
    _check_for_errors(Scalar[DType.int64](42))

    # _check_for_errors raises on negative values
    var caught = False
    try:
        _check_for_errors(Scalar[DType.int64](-13))
    except:
        caught = True
    assert_true(caught)

    print("All errno tests passed.")
