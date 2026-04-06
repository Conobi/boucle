from boucle.interest import Interest
from std.testing import assert_true, assert_false, assert_equal


fn main() raises:
    assert_true(Interest.READABLE.is_readable())
    assert_false(Interest.READABLE.is_writable())
    assert_true(Interest.WRITABLE.is_writable())
    assert_false(Interest.WRITABLE.is_readable())

    var both = Interest.READABLE | Interest.WRITABLE
    assert_true(both.is_readable())
    assert_true(both.is_writable())

    var empty = Interest()
    assert_false(empty.is_readable())
    assert_false(empty.is_writable())

    print("All interest tests passed.")
