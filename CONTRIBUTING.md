# Contributing

## Development Workflow

- Keep changes scoped and minimal.
- Prefer one logical checklist item per commit.
- Keep tests and docs updated in the same change.

## Required Local Validation

Before opening a pull request, run:

- `make test KUJO_BIN=/path/to/kujo`
- `cd frontend && npm run lint && npm run build`
- `cd frontend && npm audit`
- `KUJO_BIN=/path/to/kujo bash tests/t5_01_performance_baseline.sh`
- `KUJO_BIN=/path/to/kujo bash tests/t5_02_backup_restore_drill.sh`

## API Contract Discipline

- If endpoint behavior changes, update `docs/openapi.yaml`.
- Keep contract validation passing: `bash tests/t4_03_contract_validation.sh`.

## Security Expectations

- Avoid introducing new unauthenticated write paths.
- Keep optimistic concurrency checks intact for update/delete operations.
- Do not log secret values.

## Pull Request Expectations

Include in PR description:

- Problem statement
- Change summary
- Validation commands and outcomes
- Any known risks or follow-up tasks
