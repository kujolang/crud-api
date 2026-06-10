#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
KUJO_BIN="${KUJO_BIN:-kujo}"
PORT="4138"
DB_PATH="$TMP_DIR/t4_03_contract.db"
LOG_PATH="$TMP_DIR/t4_03_contract.log"
CONTRACT_PATH="$ROOT_DIR/docs/openapi.yaml"

mkdir -p "$TMP_DIR"
rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$LOG_PATH"

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

for required_path in "/items:" "/items/{id}:" "/projects:" "/projects/{id}:" "/projects/{id}/items:"; do
	if ! grep -q "$required_path" "$CONTRACT_PATH"; then
		echo "OpenAPI contract missing required path: $required_path"
		exit 1
	fi
done

for required_header in "If-Unmodified-Since" "cursor" "sort_by" "q"; do
	if ! grep -q "$required_header" "$CONTRACT_PATH"; then
		echo "OpenAPI contract missing expected parameter/header: $required_header"
		exit 1
	fi
done

for required_security in "securitySchemes:" "BearerAuth:" "HeaderValueAuth:"; do
	if ! grep -Fq -- "$required_security" "$CONTRACT_PATH"; then
		echo "OpenAPI contract missing expected security declaration: $required_security"
		exit 1
	fi
done

bearer_security_count="$(grep -Fc -- "- BearerAuth: []" "$CONTRACT_PATH")"
if [[ "$bearer_security_count" -lt 5 ]]; then
	echo "OpenAPI contract missing write-operation BearerAuth security blocks"
	exit 1
fi

header_security_count="$(grep -Fc -- "- HeaderValueAuth: []" "$CONTRACT_PATH")"
if [[ "$header_security_count" -lt 5 ]]; then
	echo "OpenAPI contract missing write-operation HeaderValueAuth security blocks"
	exit 1
fi

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

for path in "/" "/health" "/projects" "/items?limit=5&sort_by=id&sort_dir=desc"; do
	status=$(curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT$path")
	if [[ "$status" != "200" ]]; then
		echo "Expected $path to return 200, got $status"
		exit 1
	fi
done

project_name="Contract Validation Project $RANDOM"
project_payload='{"name":"'"$project_name"'","description":"Used to validate OpenAPI examples."}'

create_project_status=$(curl -sS -o "$TMP_DIR/t4_03_project_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/projects" \
	-H "Content-Type: application/json" \
	-d "$project_payload")
if [[ "$create_project_status" != "201" ]]; then
	echo "Expected project create to return 201, got $create_project_status"
	exit 1
fi
project_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t4_03_project_create.json")

create_item_status=$(curl -sS -o "$TMP_DIR/t4_03_item_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"Contract item","content":"Validating openapi contract","status":"draft","project_id":'"$project_id"'}')
if [[ "$create_item_status" != "201" ]]; then
	echo "Expected item create to return 201, got $create_item_status"
	exit 1
fi
item_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t4_03_item_create.json")
item_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t4_03_item_create.json")

project_items_status=$(curl -sS -o "$TMP_DIR/t4_03_project_items.json" -w "%{http_code}" "http://127.0.0.1:$PORT/projects/$project_id/items")
if [[ "$project_items_status" != "200" ]]; then
	echo "Expected project items endpoint to return 200, got $project_items_status"
	exit 1
fi

sleep 1

replace_status=$(curl -sS -o "$TMP_DIR/t4_03_item_replace.json" -w "%{http_code}" -X PUT "http://127.0.0.1:$PORT/items/$item_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $item_updated_at" \
	-d '{"title":"Contract item replaced","content":"PUT example","status":"published","project_id":'"$project_id"'}')
if [[ "$replace_status" != "200" ]]; then
	echo "Expected item replace to return 200, got $replace_status"
	exit 1
fi
replace_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t4_03_item_replace.json")

sleep 1

patch_status=$(curl -sS -o "$TMP_DIR/t4_03_item_patch.json" -w "%{http_code}" -X PATCH "http://127.0.0.1:$PORT/items/$item_id" \
	-H "Content-Type: application/json" \
	-H "If-Unmodified-Since: $replace_updated_at" \
	-d '{"content":"PATCH example"}')
if [[ "$patch_status" != "200" ]]; then
	echo "Expected item patch to return 200, got $patch_status"
	exit 1
fi
patch_updated_at=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.updated_at));' "$TMP_DIR/t4_03_item_patch.json")

delete_status=$(curl -sS -o "$TMP_DIR/t4_03_item_delete.json" -w "%{http_code}" -X DELETE "http://127.0.0.1:$PORT/items/$item_id" \
	-H "If-Unmodified-Since: $patch_updated_at")
if [[ "$delete_status" != "200" ]]; then
	echo "Expected item delete to return 200, got $delete_status"
	exit 1
fi

echo "t4_03_contract_validation: PASS"
