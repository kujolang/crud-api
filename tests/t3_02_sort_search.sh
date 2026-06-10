#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4135"
DB_PATH="$TMP_DIR/t3_02_sort_search.db"
LOG_PATH="$TMP_DIR/t3_02_sort_search.log"

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

curl -sS "http://127.0.0.1:$PORT/items?sort_by=title&sort_dir=asc&limit=10&offset=0" >"$TMP_DIR/t3_02_sorted.json"
is_sorted=$(node -e 'const fs=require("fs");const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const items=data.items||[];let ok=true;for(let i=1;i<items.length;i++){if(String(items[i-1].title).localeCompare(String(items[i].title))>0){ok=false;break;}}process.stdout.write(ok?"yes":"no");' "$TMP_DIR/t3_02_sorted.json")
if [[ "$is_sorted" != "yes" ]]; then
	echo "Expected title ascending sort order"
	exit 1
fi

curl -sS "http://127.0.0.1:$PORT/items?q=draft&limit=20&offset=0" >"$TMP_DIR/t3_02_search.json"
search_valid=$(node -e 'const fs=require("fs");const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const items=data.items||[];if(items.length===0){process.stdout.write("no");process.exit(0);}const ok=items.every((item)=>{const hay=(String(item.title)+" "+String(item.content)).toLowerCase();return hay.includes("draft");});process.stdout.write(ok?"yes":"no");' "$TMP_DIR/t3_02_search.json")
if [[ "$search_valid" != "yes" ]]; then
	echo "Expected search query to filter items by text"
	exit 1
fi

bad_sort_status=$(curl -sS -o "$TMP_DIR/t3_02_bad_sort.json" -w "%{http_code}" "http://127.0.0.1:$PORT/items?sort_by=created")
if [[ "$bad_sort_status" != "400" ]]; then
	echo "Expected invalid sort_by to return 400, got $bad_sort_status"
	exit 1
fi

bad_dir_status=$(curl -sS -o "$TMP_DIR/t3_02_bad_dir.json" -w "%{http_code}" "http://127.0.0.1:$PORT/items?sort_dir=descending")
if [[ "$bad_dir_status" != "400" ]]; then
	echo "Expected invalid sort_dir to return 400, got $bad_dir_status"
	exit 1
fi

long_query=$(printf 'a%.0s' {1..121})
long_q_status=$(curl -sS -o "$TMP_DIR/t3_02_long_q.json" -w "%{http_code}" "http://127.0.0.1:$PORT/items?q=$long_query")
if [[ "$long_q_status" != "400" ]]; then
	echo "Expected overly long q to return 400, got $long_q_status"
	exit 1
fi

echo "t3_02_sort_search: PASS"
