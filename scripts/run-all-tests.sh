#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUJO_BIN="${KUJO_BIN:-kujo}"
NODE_BIN="${NODE_BIN:-/Users/robertdevore/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
NODE_SHIM_DIR="$ROOT_DIR/.tmp/node-shim"

cd "$ROOT_DIR"
mkdir -p "$NODE_SHIM_DIR"
ln -sf "$NODE_BIN" "$NODE_SHIM_DIR/node"
PATH="$NODE_SHIM_DIR:$PATH"

for test_file in tests/*.sh; do
	chmod +x "$test_file"
	KUJO_BIN="$KUJO_BIN" bash "$test_file"
done

echo "run-all-tests: PASS"
