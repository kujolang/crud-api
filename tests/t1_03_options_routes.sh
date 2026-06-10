#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="4126"
TMP_DIR="$ROOT_DIR/.tmp"
DB_PATH="$TMP_DIR/t1_03_options.db"
LOG_PATH="$TMP_DIR/t1_03_options.log"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal"

cleanup() {
	if [[ -n "${SERVER_PID:-}" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT" KUJO_CRUD_DB_PATH="$DB_PATH" "$KUJO_BIN" run main.ruff --interpreter >"$LOG_PATH" 2>&1
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

assert_options() {
	local path="$1"
	local out_file="$TMP_DIR/t1_03_$(echo "$path" | tr '/:' '__').out"
	local status

	status=$(curl -s -D "$out_file" -o /dev/null -w "%{http_code}" -X OPTIONS "http://127.0.0.1:$PORT$path")
	if [[ "$status" != "200" ]]; then
		echo "OPTIONS $path returned $status"
		exit 1
	fi

	if ! grep -qi "Access-Control-Allow-Methods:" "$out_file"; then
		echo "OPTIONS $path missing Access-Control-Allow-Methods header"
		exit 1
	fi
}

assert_options "/"
assert_options "/health"
assert_options "/items"
assert_options "/items/1"

echo "t1_03_options_routes: PASS"
