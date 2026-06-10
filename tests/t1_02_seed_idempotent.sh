#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
DB_PATH="$TMP_DIR/t1_02_seed.db"
LOG_1="$TMP_DIR/t1_02_first.log"
LOG_2="$TMP_DIR/t1_02_second.log"
KUJO_BIN="${KUJO_BIN:-kujo}"
FIRST_PID=""
SECOND_PID=""
LAST_TOTAL=""

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal"

cleanup() {
	if [[ -n "$FIRST_PID" ]]; then
		kill "$FIRST_PID" >/dev/null 2>&1 || true
		wait "$FIRST_PID" >/dev/null 2>&1 || true
	fi
	if [[ -n "$SECOND_PID" ]]; then
		kill "$SECOND_PID" >/dev/null 2>&1 || true
		wait "$SECOND_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

extract_total() {
	local payload="$1"
	echo "$payload" | grep -Eo '"total"[[:space:]]*:[[:space:]]*[0-9]+' | head -n 1 | grep -Eo '[0-9]+'
}

start_server() {
	local port="$1"
	local log_path="$2"
	local pid_var="$3"

	lsof -ti:"$port" | xargs -I{} kill {} >/dev/null 2>&1 || true

	(
		cd "$ROOT_DIR"
		KUJO_CRUD_PORT="$port" KUJO_CRUD_DB_PATH="$DB_PATH" "$KUJO_BIN" run main.ruff --interpreter >"$log_path" 2>&1
	) &
	local pid=$!
	eval "$pid_var=$pid"

	for _ in $(seq 1 40); do
		if curl -s "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
			return
		fi
		sleep 0.25
	done

	echo "Server did not start on port $port"
	cat "$log_path"
	exit 1
}

fetch_total() {
	local port="$1"
	local list_payload
	list_payload="$(curl -s "http://127.0.0.1:$port/items?limit=100&offset=0")"
	LAST_TOTAL="$(extract_total "$list_payload")"
	if [[ -z "$LAST_TOTAL" ]]; then
		echo "Could not extract total from list payload"
		echo "$list_payload"
		exit 1
	fi
}

stop_server_pid() {
	local pid="$1"
	if [[ -n "$pid" ]]; then
		kill "$pid" >/dev/null 2>&1 || true
		wait "$pid" >/dev/null 2>&1 || true
	fi
}

start_server "4116" "$LOG_1" "FIRST_PID"
fetch_total "4116"
if [[ "$LAST_TOTAL" != "5" ]]; then
	echo "Expected first total to be 5, got $LAST_TOTAL"
	exit 1
fi

stop_server_pid "$FIRST_PID"
FIRST_PID=""

start_server "4117" "$LOG_2" "SECOND_PID"
fetch_total "4117"
if [[ "$LAST_TOTAL" != "5" ]]; then
	echo "Expected second total to remain 5 after restart, got $LAST_TOTAL"
	exit 1
fi

echo "t1_02_seed_idempotent: PASS"
