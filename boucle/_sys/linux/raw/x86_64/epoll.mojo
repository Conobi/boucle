from boucle._sys.linux.raw.ctypes import c_int, c_uint

# epoll_ctl operations
comptime EPOLL_CTL_ADD = 1
comptime EPOLL_CTL_DEL = 2
comptime EPOLL_CTL_MOD = 3

# epoll event flags
comptime EPOLLIN = 0x001
comptime EPOLLPRI = 0x002
comptime EPOLLOUT = 0x004
comptime EPOLLERR = 0x008
comptime EPOLLHUP = 0x010
comptime EPOLLRDNORM = 0x040
comptime EPOLLRDBAND = 0x080
comptime EPOLLWRNORM = 0x100
comptime EPOLLWRBAND = 0x200
comptime EPOLLMSG = 0x400
comptime EPOLLRDHUP = 0x2000
comptime EPOLLEXCLUSIVE = 0x10000000
comptime EPOLLWAKEUP = 0x20000000
comptime EPOLLONESHOT = 0x40000000
comptime EPOLLET = 0x80000000


struct epoll_event(TrivialRegisterPassable):
    """Linux epoll_event struct."""
    var events: UInt32
    var data: UInt64

    @always_inline
    def __init__(out self):
        self.events = 0
        self.data = 0

    @always_inline
    def __init__(out self, *, events: UInt32, data: UInt64):
        self.events = events
        self.data = data
