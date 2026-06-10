#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="4111"
TMP_DIR="$ROOT_DIR/.tmp"
DB_PATH="$TMP_DIR/t0_01.db"
LOG_PATH="$TMP_DIR/t0_01_server.log"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal"

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
	echo "--- server log ---"
	cat "$LOG_PATH"
	exit 1
fi

assert_status() {
	local expected="$1"
	local actual="$2"
	local label="$3"
	if [[ "$actual" != "$expected" ]]; then
		echo "Assertion failed ($label): expected HTTP $expected, got $actual"
		exit 1
	fi
}

run_post() {
	local content_type="$1"
	local payload="$2"
	local body_file="$3"
	if [[ -n "$content_type" ]]; then
		curl -s -o "$body_file" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
			-H "Content-Type: $content_type" \
			-d "$payload"
	else
		curl -s -o "$body_file" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
			-d "$payload"
	fi
}

status_json=$(run_post "application/json" '{"title":"t0-01 json","content":"ok","status":"draft"}' "$TMP_DIR/t0_01_json_ok.body")
assert_status "201" "$status_json" "application/json should succeed"

status_text=$(run_post "text/plain" '{"title":"t0-01 txt","content":"bad","status":"draft"}' "$TMP_DIR/t0_01_text_plain.body")
assert_status "400" "$status_text" "text/plain should fail"
if ! grep -q "Content-Type must be application/json" "$TMP_DIR/t0_01_text_plain.body"; then
	echo "Expected JSON content-type error message not found"
	cat "$TMP_DIR/t0_01_text_plain.body"
	exit 1
fi

status_charset=$(run_post "application/json; charset=utf-8" '{"title":"t0-01 charset","content":"ok","status":"draft"}' "$TMP_DIR/t0_01_charset_ok.body")
assert_status "201" "$status_charset" "application/json with charset should succeed"

status_malformed=$(run_post "application/jsonx" '{"title":"t0-01 malformed","content":"bad","status":"draft"}' "$TMP_DIR/t0_01_json_bad.body")
assert_status "400" "$status_malformed" "application/jsonx should fail"

status_missing=$(run_post "" '{"title":"t0-01 missing","content":"bad","status":"draft"}' "$TMP_DIR/t0_01_missing_header.body")
assert_status "400" "$status_missing" "missing content-type should fail"

echo "t0_01_content_type_validation: PASS"
