# Release Checklist

Use this checklist for each release candidate. Production readiness still requires target-environment deployment, secret, storage, monitoring, and human approval evidence outside this local showcase gate.

## Pre-Release

- Confirm branch is up to date with `main`.
- Confirm API contract changes are reflected in `docs/openapi.yaml`.
- Confirm auth strategy behavior is documented in `README.md`.

## Quality Gates

Run and verify all commands are green:

- `make test KUJO_BIN=/path/to/kujo`
- `cd frontend && npm run lint && npm run build`
- `cd frontend && npm audit`
- `KUJO_BIN=/path/to/kujo bash tests/t5_01_performance_baseline.sh`
- `KUJO_BIN=/path/to/kujo bash tests/t5_02_backup_restore_drill.sh`

## Security Gates

- Verify no new high/critical advisories in frontend dependencies.
- Verify CI secret pattern scan passes with zero findings.
- Verify frontend SBOM artifact is generated in CI.
- Verify write-route auth behavior:
  - `KUJO_CRUD_AUTH_STRATEGY=static_bearer`
  - `KUJO_CRUD_AUTH_STRATEGY=header_value`
- Verify optimistic concurrency protections (`409` and `428`) still hold.

## Packaging And Notes

- Summarize user-visible changes.
- Summarize breaking changes (if any).
- Include migration notes for dependency upgrades.

## Publish

- Tag release commit.
- Push tags.
- Publish release notes referencing test evidence.

## Post-Release

- Monitor CI and issue tracker for regressions.
- If needed, prepare rollback commit with focused scope.
