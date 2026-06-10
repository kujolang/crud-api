#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
SERVER_PID=""

mkdir -p "$TMP_DIR"

cleanup() {
	if [[ -n "$SERVER_PID" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

start_server() {
	local port="$1"
	local db_path="$2"
	local auth_token="$3"
	local log_path="$4"

	rm -f "$db_path" "$db_path-shm" "$db_path-wal"

	(
		cd "$ROOT_DIR"
		KUJO_CRUD_PORT="$port" KUJO_CRUD_DB_PATH="$db_path" KUJO_CRUD_AUTH_TOKEN="$auth_token" "$KUJO_BIN" run main.kujo --interpreter >"$log_path" 2>&1
	) &
	SERVER_PID=$!

	for _ in $(seq 1 40); do
		if curl -s "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
			break
		fi
		sleep 0.25
	done

	if ! curl -s "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
		echo "Server failed to start on port $port"
		cat "$log_path"
		exit 1
	fi
}

stop_server() {
	if [[ -n "$SERVER_PID" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
		SERVER_PID=""
	fi
}

assert_status() {
	local expected="$1"
	local actual="$2"
	local label="$3"
	if [[ "$actual" != "$expected" ]]; then
		echo "Assertion failed ($label): expected HTTP $expected, got $actual"
		exit 1
	fi
}

run_json_post() {
	local port="$1"
	local path="$2"
	local payload="$3"
	local body_file="$4"
	local auth_token="${5:-}"

	if [[ -n "$auth_token" ]]; then
		curl -s -o "$body_file" -w "%{http_code}" -X POST "http://127.0.0.1:$port$path" \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer $auth_token" \
			-d "$payload"
	else
		curl -s -o "$body_file" -w "%{http_code}" -X POST "http://127.0.0.1:$port$path" \
			-H "Content-Type: application/json" \
			-d "$payload"
	fi
}

extract_item_id() {
	local body_file="$1"
	local extracted
	extracted="$(grep -Eo '"id"[[:space:]]*:[[:space:]]*[0-9]+' "$body_file" | head -n 1 | grep -Eo '[0-9]+' || true)"
	if [[ -z "$extracted" ]]; then
		echo ""
		return
	fi
	echo "$extracted"
}

extract_updated_at() {
	local body_file="$1"
	local extracted
	extracted="$(grep -Eo '"updated_at"[[:space:]]*:[[:space:]]*"[^"]+"' "$body_file" | head -n 1 | sed -E 's/.*"updated_at"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/' || true)"
	if [[ -z "$extracted" ]]; then
		echo ""
		return
	fi
	echo "$extracted"
}

# Phase 1: general CRUD smoke without auth token.
PORT_NO_AUTH="4113"
DB_NO_AUTH="$TMP_DIR/t0_04_no_auth.db"
LOG_NO_AUTH="$TMP_DIR/t0_04_no_auth.log"
start_server "$PORT_NO_AUTH" "$DB_NO_AUTH" "" "$LOG_NO_AUTH"

curl -s "http://127.0.0.1:$PORT_NO_AUTH/" > "$TMP_DIR/t0_04_root.body"
curl -s "http://127.0.0.1:$PORT_NO_AUTH/health" > "$TMP_DIR/t0_04_health.body"
curl -s "http://127.0.0.1:$PORT_NO_AUTH/items?limit=5&offset=0" > "$TMP_DIR/t0_04_items.body"

create_status=$(run_json_post "$PORT_NO_AUTH" "/items" '{"title":"t0-04 smoke","content":"create ok","status":"draft"}' "$TMP_DIR/t0_04_create.body")
assert_status "201" "$create_status" "create item without auth"

created_id="$(extract_item_id "$TMP_DIR/t0_04_create.body")"
if [[ -z "$created_id" ]]; then
	echo "Failed to extract created item id"
	cat "$TMP_DIR/t0_04_create.body"
	exit 1
fi

created_updated_at="$(extract_updated_at "$TMP_DIR/t0_04_create.body")"
if [[ -z "$created_updated_at" ]]; then
	echo "Failed to extract created item updated_at"
	cat "$TMP_DIR/t0_04_create.body"
	exit 1
fi

patch_status=$(curl -s -o "$TMP_DIR/t0_04_patch.body" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT_NO_AUTH/items/$created_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $created_updated_at" \
	-d '{"content":"patched"}')
assert_status "200" "$patch_status" "patch created item"

patched_updated_at="$(extract_updated_at "$TMP_DIR/t0_04_patch.body")"
if [[ -z "$patched_updated_at" ]]; then
	echo "Failed to extract patched item updated_at"
	cat "$TMP_DIR/t0_04_patch.body"
	exit 1
fi

delete_status=$(curl -s -o "$TMP_DIR/t0_04_delete.body" -w "%{http_code}" -X DELETE "http://127.0.0.1:$PORT_NO_AUTH/items/$created_id" \
	-H "If-Unmodified-Since: $patched_updated_at")
assert_status "200" "$delete_status" "delete created item"

stop_server

# Phase 2: auth-mode smoke checks.
PORT_AUTH="4114"
DB_AUTH="$TMP_DIR/t0_04_auth.db"
LOG_AUTH="$TMP_DIR/t0_04_auth.log"
AUTH_TOKEN="testtoken"
start_server "$PORT_AUTH" "$DB_AUTH" "$AUTH_TOKEN" "$LOG_AUTH"

unauth_status=$(run_json_post "$PORT_AUTH" "/items" '{"title":"unauth","content":"should fail","status":"draft"}' "$TMP_DIR/t0_04_unauth.body")
assert_status "401" "$unauth_status" "unauthorized create should fail"

auth_status=$(run_json_post "$PORT_AUTH" "/items" '{"title":"auth","content":"should pass","status":"draft"}' "$TMP_DIR/t0_04_auth.body" "$AUTH_TOKEN")
assert_status "201" "$auth_status" "authorized create should pass"

stop_server

echo "t0_04_api_smoke_suite: PASS"
