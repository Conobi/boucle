from std.ffi import external_call
from std.memory import UnsafePointer
from std.testing import assert_true, assert_equal

from boucle.net.socket import Socket
from boucle.net.addr import SocketAddrStorV6
from boucle._sys.linux.raw import (
    SOL_SOCKET,
    SO_REUSEADDR,
    SO_REUSEPORT,
    IPPROTO_IPV6,
    IPV6_V6ONLY,
)


def _getsockopt_int(ref s: Socket, level: Int32, optname: Int32) raises -> Int32:
    var val = Int32(-1)
    var optlen = UInt32(4)
    var v_p = UnsafePointer(to=val)
    var l_p = UnsafePointer(to=optlen)
    var res = external_call["getsockopt", Int32](
        s.raw(), level, optname, v_p, l_p,
    )
    if res < 0:
        raise String("getsockopt failed: ", Int(res))
    return val


def _getsockname_port(ref s: Socket) raises -> UInt16:
    # IPv6 sockaddr is 28 bytes; sin6_port is at offset 2 (network order).
    var stor = SocketAddrStorV6()
    var stor_p = UnsafePointer(to=stor)
    var len = UInt32(28)
    var len_p = UnsafePointer(to=len)
    var res = external_call["getsockname", Int32](
        s.raw(), stor_p, len_p,
    )
    if res < 0:
        raise String("getsockname failed: ", Int(res))
    var be = stor.addr.sin6_port
    return (UInt16(be) >> 8) | ((UInt16(be) & UInt16(0xFF)) << 8)


def _check_listener_opts(ref s: Socket) raises:
    assert_true(_getsockopt_int(s, Int32(SOL_SOCKET), Int32(SO_REUSEADDR)) != 0)
    assert_true(_getsockopt_int(s, Int32(SOL_SOCKET), Int32(SO_REUSEPORT)) != 0)
    assert_equal(_getsockopt_int(s, Int32(IPPROTO_IPV6), Int32(IPV6_V6ONLY)), 0)


def main() raises:
    var tcp = Socket.tcp_listener_v6(0)
    assert_true(tcp.raw() > -1)
    _check_listener_opts(tcp)
    var tcp_port = _getsockname_port(tcp)
    assert_true(tcp_port != 0)

    var udp = Socket.udp_listener_v6(0)
    assert_true(udp.raw() > -1)
    _check_listener_opts(udp)
    var udp_port = _getsockname_port(udp)
    assert_true(udp_port != 0)

    print("All socket factory tests passed.")
