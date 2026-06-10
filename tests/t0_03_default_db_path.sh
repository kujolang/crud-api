#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="4112"
DATA_DB="$ROOT_DIR/data/kujo_crud_api.db"
LOG_PATH="$ROOT_DIR/.tmp/t0_03_server.log"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$ROOT_DIR/.tmp"
rm -f "$DATA_DB" "$DATA_DB-shm" "$DATA_DB-wal"

existing_pid="$(lsof -ti tcp:"$PORT" || true)"
if [[ -n "$existing_pid" ]]; then
	kill "$existing_pid" >/dev/null 2>&1 || true
	sleep 0.25
fi

cleanup() {
	if [[ -n "${SERVER_PID:-}" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT" "$KUJO_BIN" run main.ruff --interpreter >"$LOG_PATH" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 40); do
	if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.25
done

if ! curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
	echo "Server did not start in time"
	cat "$LOG_PATH"
	exit 1
fi

if [[ ! -f "$DATA_DB" ]]; then
	echo "Expected default database file not found at $DATA_DB"
	exit 1
fi

echo "t0_03_default_db_path: PASS"
