"""Low-level socket syscall wrappers using libc external_call.

Uses external_call instead of raw syscall wrappers to work around
a Mojo 0.26.2 mojopkg deserialization crash when calling through
multiple internal subpackage layers.
"""

from std.ffi import external_call
from std.memory import UnsafePointer

from boucle.handle import RawHandle, OwnedHandle
from boucle.net.addr import SocketAddr
from boucle.net.options import AddrFamily, SocketType, SocketFlags, Protocol, Backlog


@always_inline
def _socket(
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
def _bind[Addr: SocketAddr](ref handle: OwnedHandle, ref addr: Addr) raises:
    var res = external_call["bind", Int32](
        handle.raw(), addr.addr_unsafe_ptr(), Int32(Addr.ADDR_LEN)
    )
    if res < 0:
        raise String(Int(res))


@always_inline
def _listen(ref handle: OwnedHandle, backlog: Backlog) raises:
    var res = external_call["listen", Int32](handle.raw(), backlog.value)
    if res < 0:
        raise String(Int(res))


@always_inline
def _setsockopt(
    ref handle: OwnedHandle,
    level: Int32,
    optname: Int32,
    value: Int32,
) raises:
    var val = value
    # Pre-capture the pointer in a named local — passing
    # UnsafePointer(to=val) inline can clobber val's stack slot
    # during external_call arg marshaling.
    var val_p = UnsafePointer(to=val)
    var res = external_call["setsockopt", Int32](
        handle.raw(),
        level,
        optname,
        val_p,
        UInt32(4),
    )
    if res < 0:
        raise String(Int(res))


@always_inline
def _connect[Addr: SocketAddr](ref handle: OwnedHandle, ref addr: Addr) raises:
    var res = external_call["connect", Int32](
        handle.raw(), addr.addr_unsafe_ptr(), Int32(Addr.ADDR_LEN)
    )
    if res < 0:
        raise String(Int(res))
