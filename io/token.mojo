"""Opaque token for correlating I/O operations with completions."""


struct Token(TrivialRegisterPassable, Equatable):
    """Opaque token for correlating I/O operations with completions."""

    var value: UInt64

    @always_inline("nodebug")
    @implicit
    fn __init__(out self, value: UInt64):
        self.value = value

    @always_inline("nodebug")
    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    @always_inline("nodebug")
    fn __ne__(self, other: Self) -> Bool:
        return self.value != other.value
