#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
PORT_PRIMARY="4140"
PORT_RESTORE="4141"
DB_PRIMARY="$TMP_DIR/t5_02_primary.db"
DB_BACKUP="$TMP_DIR/t5_02_backup.db"
DB_RESTORE="$TMP_DIR/t5_02_restore.db"
LOG_PRIMARY="$TMP_DIR/t5_02_primary.log"
LOG_RESTORE="$TMP_DIR/t5_02_restore.log"
KUJO_BIN="${KUJO_BIN:-kujo}"

mkdir -p "$TMP_DIR"
rm -f \
	"$DB_PRIMARY" "$DB_PRIMARY-shm" "$DB_PRIMARY-wal" \
	"$DB_BACKUP" "$DB_BACKUP-shm" "$DB_BACKUP-wal" \
	"$DB_RESTORE" "$DB_RESTORE-shm" "$DB_RESTORE-wal" \
	"$LOG_PRIMARY" "$LOG_RESTORE" \
	"$TMP_DIR/t5_02_project_create.json" "$TMP_DIR/t5_02_item_create.json" "$TMP_DIR/t5_02_projects_restored.json"

clear_port() {
	local port="$1"
	local existing_pid
	existing_pid="$(lsof -ti tcp:"$port" || true)"
	if [[ -n "$existing_pid" ]]; then
		kill "$existing_pid" >/dev/null 2>&1 || true
		sleep 0.25
	fi
}

wait_for_health() {
	local port="$1"
	local log_path="$2"
	for _ in $(seq 1 40); do
		if curl -s "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.25
	done
	echo "Server failed to start on port $port"
	cat "$log_path"
	exit 1
}

cleanup() {
	if [[ -n "${PRIMARY_PID:-}" ]]; then
		kill "$PRIMARY_PID" >/dev/null 2>&1 || true
		wait "$PRIMARY_PID" >/dev/null 2>&1 || true
	fi
	if [[ -n "${RESTORE_PID:-}" ]]; then
		kill "$RESTORE_PID" >/dev/null 2>&1 || true
		wait "$RESTORE_PID" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

clear_port "$PORT_PRIMARY"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_PRIMARY" \
	KUJO_CRUD_DB_PATH="$DB_PRIMARY" \
	KUJO_CRUD_AUTH_TOKEN="" \
	"$KUJO_BIN" run main.ruff --interpreter >"$LOG_PRIMARY" 2>&1
) &
PRIMARY_PID=$!
wait_for_health "$PORT_PRIMARY" "$LOG_PRIMARY"

project_name="DR Drill Project $RANDOM"
create_project_status=$(curl -sS -o "$TMP_DIR/t5_02_project_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_PRIMARY/projects" \
	-H "Content-Type: application/json" \
	-d '{"name":"'"$project_name"'","description":"Created for backup restore drill."}')
if [[ "$create_project_status" != "201" ]]; then
	echo "Expected project create to return 201, got $create_project_status"
	exit 1
fi
project_id=$(node -e 'const fs=require("fs");const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(o.id));' "$TMP_DIR/t5_02_project_create.json")

create_item_status=$(curl -sS -o "$TMP_DIR/t5_02_item_create.json" -w "%{http_code}" -X POST "http://127.0.0.1:$PORT_PRIMARY/items" \
	-H "Content-Type: application/json" \
	-d '{"title":"DR drill item","content":"Verify restore content integrity","status":"published","project_id":'"$project_id"'}')
if [[ "$create_item_status" != "201" ]]; then
	echo "Expected item create to return 201, got $create_item_status"
	exit 1
fi

kill "$PRIMARY_PID" >/dev/null 2>&1 || true
wait "$PRIMARY_PID" >/dev/null 2>&1 || true
PRIMARY_PID=""

cp "$DB_PRIMARY" "$DB_BACKUP"
if [[ -f "$DB_PRIMARY-wal" ]]; then
	cp "$DB_PRIMARY-wal" "$DB_BACKUP-wal"
fi
if [[ -f "$DB_PRIMARY-shm" ]]; then
	cp "$DB_PRIMARY-shm" "$DB_BACKUP-shm"
fi

cp "$DB_BACKUP" "$DB_RESTORE"
if [[ -f "$DB_BACKUP-wal" ]]; then
	cp "$DB_BACKUP-wal" "$DB_RESTORE-wal"
fi
if [[ -f "$DB_BACKUP-shm" ]]; then
	cp "$DB_BACKUP-shm" "$DB_RESTORE-shm"
fi

clear_port "$PORT_RESTORE"
(
	cd "$ROOT_DIR"
	KUJO_CRUD_PORT="$PORT_RESTORE" \
	KUJO_CRUD_DB_PATH="$DB_RESTORE" \
	KUJO_CRUD_AUTH_TOKEN="" \
	"$KUJO_BIN" run main.ruff --interpreter >"$LOG_RESTORE" 2>&1
) &
RESTORE_PID=$!
wait_for_health "$PORT_RESTORE" "$LOG_RESTORE"

restored_projects_status=$(curl -sS -o "$TMP_DIR/t5_02_projects_restored.json" -w "%{http_code}" "http://127.0.0.1:$PORT_RESTORE/projects")
if [[ "$restored_projects_status" != "200" ]]; then
	echo "Expected restored projects endpoint to return 200, got $restored_projects_status"
	exit 1
fi

project_found=$(node -e 'const fs=require("fs");const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const name=process.argv[2];const projects=Array.isArray(data.projects)?data.projects:[];process.stdout.write(projects.some((p)=>p.name===name)?"yes":"no");' "$TMP_DIR/t5_02_projects_restored.json" "$project_name")
if [[ "$project_found" != "yes" ]]; then
	echo "Restored dataset missing expected project: $project_name"
	cat "$TMP_DIR/t5_02_projects_restored.json"
	exit 1
fi

echo "t5_02_backup_restore_drill: PASS"
