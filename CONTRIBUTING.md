# Contributing

## Development Workflow

- Keep changes scoped and minimal.
- Prefer one logical checklist item per commit.
- Keep tests and docs updated in the same change.

## Agent And Example Hygiene

- Read `README.md`, this file, and `docs/implementation-checklist.md` before changing behavior.
- Prioritize copyable examples over tests: examples should model the most token-efficient idioms we want agents to imitate.
- Treat `README.md` and `docs/api-examples.md` as canonical examples.
- In Kujo source and examples, prefer tiny local helpers for repeated output, fatal exits, and route guard blocks once repetition distracts from the feature being shown.
- Treat `tests/` as executable contract coverage; keep explicit output there when it makes failures clearer.
- Treat `docs/openapi.yaml` as the API contract, not a prose example.
- Exclude generated/bulk paths from broad readability sweeps unless the task explicitly targets them: `frontend/package-lock.json`, `frontend/node_modules/`, `frontend/.next/`, `.tmp/`, and `data/*.db*`.
- Prefer `rg --glob '!frontend/package-lock.json' --glob '!frontend/node_modules/**' --glob '!frontend/.next/**' --glob '!.tmp/**' --glob '!data/*.db*' ...` for broad searches.
- Clearly label any stale, legacy, generated, or expected-fail examples that remain in docs.

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
