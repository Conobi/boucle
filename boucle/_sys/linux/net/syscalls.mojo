"""Low-level socket syscall wrappers using libc external_call.

Uses external_call instead of raw syscall wrappers to work around
a Mojo 0.26.2 mojopkg deserialization crash when calling through
multiple internal subpackage layers.
"""

from ffi import external_call

from boucle.handle import RawHandle, OwnedHandle
from boucle.net.addr import SocketAddr
from boucle.net.options import AddrFamily, SocketType, SocketFlags, Protocol, Backlog


@always_inline
fn _socket(
    domain: AddrFamily,
    type: SocketType,
    flags: SocketFlags,
    protocol: Protocol,
) raises -> OwnedHandle:
    var type_flags = type.id | Int32(flags.value)
    var res = external_call["socket", Int32](
        Int32(domain.id), type_flags, Int32(protocol.id)
    )
    if res < 0:
        raise String(Int(res))
    return OwnedHandle(raw=res)


@always_inline
fn _bind[Addr: SocketAddr](ref handle: OwnedHandle, ref addr: Addr) raises:
    var res = external_call["bind", Int32](
        handle.raw(), addr.addr_unsafe_ptr(), Int32(Addr.ADDR_LEN)
    )
    if res < 0:
        raise String(Int(res))


@always_inline
fn _listen(ref handle: OwnedHandle, backlog: Backlog) raises:
    var res = external_call["listen", Int32](handle.raw(), backlog.value)
    if res < 0:
        raise String(Int(res))
