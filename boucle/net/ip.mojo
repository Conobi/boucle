"""IP address types.

IpAddrV4 holds 4 octets, IpAddrV6 holds 8 segments of 16 bits.
Both are TrivialRegisterPassable value types.
"""


struct IpAddrV4(TrivialRegisterPassable):
    """An IPv4 address (4 octets)."""

    comptime Octets = SIMD[DType.uint8, 4]
    var octets: Self.Octets

    @always_inline
    def __init__(out self, a: UInt8, b: UInt8, c: UInt8, d: UInt8):
        self.octets = Self.Octets(a, b, c, d)


struct IpAddrV6(TrivialRegisterPassable):
    """An IPv6 address (8 segments of 16 bits)."""

    comptime Segments = SIMD[DType.uint16, 8]
    var segments: Self.Segments

    @always_inline
    def __init__(
        out self,
        a: UInt16,
        b: UInt16,
        c: UInt16,
        d: UInt16,
        e: UInt16,
        f: UInt16,
        g: UInt16,
        h: UInt16,
    ):
        self.segments = Self.Segments(a, b, c, d, e, f, g, h)
