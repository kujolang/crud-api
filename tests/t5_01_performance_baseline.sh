#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
PORT="4139"
DB_PATH="$TMP_DIR/t5_01_perf.db"
LOG_PATH="$TMP_DIR/t5_01_perf.log"
LATENCY_FILE="$TMP_DIR/t5_01_latency_seconds.txt"
KUJO_BIN="${KUJO_BIN:-kujo}"
P95_THRESHOLD_SECONDS="0.400"
AVG_THRESHOLD_SECONDS="0.180"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$LOG_PATH" "$LATENCY_FILE"

clear_port() {
	local port="$1"
	local existing_pid
	existing_pid="$(lsof -ti tcp:"$port" || true)"
	if [[ -n "$existing_pid" ]]; then
		kill "$existing_pid" >/dev/null 2>&1 || true
		sleep 0.25
	fi
}

cleanup() {
	if [[ -n "${SERVER_PID:-}" ]]; then
		kill "$SERVER_PID" >/dev/null 2>&1 || true
		wait "$SERVER_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

clear_port "$PORT"

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

if ! curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
	echo "Performance test server did not start"
	cat "$LOG_PATH"
	exit 1
fi

for _ in $(seq 1 5); do
	curl -s -o /dev/null "http://127.0.0.1:$PORT/health"
	curl -s -o /dev/null "http://127.0.0.1:$PORT/items?limit=20&sort_by=id&sort_dir=desc"
done

for _ in $(seq 1 50); do
	curl -s -o /dev/null -w "%{time_total}\n" "http://127.0.0.1:$PORT/health" >> "$LATENCY_FILE"
	done
for _ in $(seq 1 50); do
	curl -s -o /dev/null -w "%{time_total}\n" "http://127.0.0.1:$PORT/items?limit=20&sort_by=id&sort_dir=desc" >> "$LATENCY_FILE"
	done

sample_count="$(wc -l < "$LATENCY_FILE" | tr -d ' ')"
if [[ "$sample_count" -lt 100 ]]; then
	echo "Expected at least 100 latency samples, got $sample_count"
	exit 1
fi

p95_seconds="$(sort -n "$LATENCY_FILE" | awk '{ values[NR] = $1 } END { idx = int((NR * 95 + 99) / 100); if (idx < 1) idx = 1; if (idx > NR) idx = NR; printf "%.6f", values[idx] }')"
avg_seconds="$(awk '{ total += $1 } END { if (NR == 0) { print "0.000000"; exit } printf "%.6f", total / NR }' "$LATENCY_FILE")"

if ! awk -v measured="$p95_seconds" -v threshold="$P95_THRESHOLD_SECONDS" 'BEGIN { exit (measured <= threshold) ? 0 : 1 }'; then
	echo "Performance baseline failed: p95 ${p95_seconds}s exceeds ${P95_THRESHOLD_SECONDS}s"
	exit 1
fi

if ! awk -v measured="$avg_seconds" -v threshold="$AVG_THRESHOLD_SECONDS" 'BEGIN { exit (measured <= threshold) ? 0 : 1 }'; then
	echo "Performance baseline failed: average ${avg_seconds}s exceeds ${AVG_THRESHOLD_SECONDS}s"
	exit 1
fi

echo "t5_01_performance_baseline: PASS (samples=$sample_count p95=${p95_seconds}s avg=${avg_seconds}s)"
