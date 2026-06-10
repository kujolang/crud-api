#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4136"
DB_PATH="$TMP_DIR/t3_03_cursor.db"
LOG_PATH="$TMP_DIR/t3_03_cursor.log"

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
	"$KUJO_BIN" run main.kujo --interpreter >"$LOG_PATH" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 40); do
	if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.25
done

curl -sS "http://127.0.0.1:$PORT/items?limit=2&sort_by=id&sort_dir=desc&cursor=id:999999999" >"$TMP_DIR/t3_03_page1.json"
next_cursor=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.next_cursor||""));' "$TMP_DIR/t3_03_page1.json")
if [[ -z "$next_cursor" ]]; then
	echo "Expected next_cursor on first cursor page"
	exit 1
fi

create_status=$(curl -sS -o "$TMP_DIR/t3_03_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"T3-03 Insert During Pagination","content":"Inserted between pages","status":"draft"}')
if [[ "$create_status" != "201" ]]; then
	echo "Expected item create during cursor test to return 201, got $create_status"
	exit 1
fi
created_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t3_03_create.json")

curl -sS "http://127.0.0.1:$PORT/items?limit=2&sort_by=id&sort_dir=desc&cursor=$next_cursor" >"$TMP_DIR/t3_03_page2.json"
no_overlap=$(node -e 'const fs=require("fs");const p1=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const p2=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));const s1=new Set((p1.items||[]).map((i)=>i.id));const overlap=(p2.items||[]).some((i)=>s1.has(i.id));process.stdout.write(overlap?"no":"yes");' "$TMP_DIR/t3_03_page1.json" "$TMP_DIR/t3_03_page2.json")
if [[ "$no_overlap" != "yes" ]]; then
	echo "Expected cursor pages to avoid duplicate IDs"
	exit 1
fi

created_not_in_page2=$(node -e 'const fs=require("fs");const p2=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const createdId=Number(process.argv[2]);const found=(p2.items||[]).some((i)=>i.id===createdId);process.stdout.write(found?"no":"yes");' "$TMP_DIR/t3_03_page2.json" "$created_id")
if [[ "$created_not_in_page2" != "yes" ]]; then
	echo "Expected newly inserted item to not affect already-issued cursor page sequence"
	exit 1
fi

bad_cursor_status=$(curl -sS -o "$TMP_DIR/t3_03_bad_cursor.json" -w "%{http_code}" "http://127.0.0.1:$PORT/items?sort_by=title&sort_dir=asc&cursor=id:2")
if [[ "$bad_cursor_status" != "400" ]]; then
	echo "Expected invalid cursor/sort combination to return 400, got $bad_cursor_status"
	exit 1
fi

offset_status=$(curl -sS -o "$TMP_DIR/t3_03_offset.json" -w "%{http_code}" "http://127.0.0.1:$PORT/items?limit=2&offset=2")
if [[ "$offset_status" != "200" ]]; then
	echo "Expected offset mode to remain functional, got $offset_status"
	exit 1
fi

echo "t3_03_cursor_pagination: PASS"
