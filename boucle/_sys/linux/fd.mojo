from ffi import external_call

comptime UnsafeFd = Int32
comptime NoFd: UnsafeFd = -1


@always_inline("nodebug")
fn unsafe_fd_as_arg(unsafe_fd: UnsafeFd) -> UnsafeFd:
    debug_assert(unsafe_fd > -1, "invalid file descriptor")
    return unsafe_fd


@always_inline
fn close(*, unsafe_fd: UnsafeFd):
    """Closes an unsafe file descriptor."""
    var res = external_call["close", Int32](unsafe_fd_as_arg(unsafe_fd))
    debug_assert(res == 0, "non-zero result from close")


@always_inline
fn dup(*, unsafe_fd: UnsafeFd) raises -> UnsafeFd:
    """Duplicates a file descriptor."""
    var res = external_call["dup", Int32](unsafe_fd_as_arg(unsafe_fd))
    if res < 0:
        raise String(Int(res))
    return res
