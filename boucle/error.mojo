"""Portable I/O error type."""


struct IOError(TrivialRegisterPassable, Writable):
    """Portable I/O error type wrapping a negated errno value."""

    var _id: Int16

    @always_inline("nodebug")
    fn __init__(out self, *, negated_errno: Int16):
        debug_assert(
            negated_errno >= -4095 and negated_errno < 0,
            "error number out of range",
        )
        self._id = negated_errno

    fn is_would_block(self) -> Bool:
        # EAGAIN = 11 = EWOULDBLOCK on Linux x86_64
        return self._id == -11

    fn is_connection_reset(self) -> Bool:
        # ECONNRESET = 104
        return self._id == -104

    fn is_connection_refused(self) -> Bool:
        # ECONNREFUSED = 111
        return self._id == -111

    fn is_broken_pipe(self) -> Bool:
        # EPIPE = 32
        return self._id == -32

    fn is_timed_out(self) -> Bool:
        # ETIMEDOUT = 110
        return self._id == -110

    fn is_interrupted(self) -> Bool:
        # EINTR = 4
        return self._id == -4

    @always_inline
    fn write_to[W: Writer](self, mut writer: W):
        writer.write("IOError(errno=", self._id, ")")
