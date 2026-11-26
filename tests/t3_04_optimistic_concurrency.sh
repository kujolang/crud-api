#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/helpers/http.sh"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4137"
DB_PATH="$TMP_DIR/t3_04_concurrency.db"
LOG_PATH="$TMP_DIR/t3_04_concurrency.log"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$LOG_PATH"

require_free_port "$PORT"

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
	exec "$KUJO_BIN" run main.kujo --interpreter >"$LOG_PATH" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 40); do
	if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.25
done

create_status=$(curl -sS -o "$TMP_DIR/t3_04_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"T3-04 OCC","content":"base","status":"draft"}')
if [[ "$create_status" != "201" ]]; then
	echo "Expected create to return 201, got $create_status"
	exit 1
fi

created_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t3_04_create.json")
initial_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t3_04_create.json")

missing_header_status=$(curl -sS -o "$TMP_DIR/t3_04_missing_header.json" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT/items/$created_id" \
	-H "Content-Type: application/json" \
	-d '{"content":"no header"}')
if [[ "$missing_header_status" != "428" ]]; then
	echo "Expected missing precondition header to return 428, got $missing_header_status"
	exit 1
fi


first_update_status=$(curl -sS -o "$TMP_DIR/t3_04_first_update.json" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT/items/$created_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $initial_updated_at" \
	-d '{"content":"first update"}')
if [[ "$first_update_status" != "200" ]]; then
	echo "Expected first optimistic update to return 200, got $first_update_status"
	exit 1
fi

current_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t3_04_first_update.json")
if [[ "$current_updated_at" == "$initial_updated_at" ]]; then
	echo "Expected updated_at to change after successful write"
	exit 1
fi

create_project_status=$(curl -sS -o "$TMP_DIR/t3_04_project_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/projects" \
	-H "Content-Type: application/json" \
	-d '{"name":"T3-04 OCC Project","description":"project-only patch coverage"}')
if [[ "$create_project_status" != "201" ]]; then
	echo "Expected project create to return 201, got $create_project_status"
	exit 1
fi

project_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t3_04_project_create.json")


project_patch_status=$(curl -sS -o "$TMP_DIR/t3_04_project_patch.json" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT/items/$created_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $current_updated_at" \
	-d '{"project_id":'"$project_id"'}')
if [[ "$project_patch_status" != "200" ]]; then
	echo "Expected project_id-only patch to return 200, got $project_patch_status"
	exit 1
fi

patched_project_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.project_id));' "$TMP_DIR/t3_04_project_patch.json")
if [[ "$patched_project_id" != "$project_id" ]]; then
	echo "Expected project_id-only patch to persist relation update"
	exit 1
fi

current_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t3_04_project_patch.json")

stale_update_status=$(curl -sS -o "$TMP_DIR/t3_04_stale_update.json" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT/items/$created_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $initial_updated_at" \
	-d '{"content":"stale update"}')
if [[ "$stale_update_status" != "409" ]]; then
	echo "Expected stale optimistic update to return 409, got $stale_update_status"
	exit 1
fi

reported_current=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.current_updated_at||""));' "$TMP_DIR/t3_04_stale_update.json")
if [[ "$reported_current" != "$current_updated_at" ]]; then
	echo "Expected 409 payload to include current_updated_at"
	exit 1
fi

# Two ordinary edits from the same revision produce one write and one conflict.
for label in left right; do
	(
		curl -sS -o "$TMP_DIR/t3_04_race_$label.json" -w '%{http_code}\n' \
			-X PATCH "http://127.0.0.1:$PORT/items/$created_id" \
			-H "Content-Type: application/json" -H "If-Unmodified-Since: $current_updated_at" \
			-d "{\"content\":\"$label edit\"}" > "$TMP_DIR/t3_04_race_$label.status"
	) &
	if [[ "$label" == left ]]; then left_pid=$!; else right_pid=$!; fi
done
wait "$left_pid"
wait "$right_pid"
if [[ "$(sort "$TMP_DIR/t3_04_race_left.status" "$TMP_DIR/t3_04_race_right.status")" != $'200\n409' ]]; then
	echo "Expected one successful edit and one conflict from the same revision"
	exit 1
fi

echo "t3_04_optimistic_concurrency: PASS"
