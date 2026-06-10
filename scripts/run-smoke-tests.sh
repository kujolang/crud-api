#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_BIN="${NODE_BIN:-/Users/robertdevore/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node}"
NODE_SHIM_DIR="$ROOT_DIR/.tmp/node-shim"

cd "$ROOT_DIR"
mkdir -p "$NODE_SHIM_DIR"
ln -sf "$NODE_BIN" "$NODE_SHIM_DIR/node"
PATH="$NODE_SHIM_DIR:$PATH"
KUJO_BIN="${KUJO_BIN:-kujo}" bash tests/t0_04_api_smoke_suite.sh
