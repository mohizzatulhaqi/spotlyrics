#!/bin/zsh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
swiftc -O "$ROOT"/Sources/Core/*.swift "$ROOT/Tests/main.swift" -o "$TMP/tests" 2>&1 | grep -E "error" || true
"$TMP/tests"
STATUS=$?
rm -rf "$TMP"
exit $STATUS
