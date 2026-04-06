#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "Removing stale .mojopkg files..."
rm -f *.mojopkg

echo "Building io..."
mojo package io -o io.mojopkg

# Workaround: Mojo 0.26.2 implicit stdlib imports shadow `io` with `std.io`.
# Copy under the `boucle` name so tests and external consumers can import.
# When implicit stdlib imports are removed in a future Mojo release, this
# line can be dropped and consumers can `from io...` directly.
echo "Creating boucle.mojopkg (test alias)..."
cp io.mojopkg boucle.mojopkg

echo "All packages built."
ls -lh *.mojopkg
