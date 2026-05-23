from std.ffi import external_call
from std.memory import UnsafePointer
from std.testing import assert_true, assert_equal

from boucle.net.socket import Socket
from boucle.net.addr import SocketAddrV4, SocketAddrStorV4
from boucle.net.options import Backlog


def _getsockname_port_v4(ref s: Socket) raises -> UInt16:
    var stor = SocketAddrStorV4()
    var stor_p = UnsafePointer(to=stor)
    var len = UInt32(16)
    var len_p = UnsafePointer(to=len)
    var res = external_call["getsockname", Int32](
        s.raw(), stor_p, len_p,
    )
    if res < 0:
        raise String("getsockname failed: ", Int(res))
    var be = stor.addr.sin_port
    return (UInt16(be) >> 8) | ((UInt16(be) & UInt16(0xFF)) << 8)


def _accept_one(ref server: Socket) raises -> Int32:
    var stor = SocketAddrStorV4()
    var stor_p = UnsafePointer(to=stor)
    var len = UInt32(16)
    var len_p = UnsafePointer(to=len)
    for _ in range(1000):
        var res = external_call["accept4", Int32](
            server.raw(), stor_p, len_p, Int32(0),
        )
        if res >= 0:
            return res
    raise String("accept timed out")


def _send_byte(ref s: Socket, b: UInt8) raises -> Int64:
    var v = b
    var v_p = UnsafePointer(to=v)
    return external_call["send", Int64](
        s.raw(), v_p, UInt64(1), Int32(0),
    )


def _recv_byte(fd: Int32) raises -> Int64:
    var rx = UInt8(0)
    var rx_p = UnsafePointer(to=rx)
    return external_call["recv", Int64](
        fd, rx_p, UInt64(1), Int32(0),
    )


def main() raises:
    var server = Socket.tcp_v4()
    var bind_addr = SocketAddrV4(127, 0, 0, 1, port=0)
    server.bind(bind_addr)
    server.listen(Backlog.DEFAULT)
    var port = _getsockname_port_v4(server)
    assert_true(port != 0)

    var dest = SocketAddrV4(127, 0, 0, 1, port=port)
    var client = Socket.tcp_connect(dest)
    assert_true(client.raw() > -1)

    var peer_fd = _accept_one(server)
    assert_true(peer_fd > -1)

    var sent = _send_byte(client, UInt8(0x42))
    assert_equal(sent, 1)

    var recvd = Int64(-1)
    for _ in range(1000):
        recvd = _recv_byte(peer_fd)
        if recvd == 1:
            break
    assert_equal(recvd, 1)

    _ = external_call["close", Int32](peer_fd)

    print("All socket connect tests passed.")
