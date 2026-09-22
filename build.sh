#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Building native macOS GUI modal (zed-create)..."
swiftc -O \
    src/DirectoryScanner.swift \
    src/FuzzyMatcher.swift \
    src/FileCreator.swift \
    src/ModalWindow.swift \
    src/main.swift \
    -o zed-create

echo "✓ Built successfully: $SCRIPT_DIR/zed-create"
