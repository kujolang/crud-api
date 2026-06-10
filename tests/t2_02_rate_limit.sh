#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
PORT="4130"
DB_PATH="$TMP_DIR/t2_02_rate_limit.db"
LOG_PATH="$TMP_DIR/t2_02_rate_limit.log"
AUTH_TOKEN="testtoken"
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
	KUJO_CRUD_PORT="$PORT" \
	KUJO_CRUD_DB_PATH="$DB_PATH" \
	KUJO_CRUD_AUTH_TOKEN="$AUTH_TOKEN" \
	KUJO_CRUD_RATE_LIMIT_MAX_WRITES="2" \
	KUJO_CRUD_RATE_LIMIT_WINDOW_SECONDS="2" \
	"$KUJO_BIN" run main.ruff --interpreter >"$LOG_PATH" 2>&1
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

post_status() {
	local body_file="$1"
	curl -s -D "$TMP_DIR/t2_02_headers.out" -o "$body_file" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
		-H "Authorization: Bearer $AUTH_TOKEN" \
		-H "Content-Type: application/json" \
		-d '{"title":"rate-test","content":"payload","status":"draft"}'
}

status_1=$(post_status "$TMP_DIR/t2_02_post1.body")
status_2=$(post_status "$TMP_DIR/t2_02_post2.body")
status_3=$(post_status "$TMP_DIR/t2_02_post3.body")

if [[ "$status_1" != "201" || "$status_2" != "201" ]]; then
	echo "Expected first two writes to succeed, got $status_1 and $status_2"
	exit 1
fi

if [[ "$status_3" != "429" ]]; then
	echo "Expected third write to be rate-limited (429), got $status_3"
	exit 1
fi

if ! grep -q "retry_after_seconds" "$TMP_DIR/t2_02_post3.body"; then
	echo "Rate-limit body missing retry_after_seconds"
	cat "$TMP_DIR/t2_02_post3.body"
	exit 1
fi

if ! grep -qi "Retry-After:" "$TMP_DIR/t2_02_headers.out"; then
	echo "Rate-limit response missing Retry-After header"
	exit 1
fi

sleep 2.2
status_4=$(post_status "$TMP_DIR/t2_02_post4.body")
if [[ "$status_4" != "201" ]]; then
	echo "Expected write after window reset to succeed, got $status_4"
	exit 1
fi

echo "t2_02_rate_limit: PASS"
