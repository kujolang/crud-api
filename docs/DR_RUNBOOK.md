# Disaster Recovery Runbook

## Objective

Validate that a backup copy of the SQLite database can be restored and served by the API without data loss for recently written records.

## Recovery Targets

- RTO (target): 10 minutes for local single-node recovery.
- RPO (target): Last successful database backup copy.

## Automated Drill

This repository includes an automated restore drill:

```bash
KUJO_BIN=/path/to/kujo bash tests/t5_02_backup_restore_drill.sh
```

The drill performs these steps:

1. Starts API against a primary database.
2. Creates a project and item.
3. Stops server and copies backup artifacts.
4. Restores into a fresh database path.
5. Starts API against restored database.
6. Verifies created project exists post-restore.

## Manual Recovery Procedure

1. Stop the API process.
2. Copy latest backup database file into recovery path.
3. Copy matching `-wal` and `-shm` files when present.
4. Start API with `KUJO_CRUD_DB_PATH` set to the recovered database.
5. Validate `/health`, `/projects`, and `/items` endpoints.
6. Confirm recent writes are present.

## Verification Commands

```bash
curl -s http://127.0.0.1:4100/health
curl -s http://127.0.0.1:4100/projects
curl -s 'http://127.0.0.1:4100/items?limit=20&sort_by=id&sort_dir=desc'
```

## Failure Handling

- If restore validation fails, keep the recovered copy for investigation.
- Roll back to prior known-good backup copy.
- Record incident timeline and root cause before next release.
