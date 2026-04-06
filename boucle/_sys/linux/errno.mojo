from boucle._sys.linux.raw.x86_64.errno import (
    EACCES,
    EADDRINUSE,
    EADDRNOTAVAIL,
    EAGAIN,
    EBADF,
    ECONNABORTED,
    ECONNREFUSED,
    ECONNRESET,
    EEXIST,
    EINTR,
    EINVAL,
    ENOENT,
    ENOMEM,
    ENOSYS,
    ENOTCONN,
    EPERM,
    EPIPE,
    ETIMEDOUT,
    EWOULDBLOCK,
)


struct Errno(TrivialRegisterPassable, Writable):
    """I/O error type wrapping a Linux errno.

    Linux returns negated error numbers, kept in range [-4095, 0).
    """

    comptime EACCES = Self(errno=EACCES)
    comptime EADDRINUSE = Self(errno=EADDRINUSE)
    comptime EADDRNOTAVAIL = Self(errno=EADDRNOTAVAIL)
    comptime EAGAIN = Self(errno=EAGAIN)
    comptime EBADF = Self(errno=EBADF)
    comptime ECONNABORTED = Self(errno=ECONNABORTED)
    comptime ECONNREFUSED = Self(errno=ECONNREFUSED)
    comptime ECONNRESET = Self(errno=ECONNRESET)
    comptime EEXIST = Self(errno=EEXIST)
    comptime EINTR = Self(errno=EINTR)
    comptime EINVAL = Self(errno=EINVAL)
    comptime ENOENT = Self(errno=ENOENT)
    comptime ENOMEM = Self(errno=ENOMEM)
    comptime ENOSYS = Self(errno=ENOSYS)
    comptime ENOTCONN = Self(errno=ENOTCONN)
    comptime EPERM = Self(errno=EPERM)
    comptime EPIPE = Self(errno=EPIPE)
    comptime ETIMEDOUT = Self(errno=ETIMEDOUT)
    comptime EWOULDBLOCK = Self(errno=EWOULDBLOCK)

    var id: Int16

    @always_inline("nodebug")
    fn __init__(out self, *, errno: UInt16):
        self = Self(negated_errno=-Int16(errno))

    @always_inline("nodebug")
    fn __init__(out self, *, error: Error) raises:
        self = Self(negated_errno=Int16(Int(String(error))))

    @always_inline("nodebug")
    fn __init__(out self, *, negated_errno: Int16):
        self.id = negated_errno
        debug_assert(
            self.id >= -4095 and self.id < 0, "error number out of range"
        )

    @always_inline("nodebug")
    fn __is__(self, rhs: Self) -> Bool:
        return self.id == rhs.id

    @always_inline("nodebug")
    fn __isnot__(self, rhs: Self) -> Bool:
        return self.id != rhs.id

    @always_inline
    fn write_to[W: Writer](self, mut writer: W):
        writer.write(self.id)


@always_inline("nodebug")
fn _check_for_errors(raw: Scalar[DType.int64]) raises:
    if raw < 0:
        debug_assert(raw >= -4095, "error number out of range")
        raise String(raw)


@always_inline("nodebug")
fn _zero_result(raw: Scalar[DType.int64]):
    debug_assert(raw == 0, "non-zero result")


@always_inline("nodebug")
fn unsafe_decode_result[
    type: DType
](raw: Scalar[DType.int64]) raises -> Scalar[type]:
    _check_for_errors(raw)
    var res = raw.cast[type]()
    debug_assert(res.cast[DType.int64]() == raw, "conversion is not lossless")
    return res


@always_inline("nodebug")
fn unsafe_decode_ptr(
    unsafe_ptr: UnsafePointer[Int8, StaticConstantOrigin],
) raises:
    _check_for_errors(Scalar[DType.int64](Int(unsafe_ptr)))


@always_inline("nodebug")
fn unsafe_decode_none(raw: Scalar[DType.int64]) raises:
    if raw != 0:
        debug_assert(raw >= -4095 and raw < 0, "error number out of range")
        raise String(raw)
