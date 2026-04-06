"""Portable I/O error type."""

from boucle._sys.linux.errno import Errno


struct IOError(Writable):
    """Portable I/O error type wrapping a Linux errno."""

    var _errno: Errno

    @always_inline("nodebug")
    fn __init__(out self, errno: Errno):
        self._errno = errno

    @always_inline("nodebug")
    fn __init__(out self, *, error: Error) raises:
        self._errno = Errno(error=error)

    @always_inline("nodebug")
    fn is_would_block(self) -> Bool:
        return self._errno is Errno.EAGAIN or self._errno is Errno.EWOULDBLOCK

    @always_inline("nodebug")
    fn is_connection_reset(self) -> Bool:
        return self._errno is Errno.ECONNRESET

    @always_inline("nodebug")
    fn is_connection_refused(self) -> Bool:
        return self._errno is Errno.ECONNREFUSED

    @always_inline("nodebug")
    fn is_broken_pipe(self) -> Bool:
        return self._errno is Errno.EPIPE

    @always_inline("nodebug")
    fn is_timed_out(self) -> Bool:
        return self._errno is Errno.ETIMEDOUT

    @always_inline("nodebug")
    fn is_interrupted(self) -> Bool:
        return self._errno is Errno.EINTR

    @always_inline
    fn write_to[W: Writer](self, mut writer: W):
        writer.write("IOError(errno=", self._errno, ")")
