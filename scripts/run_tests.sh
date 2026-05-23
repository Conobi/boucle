#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/_arch_sub.sh"
apply_arch_substitution

# Avoid stale-package gotcha: mojo run -I . picks up boucle.mojopkg ahead
# of source. Wipe it so tests always see the current source.
rm -f "$PROJECT_DIR/boucle.mojopkg"

TESTS=(
    tests/boucle/_sys/linux/raw/test_ctypes.mojo
    tests/boucle/_sys/linux/raw/test_net_structs.mojo
    tests/boucle/_sys/linux/raw/test_facade.mojo
    tests/boucle/_sys/linux/raw/test_aarch64_syscall_numbers.mojo
    tests/boucle/_sys/test_triple_helpers.mojo
    tests/boucle/_sys/test_linux_facade.mojo
    tests/boucle/_sys/linux/test_errno.mojo
    tests/boucle/_sys/linux/test_fd.mojo
    tests/boucle/test_ctypes_reexports.mojo
    tests/boucle/test_handle.mojo
    tests/boucle/test_token.mojo
    tests/boucle/test_error.mojo
    tests/boucle/test_buffer.mojo
    tests/boucle/net/test_options.mojo
    tests/boucle/net/test_ip.mojo
    tests/boucle/net/test_ip_parse.mojo
    tests/boucle/net/test_ip_display.mojo
    tests/boucle/net/test_addr.mojo
    tests/boucle/_sys/linux/test_mm.mojo
    tests/boucle/_sys/linux/test_ucontext.mojo
    tests/boucle/_sys/linux/io_uring/test_setup.mojo
    tests/boucle/_sys/linux/io_uring/test_nop.mojo
    tests/boucle/_sys/linux/io_uring/test_ops.mojo
    tests/boucle/_sys/linux/io_uring/test_provide_buffers.mojo
    tests/boucle/_sys/linux/io_uring/test_register_buf_ring.mojo
    tests/boucle/_sys/linux/io_uring/test_multishot_recv.mojo
    tests/boucle/_sys/linux/io_uring/test_multishot_recvmsg.mojo
    tests/boucle/_sys/linux/epoll/test_epoll.mojo
    tests/boucle/_sys/linux/net/test_syscalls.mojo
    tests/boucle/net/test_socket.mojo
    tests/boucle/net/test_socket_setopt.mojo
    tests/boucle/net/test_socket_connect.mojo
    tests/boucle/net/test_socket_factories.mojo
    tests/boucle/test_completion_reexports.mojo
    tests/boucle/test_completion.mojo
    tests/boucle/test_completion_io.mojo
    tests/boucle/test_completion_connect.mojo
    tests/boucle/test_interest.mojo
    tests/boucle/test_readiness_state.mojo
    tests/boucle/test_readiness.mojo
    tests/boucle/test_stackful.mojo
    tests/boucle/test_stackful_io.mojo
    tests/boucle/test_coroutine_pool.mojo
)

# Tests that exercise io_uring (via raw syscalls or CompletionLoop) plus
# epoll-on-pipe behavior that qemu-user-static cannot emulate. Set
# SKIP_IO_URING_TESTS=1 (e.g. on the aarch64 qemu CI job) to skip them.
SKIP_UNDER_QEMU=(
    tests/boucle/_sys/linux/io_uring/test_setup.mojo
    tests/boucle/_sys/linux/io_uring/test_nop.mojo
    tests/boucle/_sys/linux/io_uring/test_ops.mojo
    tests/boucle/_sys/linux/io_uring/test_provide_buffers.mojo
    tests/boucle/_sys/linux/io_uring/test_register_buf_ring.mojo
    tests/boucle/_sys/linux/io_uring/test_multishot_recv.mojo
    tests/boucle/_sys/linux/io_uring/test_multishot_recvmsg.mojo
    tests/boucle/_sys/linux/epoll/test_epoll.mojo
    tests/boucle/test_completion.mojo
    tests/boucle/test_completion_io.mojo
    tests/boucle/test_completion_connect.mojo
    tests/boucle/test_readiness.mojo
    tests/boucle/test_stackful_io.mojo
)

is_skipped() {
    local needle="$1"
    for skip in "${SKIP_UNDER_QEMU[@]}"; do
        if [ "$skip" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

cd "$PROJECT_DIR"

PASS=0
FAIL=0
SKIP=0

for test in "${TESTS[@]}"; do
    if [ "${SKIP_IO_URING_TESTS:-0}" = "1" ] && is_skipped "$test"; then
        echo "--- SKIPPED (SKIP_IO_URING_TESTS=1): $test ---"
        echo ""
        SKIP=$((SKIP + 1))
        continue
    fi
    echo "--- Running: $test ---"
    if mojo run -I . -D ASSERT=all "$test"; then
        echo "--- PASSED: $test ---"
        PASS=$((PASS + 1))
    else
        echo "--- FAILED: $test ---"
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "Results: $PASS passed, $FAIL failed, $SKIP skipped (out of ${#TESTS[@]})"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
