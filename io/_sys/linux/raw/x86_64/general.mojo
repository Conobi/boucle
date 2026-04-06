from io._sys.linux.raw.ctypes import c_int, c_long, c_ulong, c_longlong

# Syscall numbers (x86_64)
comptime __NR_close = 3
comptime __NR_mmap = 9
comptime __NR_munmap = 11
comptime __NR_madvise = 28
comptime __NR_dup = 32
comptime __NR_socket = 41
comptime __NR_bind = 49
comptime __NR_listen = 50
comptime __NR_setsockopt = 54
comptime __NR_socketpair = 53

# mmap constants
comptime MAP_SHARED = 0x01
comptime MAP_PRIVATE = 0x02
comptime MAP_ANONYMOUS = 0x20
comptime MAP_POPULATE = 0x08000
comptime MAP_HUGETLB = 0x40000

comptime PROT_NONE = 0x0
comptime PROT_READ = 0x1
comptime PROT_WRITE = 0x2
comptime PROT_EXEC = 0x4

comptime MADV_NORMAL = 0
comptime MADV_RANDOM = 1
comptime MADV_SEQUENTIAL = 2
comptime MADV_WILLNEED = 3
comptime MADV_DONTNEED = 4
comptime MADV_DONTFORK = 10
comptime MADV_DOFORK = 11

# Kernel timespec
@fieldwise_init
struct __kernel_timespec(TrivialRegisterPassable):
    var tv_sec: c_longlong
    var tv_nsec: c_longlong

# Signal set (simple alias on x86_64 Linux)
comptime sigset_t = c_ulong
