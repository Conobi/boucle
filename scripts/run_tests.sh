#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS=(
    tests/boucle/_sys/linux/raw/test_ctypes.mojo
    tests/boucle/_sys/linux/raw/test_net_structs.mojo
    tests/boucle/_sys/linux/test_errno.mojo
    tests/boucle/_sys/linux/test_fd.mojo
    tests/boucle/test_handle.mojo
    tests/boucle/test_token.mojo
    tests/boucle/test_error.mojo
    tests/boucle/test_buffer.mojo
    tests/boucle/net/test_options.mojo
    tests/boucle/net/test_ip.mojo
    tests/boucle/net/test_addr.mojo
    tests/boucle/_sys/linux/test_mm.mojo
    tests/boucle/_sys/linux/io_uring/test_setup.mojo
    tests/boucle/_sys/linux/io_uring/test_nop.mojo
    tests/boucle/_sys/linux/io_uring/test_ops.mojo
    tests/boucle/_sys/linux/epoll/test_epoll.mojo
    tests/boucle/_sys/linux/net/test_syscalls.mojo
    tests/boucle/net/test_socket.mojo
    tests/boucle/test_completion.mojo
    tests/boucle/test_completion_io.mojo
    tests/boucle/test_interest.mojo
    tests/boucle/test_readiness_state.mojo
)

cd "$PROJECT_DIR"

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do
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

echo "Results: $PASS passed, $FAIL failed (out of ${#TESTS[@]})"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
