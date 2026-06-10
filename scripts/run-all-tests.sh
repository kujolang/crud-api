#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"

cd "$ROOT_DIR"

for test_file in tests/*.sh; do
	chmod +x "$test_file"
	KUJO_BIN="$KUJO_BIN" bash "$test_file"
done

echo "run-all-tests: PASS"
