from boucle.handle import RawHandle, OwnedHandle
from std.testing import assert_true
from std.ffi import external_call


fn main() raises:
    # Dup stdin to get a valid fd (using external_call directly to avoid
    # a Mojo 0.26.2 mojopkg crash when importing from multiple submodules).
    var raw = external_call["dup", Int32](Int32(0))
    assert_true(raw > -1)

    var handle = OwnedHandle(raw=raw)
    assert_true(handle.raw() > -1)

    var handle2 = handle
    assert_true(handle2.raw() > -1)

    # Close the duped fd
    var res = external_call["close", Int32](handle2.raw())
    debug_assert(res == 0, "close failed")

    print("All handle tests passed.")
