#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="4115"
API_HOST="${KUJO_CRUD_API_HOST:-127.0.0.1}"
TMP_DIR="$ROOT_DIR/.tmp"
DB_PATH="$TMP_DIR/t1_01.db"
LOG_PATH="$TMP_DIR/t1_01_server.log"
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
	KUJO_CRUD_PORT="$PORT" KUJO_CRUD_API_HOST="$API_HOST" KUJO_CRUD_DB_PATH="$DB_PATH" "$KUJO_BIN" run main.kujo --interpreter >"$LOG_PATH" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 40); do
	if curl -s "http://$API_HOST:$PORT/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.25
done

if ! curl -s "http://$API_HOST:$PORT/health" >/dev/null 2>&1; then
	echo "Server did not start from modular entrypoint"
	cat "$LOG_PATH"
	exit 1
fi

listener_line="$(lsof -nP -iTCP:$PORT -sTCP:LISTEN | tail -n 1 || true)"
if [[ -z "$listener_line" || "$listener_line" != *"$API_HOST:$PORT"* ]]; then
	echo "Expected listener on $API_HOST:$PORT, got:"
	echo "$listener_line"
	cat "$LOG_PATH"
	exit 1
fi

root_payload="$(curl -s "http://$API_HOST:$PORT/")"
health_payload="$(curl -s "http://$API_HOST:$PORT/health")"

if ! echo "$root_payload" | grep -q "Kujo CRUD Starter API"; then
	echo "Root payload did not contain expected service metadata"
	exit 1
fi

if ! echo "$health_payload" | grep -q '"status":"ok"'; then
	echo "Health payload did not contain expected status"
	exit 1
fi

if ! grep -q "Server: http://$API_HOST:$PORT" "$LOG_PATH"; then
	echo "Startup banner did not report the actual bind host"
	cat "$LOG_PATH"
	exit 1
fi

echo "t1_01_entrypoint_smoke: PASS"
