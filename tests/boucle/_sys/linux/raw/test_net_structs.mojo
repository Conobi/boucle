from boucle._sys.linux.raw.x86_64.net import (
    sockaddr_in, sockaddr_in6, in_addr, in6_addr,
    iovec, msghdr,
    AF_INET, AF_INET6, SOCK_STREAM, SOCK_DGRAM,
    IPPROTO_TCP, IPPROTO_UDP,
)
from testing import assert_equal
from sys.info import size_of


fn main() raises:
    assert_equal(size_of[in_addr](), 4)
    assert_equal(size_of[sockaddr_in](), 16)
    assert_equal(size_of[in6_addr](), 16)
    assert_equal(size_of[sockaddr_in6](), 28)
    assert_equal(size_of[iovec](), 16)
    assert_equal(size_of[msghdr](), 56)

    var sa4 = sockaddr_in()
    assert_equal(Int(sa4.sin_family), 0)
    assert_equal(Int(sa4.sin_port), 0)

    var sa6 = sockaddr_in6()
    assert_equal(Int(sa6.sin6_family), 0)
    assert_equal(Int(sa6.sin6_scope_id), 0)

    assert_equal(AF_INET, 2)
    assert_equal(AF_INET6, 10)
    assert_equal(SOCK_STREAM, 1)
    assert_equal(SOCK_DGRAM, 2)
    assert_equal(IPPROTO_TCP, 6)
    assert_equal(IPPROTO_UDP, 17)

    print("All net struct tests passed.")
