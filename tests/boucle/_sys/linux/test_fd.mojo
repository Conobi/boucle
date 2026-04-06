from boucle._sys.linux.fd import close, dup, UnsafeFd, NoFd, unsafe_fd_as_arg
from std.testing import assert_true


fn main() raises:
    # NoFd sentinel is -1
    assert_true(NoFd == -1)

    # Dup stdin (fd 0) to get a valid fd
    var fd: UnsafeFd = dup(unsafe_fd=0)
    assert_true(fd > -1)

    # unsafe_fd_as_arg validates and returns the fd
    var validated = unsafe_fd_as_arg(fd)
    assert_true(validated == fd)

    # Close the duped fd
    close(unsafe_fd=fd)

    print("All fd tests passed.")
