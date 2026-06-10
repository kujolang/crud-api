#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4134"
DB_PATH="$TMP_DIR/t3_01_projects_relationship.db"
LOG_PATH="$TMP_DIR/t3_01_projects_relationship.log"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$LOG_PATH"

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

curl -sS "http://127.0.0.1:$PORT/projects" >"$TMP_DIR/t3_01_projects.json"

projects_count=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.count||0));' "$TMP_DIR/t3_01_projects.json")
if [[ "$projects_count" -lt 1 ]]; then
	echo "Expected seeded projects to be available"
	exit 1
fi

first_project_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));if(!o.projects||o.projects.length===0){process.exit(1)}process.stdout.write(String(o.projects[0].id));' "$TMP_DIR/t3_01_projects.json")

create_status=$(curl -sS -o "$TMP_DIR/t3_01_create_item.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"T3-01 Relationship Item","content":"Project-linked item","status":"draft","project_id":'"$first_project_id"'}')
if [[ "$create_status" != "201" ]]; then
	echo "Expected project-linked item creation to return 201, got $create_status"
	exit 1
fi

created_item_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t3_01_create_item.json")

curl -sS "http://127.0.0.1:$PORT/projects/$first_project_id/items" >"$TMP_DIR/t3_01_project_items.json"
contains_item=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const id=Number(process.argv[2]);const found=(o.items||[]).some((item)=>item.id===id);process.stdout.write(found?"yes":"no");' "$TMP_DIR/t3_01_project_items.json" "$created_item_id")
if [[ "$contains_item" != "yes" ]]; then
	echo "Expected project relation endpoint to include created item"
	exit 1
fi

curl -sS "http://127.0.0.1:$PORT/items?project_id=$first_project_id&limit=20&offset=0" >"$TMP_DIR/t3_01_items_by_project.json"
project_filter_count=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.count||0));' "$TMP_DIR/t3_01_items_by_project.json")
if [[ "$project_filter_count" -lt 1 ]]; then
	echo "Expected /items project filter to return related records"
	exit 1
fi

echo "t3_01_projects_relationship: PASS"
