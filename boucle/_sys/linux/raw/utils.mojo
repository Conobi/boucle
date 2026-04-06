from sys.info import is_nvidia_gpu, is_triple, is_64bit as _is_64bit
from bit import byte_swap


@always_inline("nodebug")
fn is_x86_64() -> Bool:
    return not is_nvidia_gpu() and is_triple["x86_64-unknown-linux-gnu"]()


@always_inline("nodebug")
fn is_64bit() -> Bool:
    return _is_64bit()


@always_inline("nodebug")
fn is_big_endian() -> Bool:
    return not is_little_endian()


@always_inline("nodebug")
fn is_little_endian() -> Bool:
    var val = UInt16(0x0001)
    var bytes = UnsafePointer(to=val).bitcast[UInt8]()
    return bytes[] == 1


@always_inline("nodebug")
fn _to_be[type: DType, size: Int](value: SIMD[type, size]) -> SIMD[type, size]:
    comptime if is_big_endian():
        return value
    else:
        return byte_swap(value)
