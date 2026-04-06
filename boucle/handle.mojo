"""Portable I/O resource handle types."""

comptime RawHandle = Int32
"""A raw, unowned file descriptor / handle value. Alias for Int32."""


struct OwnedHandle(TrivialRegisterPassable):
    """An owned I/O resource handle.

    Register-passable for efficient storage and passing. The caller must
    explicitly close the handle via `close(unsafe_fd=handle.raw())` when done.
    """

    var _raw: RawHandle

    @always_inline("nodebug")
    fn __init__(out self, *, raw: RawHandle):
        debug_assert(raw > -1, "invalid handle")
        self._raw = raw

    @always_inline("nodebug")
    fn raw(self) -> RawHandle:
        """Returns the underlying raw handle value."""
        debug_assert(self._raw > -1, "invalid handle")
        return self._raw
