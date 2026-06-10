#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$TMP_DIR"

cleanup() {
	if [[ -n "${SERVER_PID_STATIC:-}" ]]; then
		kill "$SERVER_PID_STATIC" >/dev/null 2>&1 || true
		wait "$SERVER_PID_STATIC" >/dev/null 2>&1 || true
	fi
	if [[ -n "${SERVER_PID_HEADER:-}" ]]; then
		kill "$SERVER_PID_HEADER" >/dev/null 2>&1 || true
		wait "$SERVER_PID_HEADER" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

wait_for_health() {
	local port="$1"
	for _ in $(seq 1 40); do
		if curl -s "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
			return
		fi
		sleep 0.25
	done
	echo "Server failed to start on port $port"
	exit 1
}

clear_port() {
	local port="$1"
	local existing_pid
	existing_pid="$(lsof -ti tcp:"$port" || true)"
	if [[ -n "$existing_pid" ]]; then
		kill "$existing_pid" >/dev/null 2>&1 || true
		sleep 0.25
	fi
}

# Strategy 1: static bearer token
PORT_STATIC="4131"
DB_STATIC="$TMP_DIR/t2_03_static.db"
clear_port "$PORT_STATIC"
rm -f "$DB_STATIC" "$DB_STATIC-shm" "$DB_STATIC-wal"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_STATIC" \
	KUJO_CRUD_DB_PATH="$DB_STATIC" \
	KUJO_CRUD_AUTH_STRATEGY="static_bearer" \
	KUJO_CRUD_AUTH_TOKEN="static-token" \
	"$KUJO_BIN" run main.ruff --interpreter >"$TMP_DIR/t2_03_static.log" 2>&1
) &
SERVER_PID_STATIC=$!
wait_for_health "$PORT_STATIC"

static_root=$(curl -s "http://127.0.0.1:$PORT_STATIC/")
if ! echo "$static_root" | grep -q '"auth_strategy":"static_bearer"'; then
	echo "Expected static strategy metadata to report static_bearer"
	exit 1
fi
if ! echo "$static_root" | grep -q '"auth_enabled":true'; then
	echo "Expected static strategy metadata to report auth_enabled=true"
	exit 1
fi

static_unauth_status=$(curl -s -o "$TMP_DIR/t2_03_static_unauth.body" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_STATIC/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"s1","content":"s1","status":"draft"}')
if [[ "$static_unauth_status" != "401" ]]; then
	echo "Expected static strategy unauthorized write to return 401, got $static_unauth_status"
	exit 1
fi

static_auth_status=$(curl -s -o "$TMP_DIR/t2_03_static_auth.body" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_STATIC/items" \
	-H "Authorization: Bearer static-token" \
	-H "Content-Type: application/json" \
	-d '{"title":"s1","content":"s1","status":"draft"}')
if [[ "$static_auth_status" != "201" ]]; then
	echo "Expected static strategy authorized write to return 201, got $static_auth_status"
	exit 1
fi

kill "$SERVER_PID_STATIC" >/dev/null 2>&1 || true
wait "$SERVER_PID_STATIC" >/dev/null 2>&1 || true
SERVER_PID_STATIC=""

# Strategy 2: header value strategy
PORT_HEADER="4132"
DB_HEADER="$TMP_DIR/t2_03_header.db"
clear_port "$PORT_HEADER"
rm -f "$DB_HEADER" "$DB_HEADER-shm" "$DB_HEADER-wal"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_HEADER" \
	KUJO_CRUD_DB_PATH="$DB_HEADER" \
	KUJO_CRUD_AUTH_STRATEGY="header_value" \
	KUJO_CRUD_AUTH_HEADER_NAME="X-Auth-Key" \
	KUJO_CRUD_AUTH_HEADER_VALUE="header-token" \
	"$KUJO_BIN" run main.ruff --interpreter >"$TMP_DIR/t2_03_header.log" 2>&1
) &
SERVER_PID_HEADER=$!
wait_for_health "$PORT_HEADER"

header_root=$(curl -s "http://127.0.0.1:$PORT_HEADER/")
if ! echo "$header_root" | grep -q '"auth_strategy":"header_value"'; then
	echo "Expected header strategy metadata to report header_value"
	exit 1
fi
if ! echo "$header_root" | grep -q '"auth_enabled":true'; then
	echo "Expected header strategy metadata to report auth_enabled=true"
	exit 1
fi

header_unauth_status=$(curl -s -o "$TMP_DIR/t2_03_header_unauth.body" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_HEADER/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"h1","content":"h1","status":"draft"}')
if [[ "$header_unauth_status" != "401" ]]; then
	echo "Expected header strategy unauthorized write to return 401, got $header_unauth_status"
	exit 1
fi

header_auth_status=$(curl -s -o "$TMP_DIR/t2_03_header_auth.body" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_HEADER/items" \
	-H "X-Auth-Key: header-token" \
	-H "Content-Type: application/json" \
	-d '{"title":"h1","content":"h1","status":"draft"}')
if [[ "$header_auth_status" != "201" ]]; then
	echo "Expected header strategy authorized write to return 201, got $header_auth_status"
	exit 1
fi

echo "t2_03_auth_strategy: PASS"
