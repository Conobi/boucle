from boucle.completion import (
    IORING_CQE_F_BUFFER,
    IORING_CQE_F_MORE,
    IORING_CQE_BUFFER_SHIFT,
)
from std.testing import assert_equal


def main() raises:
    # Kernel UAPI values from include/uapi/linux/io_uring.h.
    assert_equal(Int(IORING_CQE_F_BUFFER), 1)
    assert_equal(Int(IORING_CQE_F_MORE), 2)
    assert_equal(Int(IORING_CQE_BUFFER_SHIFT), 16)

    print("All completion re-export tests passed.")
