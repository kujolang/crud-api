#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers/http.sh"
PORT="4112"
LOG_PATH="$ROOT_DIR/.tmp/t0_03_server.log"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$ROOT_DIR/.tmp"
require_free_port "$PORT"
TEST_ROOT="$(mktemp -d "$ROOT_DIR/.tmp/t0_03.XXXXXX")"
DATA_DB="$TEST_ROOT/data/kujo_crud_api.db"

cleanup() {
	if [[ -n "${SERVER_PID:-}" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$DATA_DB" "$DATA_DB-shm" "$DATA_DB-wal"
	rmdir "$TEST_ROOT/data" "$TEST_ROOT" 2>/dev/null || true
}
trap cleanup EXIT
mkdir "$TEST_ROOT/data"

(
	cd "$TEST_ROOT"
	unset KUJO_CRUD_DB_PATH
	KUJO_CRUD_PORT="$PORT" exec "$KUJO_BIN" run "$ROOT_DIR/main.kujo" --interpreter >"$LOG_PATH" 2>&1
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
