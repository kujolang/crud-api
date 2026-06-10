# Security Policy

## Reporting A Vulnerability

Please report security issues privately.

- Open a private security advisory on GitHub for this repository.
- If private advisory is not available, email the maintainer and include:
  - Impact summary
  - Reproduction steps
  - Affected endpoints or files
  - Suggested remediation, if known

Please do not open public issues for unpatched vulnerabilities.

## Disclosure Process

- We acknowledge new reports within 3 business days.
- We aim to provide an initial triage decision within 7 business days.
- If the issue is accepted, we coordinate fix, test evidence, and release notes.
- Public disclosure occurs after a patch is released.

## Supported Versions

Only the latest `main` branch is supported for security fixes in this showcase project.

## Security Baseline

Release candidates should pass all of the following:

- Backend regression suite: `make test`
- Frontend quality gates: `npm run lint && npm run build` (from `frontend`)
- Dependency audit: `npm audit` (from `frontend`) with zero high/critical vulnerabilities
- Contract checks: `bash tests/t4_03_contract_validation.sh`
- Performance baseline: `bash tests/t5_01_performance_baseline.sh`
- Backup/restore drill: `bash tests/t5_02_backup_restore_drill.sh`
- CI static analysis: CodeQL job must pass

## Scope Notes

This project is a showcase. It is not a managed hosted service and does not include SLA guarantees.
