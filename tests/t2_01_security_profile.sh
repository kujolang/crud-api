#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$TMP_DIR"

cleanup() {
	if [[ -n "${SERVER_PID_DEMO:-}" ]]; then
		kill "$SERVER_PID_DEMO" >/dev/null 2>&1 || true
		wait "$SERVER_PID_DEMO" >/dev/null 2>&1 || true
	fi
	if [[ -n "${SERVER_PID_PROD:-}" ]]; then
		kill "$SERVER_PID_PROD" >/dev/null 2>&1 || true
		wait "$SERVER_PID_PROD" >/dev/null 2>&1 || true
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

# Demo profile should run with defaults and expose demo profile metadata.
PORT_DEMO="4127"
DB_DEMO="$TMP_DIR/t2_01_demo.db"
rm -f "$DB_DEMO" "$DB_DEMO-shm" "$DB_DEMO-wal"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_DEMO" KUJO_CRUD_DB_PATH="$DB_DEMO" KUJO_CRUD_SECURITY_PROFILE="demo" "$KUJO_BIN" run main.kujo --interpreter >"$TMP_DIR/t2_01_demo.log" 2>&1
) &
SERVER_PID_DEMO=$!
wait_for_health "$PORT_DEMO"

demo_root="$(curl -s "http://127.0.0.1:$PORT_DEMO/")"
if ! echo "$demo_root" | grep -q '"security_profile":"demo"'; then
	echo "Demo profile metadata check failed"
	exit 1
fi

kill "$SERVER_PID_DEMO" >/dev/null 2>&1 || true
wait "$SERVER_PID_DEMO" >/dev/null 2>&1 || true
SERVER_PID_DEMO=""

# Production profile should fail fast without required auth token.
set +e
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="4128" KUJO_CRUD_DB_PATH="$TMP_DIR/t2_01_prod_fail.db" KUJO_CRUD_SECURITY_PROFILE="production" "$KUJO_BIN" run main.kujo --interpreter >"$TMP_DIR/t2_01_prod_fail.log" 2>&1
)
prod_fail_code=$?
set -e

if [[ "$prod_fail_code" -eq 0 ]]; then
	echo "Production profile unexpectedly started without required auth token"
	exit 1
fi

if ! grep -q "KUJO_CRUD_AUTH_TOKEN is required" "$TMP_DIR/t2_01_prod_fail.log"; then
	echo "Expected production failure message not found"
	cat "$TMP_DIR/t2_01_prod_fail.log"
	exit 1
fi

# Production profile should reject short auth secrets.
set +e
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="4142" KUJO_CRUD_DB_PATH="$TMP_DIR/t2_01_prod_short.db" KUJO_CRUD_SECURITY_PROFILE="production" KUJO_CRUD_AUTH_TOKEN="short" KUJO_CRUD_CORS_ORIGIN="http://localhost:3000" "$KUJO_BIN" run main.kujo --interpreter >"$TMP_DIR/t2_01_prod_short.log" 2>&1
)
prod_short_code=$?
set -e

if [[ "$prod_short_code" -eq 0 ]]; then
	echo "Production profile unexpectedly started with a short auth token"
	exit 1
fi

if ! grep -q "at least 16 characters" "$TMP_DIR/t2_01_prod_short.log"; then
	echo "Expected production short-token failure message not found"
	cat "$TMP_DIR/t2_01_prod_short.log"
	exit 1
fi

# Production profile should start when auth token and strict CORS origin are provided.
PORT_PROD="4129"
DB_PROD="$TMP_DIR/t2_01_prod_ok.db"
rm -f "$DB_PROD" "$DB_PROD-shm" "$DB_PROD-wal"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_PROD" KUJO_CRUD_DB_PATH="$DB_PROD" KUJO_CRUD_SECURITY_PROFILE="production" KUJO_CRUD_AUTH_TOKEN="testtoken-16char" KUJO_CRUD_CORS_ORIGIN="http://localhost:3000" "$KUJO_BIN" run main.kujo --interpreter >"$TMP_DIR/t2_01_prod_ok.log" 2>&1
) &
SERVER_PID_PROD=$!
wait_for_health "$PORT_PROD"

prod_root="$(curl -s "http://127.0.0.1:$PORT_PROD/")"
if ! echo "$prod_root" | grep -q '"security_profile":"production"'; then
	echo "Production profile metadata check failed"
	exit 1
fi

kill "$SERVER_PID_PROD" >/dev/null 2>&1 || true
wait "$SERVER_PID_PROD" >/dev/null 2>&1 || true
SERVER_PID_PROD=""

echo "t2_01_security_profile: PASS"
