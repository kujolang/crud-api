# Contributing

Thanks for helping improve this Kujo ecosystem project.

This guide is intended for standalone Kujo tools and primitives. It does not
cover the core Kujo language repo, Kujo Skills, or Kujo Workflows when those
projects have their own contribution rules.

## Development Principles

- Keep changes focused, reviewable, and tied to one user-visible concern.
- Prefer deterministic, local-first behavior.
- Do not add network calls, provider calls, timestamps, or machine-specific
  output to core command paths unless the feature explicitly requires it.
- Preserve redaction, path safety, guarded cleanup, and stable output ordering.
- Add tests for behavior changes. Bug fixes should include regression coverage.
- Avoid speculative refactors unless they directly simplify the change at hand.

For CRUD API specifically, keep API write auth, request validation, optimistic
concurrency checks, and contract-tested item/project behavior intact.

## Local Setup

Use the Kujo runtime expected by this repository. Most repos support one of
these environment variables:

```bash
export KUJO_BIN=kujo
export KUJO=kujo
```

Primary backend entry point:

```text
main.kujo
```

The frontend playground lives under `frontend/`. Check the repo README,
`Makefile`, `tests/`, and `scripts/` directory for the authoritative local
commands.

## Agent And Example Hygiene

Start with `README.md`, `CONTRIBUTING.md`, relevant docs, and examples before
broad source sweeps.

Treat user-facing examples as canonical copyable surfaces. Examples should be
short, runnable, and representative of the idioms humans and agents should copy.

CRUD API canonical surfaces:

- Read `README.md`, this file, and `docs/implementation-checklist.md` before
  changing behavior.
- Treat `README.md` and `docs/api-examples.md` as canonical examples.
- Treat `docs/openapi.yaml` as the API contract, not a prose example.
- Treat `tests/` as executable contract coverage; keep explicit output there
  when it makes failures clearer.

Exclude generated and bulk paths from broad searches unless the task explicitly
targets them. For this repo, skip `frontend/package-lock.json`,
`frontend/node_modules/`, `frontend/.next/`, `.tmp/`, and `data/*.db*`.

```bash
rg --glob '!frontend/package-lock.json' \
  --glob '!frontend/node_modules/**' \
  --glob '!frontend/.next/**' \
  --glob '!.tmp/**' \
  --glob '!data/*.db*' \
  "pattern" README.md CONTRIBUTING.md docs src tests scripts frontend
```

Document any important search exclusions in larger cleanup or audit PRs.

## Code Standards

- Match the surrounding code style before introducing a new abstraction.
- Keep command output readable and stable.
- Prefer small local helpers for repeated output, error, section, or key/value
  formatting once repetition distracts from the behavior.
- Keep CLI and API contracts explicit: flags, exit codes, JSON fields, artifact
  paths, endpoints, request bodies, status codes, and documented examples should
  agree with parser and handler behavior.
- Keep config honest. A config key should either change observable behavior or
  be clearly documented as reserved.
- Preserve compatibility entrypoints and wrappers when a repo provides them.
- In Kujo source and examples, prefer tiny local helpers for repeated output,
  fatal exits, and route guard blocks once repetition distracts from the feature
  being shown.
- Clearly label stale, legacy, generated, or expected-fail examples that remain
  in docs.

## Kujo Runtime Notes

Kujo ecosystem tools often follow these defensive patterns:

- Prefer `while` loops in complex functions.
- Avoid duplicate local names across branches in the same function.
- Keep imports at the top of the file.
- Export functions that are imported by another module.
- Guard dictionary access with `has_key()` or local helper wrappers.
- Remember that some builtins return int-like `1`/`0` instead of booleans.
- Guard parsing operations such as JSON or TOML parsing and validate the result.
- Keep deep tree walks iterative where recursion risks VM stack limits.
- Be careful with byte-based string indexes versus character-based substring
  operations; use existing repo helpers when available.

Follow stricter runtime notes in the local repo when they exist.

## Validation

Before opening a pull request, run the strongest local validation available for
the repo.

Required CRUD API validation:

```bash
make test KUJO_BIN=kujo
cd frontend && npm run lint && npm run build
cd frontend && npm audit
KUJO_BIN=kujo bash tests/t5_01_performance_baseline.sh
KUJO_BIN=kujo bash tests/t5_02_backup_restore_drill.sh
```

Keep contract validation passing when endpoint behavior changes:

```bash
bash tests/t4_03_contract_validation.sh
```

If the repo includes additional frontend, bridge, Rust, Python, shell,
performance, or security checks, run the relevant commands documented in that
repo.

Tests should stay offline and deterministic unless the repo explicitly marks a
live-provider or network test as opt-in.

## Documentation And Changelog

Update docs when behavior, configuration, command output, flags, schemas,
examples, or security expectations change.

When endpoint behavior changes, update `docs/openapi.yaml`. Also check:

- `README.md`
- `docs/`
- command reference or flags docs
- schema or report format docs
- examples
- `CHANGELOG.md`

User-visible behavior changes should include a changelog entry when the repo has
a changelog.

## Security Expectations

- Avoid introducing new unauthenticated write paths.
- Keep optimistic concurrency checks intact for update/delete operations.
- Do not log secret values.

## Pull Requests

A good PR includes:

- Problem statement.
- Change summary.
- User-visible impact.
- Validation commands and outcomes.
- Documentation or changelog updates.
- Known risks or follow-up tasks, if any.

Keep generated artifacts out of commits unless the artifact is the reviewed
output of the change.
