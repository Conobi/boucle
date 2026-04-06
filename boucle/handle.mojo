"""Portable I/O resource handle types."""

from boucle._sys.linux.fd import UnsafeFd, close, unsafe_fd_as_arg

comptime RawHandle = UnsafeFd
"""A raw, unowned file descriptor / handle value. Alias for Int32."""


struct OwnedHandle(Movable):
    """An owned I/O resource handle with RAII semantics.

    Automatically closes the underlying file descriptor on destruction.
    Use `__moveinit__` to transfer ownership.
    """

    var _raw: RawHandle

    @always_inline("nodebug")
    fn __init__(out self, *, raw: RawHandle):
        debug_assert(raw > -1, "invalid handle")
        self._raw = raw

    @always_inline("nodebug")
    fn __moveinit__(out self, deinit take: Self):
        self._raw = take._raw

    @always_inline("nodebug")
    fn __del__(deinit self):
        close(unsafe_fd=self._raw)

    @always_inline("nodebug")
    fn raw(self) -> RawHandle:
        """Returns the underlying raw handle value."""
        return unsafe_fd_as_arg(self._raw)
