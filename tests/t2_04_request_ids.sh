#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4133"
DB_PATH="$TMP_DIR/t2_04_request_ids.db"
LOG_PATH="$TMP_DIR/t2_04_request_ids.log"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$LOG_PATH"

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
	KUJO_CRUD_PORT="$PORT" \
	KUJO_CRUD_DB_PATH="$DB_PATH" \
	KUJO_CRUD_AUTH_TOKEN="" \
	"$KUJO_BIN" run main.ruff --interpreter >"$LOG_PATH" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 40); do
	if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.25
done

curl -sS -D "$TMP_DIR/t2_04_auto.headers" -o "$TMP_DIR/t2_04_auto.body" "http://127.0.0.1:$PORT/health" >/dev/null
if ! grep -qi '^X-Request-Id:' "$TMP_DIR/t2_04_auto.headers"; then
	echo "Expected X-Request-Id header on health response"
	exit 1
fi

auto_request_id=$(grep -i '^X-Request-Id:' "$TMP_DIR/t2_04_auto.headers" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')
if [[ -z "$auto_request_id" ]]; then
	echo "Expected non-empty generated request ID"
	exit 1
fi

curl -sS -D "$TMP_DIR/t2_04_client.headers" -o "$TMP_DIR/t2_04_client.body" "http://127.0.0.1:$PORT/health" -H "X-Request-Id: client-id-123" >/dev/null
propagated_request_id=$(grep -i '^X-Request-Id:' "$TMP_DIR/t2_04_client.headers" | head -n 1 | awk -F': ' '{print $2}' | tr -d '\r')
if [[ "$propagated_request_id" != "client-id-123" ]]; then
	echo "Expected provided request ID to be propagated"
	exit 1
fi

if ! grep -q '"event":"request.start"' "$LOG_PATH"; then
	echo "Expected structured request.start log entries"
	exit 1
fi

if ! grep -q '"event":"request.complete"' "$LOG_PATH"; then
	echo "Expected structured request.complete log entries"
	exit 1
fi

if ! grep -q '"request_id":"client-id-123"' "$LOG_PATH"; then
	echo "Expected propagated request ID in logs"
	exit 1
fi

echo "t2_04_request_ids: PASS"
