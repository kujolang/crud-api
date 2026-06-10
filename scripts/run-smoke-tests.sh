#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
KUJO_BIN="${KUJO_BIN:-kujo}" bash tests/t0_04_api_smoke_suite.sh
