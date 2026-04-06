#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS=(
    # Will be populated as tests are added
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
