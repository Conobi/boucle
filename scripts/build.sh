#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve target arch: BOUCLE_TARGET_ARCH overrides; otherwise map `uname -m`.
detect_arch() {
    if [ -n "${BOUCLE_TARGET_ARCH:-}" ]; then
        echo "$BOUCLE_TARGET_ARCH"
        return
    fi
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) echo "x86_64" ;;
    esac
}

ARCH="$(detect_arch)"
FACADE="$PROJECT_DIR/boucle/_sys/linux/raw/__init__.mojo"

# Restore the facade to its committed (x86_64) form on EXIT, regardless of
# whether the build succeeds. Guarantees the working tree is clean.
restore_facade() {
    if [ -n "${_BOUCLE_FACADE_BACKUP:-}" ] && [ -f "$_BOUCLE_FACADE_BACKUP" ]; then
        mv -f "$_BOUCLE_FACADE_BACKUP" "$FACADE"
        unset _BOUCLE_FACADE_BACKUP
    fi
}
trap restore_facade EXIT INT TERM

if [ "$ARCH" = "aarch64" ]; then
    _BOUCLE_FACADE_BACKUP="$(mktemp -t boucle-facade.XXXXXX)"
    export _BOUCLE_FACADE_BACKUP
    cp "$FACADE" "$_BOUCLE_FACADE_BACKUP"
    # Rewrite every `from boucle._sys.linux.raw.x86_64...` import inside
    # the ARCH_SLOT_START/END block to point at aarch64. The marker keeps
    # the substitution scoped and idempotent.
    sed -i \
        -e '/# ARCH_SLOT_START/,/# ARCH_SLOT_END/ s|from boucle\._sys\.linux\.raw\.x86_64|from boucle._sys.linux.raw.aarch64|g' \
        "$FACADE"
elif [ "$ARCH" != "x86_64" ]; then
    echo "Unsupported BOUCLE_TARGET_ARCH: $ARCH" >&2
    exit 1
fi

cd "$PROJECT_DIR"

echo "Removing stale .mojopkg files..."
rm -f *.mojopkg

echo "Building boucle (arch=$ARCH)..."
mojo package boucle -o boucle.mojopkg

echo "All packages built."
ls -lh *.mojopkg
