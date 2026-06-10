# Kujo CRUD API Showcase - Implementation Checklist

## Purpose
This document is the execution checklist for evolving this repository from a minimal demo into a reusable CRUD starter for other developers.

Use this with README.md as the source of truth for implementation work.

## Agent Workflow Contract
Follow this sequence for every task:

1. Read README.md and this file before starting.
2. Pick the highest-priority unchecked task whose dependencies are satisfied.
3. Implement the task completely, including tests and documentation updates.
4. Run the validation commands listed in the task.
5. Update README.md for any behavior, API, env var, or command changes.
6. Mark the checklist item as complete by changing [ ] to [x].
7. Add a completion note with date, branch, and commit hash.
8. Stop, or continue to the next task only if explicitly requested.

If blocked:

1. Leave the item unchecked.
2. Add a blocker note in the task's Dependencies/unknowns section.
3. Move to another unblocked task only if explicitly instructed.

## Universal Definition Of Done
Each completed task must satisfy all of the following:

- Code changes are committed and scoped to the task.
- Relevant tests were added or updated.
- Validation commands were executed successfully.
- README.md was updated where needed.
- This checklist item was checked off and annotated.

## Current State Review (Evidence-Based)

### Backend
- Backend logic is modular under `src/`, with `main.kujo` kept as the thin runtime entrypoint.
- Seed logic is data-driven and idempotent, so repeated starts do not duplicate demo rows.
Evidence: ../main.kujo#L82, ../main.kujo#L97, ../main.kujo#L112, ../main.kujo#L127, ../main.kujo#L142
- OPTIONS route handlers are registered through a shared helper.
Evidence: ../main.kujo#L562, ../main.kujo#L566, ../main.kujo#L570, ../main.kujo#L574
- Content-Type validation now uses an explicit comparison pattern with regression coverage.
Evidence: ../main.kujo#L273

### Frontend
- API root link is hardcoded instead of using env-derived base URL, which can mislead adopters in non-local environments.
Evidence: ../frontend/app/layout.tsx#L39
- Timestamp formatting helper is duplicated across two route files.
Evidence: ../frontend/app/page.tsx#L25, ../frontend/app/posts/[id]/page.tsx#L16
- Auth token is stored in localStorage for convenience; this is acceptable for demo-only use, but should be documented clearly with safer alternatives for production.
Evidence: ../frontend/app/page.tsx#L101, ../frontend/app/page.tsx#L160

### Testing And Tooling
- Backend regression tests and frontend lint/build checks now exist and run non-interactively.
- `make test`, `npm run lint`, and `npm run build` are CI-ready.
Evidence: ../tests/t0_04_api_smoke_suite.sh, ../tests/t4_03_contract_validation.sh, ../scripts/run-all-tests.sh, ../frontend/package.json#L5, ../frontend/package.json#L9

### Repository Hygiene
- Runtime SQLite files appear in repo root during execution, creating local clutter even if ignored.
Evidence: ../.gitignore#L1

## Priority Tiers

### Tier 0 - Immediate Foundation (High ROI, low complexity)

#### [x] T0-01: Replace unsafe contains negation in JSON Content-Type check
Category: Security, Reliability

Implementation expectations:
- Update request Content-Type logic to explicit truthy comparison pattern supported safely by runtime behavior.
- Add regression tests for valid/invalid Content-Type values.

Acceptance criteria:
- Requests with application/json pass.
- Requests with non-JSON Content-Type fail with 400.
- Behavior is deterministic across runtime versions.

Validation/testing expectations:
- Add and run automated tests for parse_body_json behavior.

Dependencies/unknowns:
- Confirm exact runtime-safe pattern for contains return type handling.

README updates required:
- Document strict Content-Type requirement.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T0-02: Make linting non-interactive and CI-ready
Category: DX, Quality

Implementation expectations:
- Initialize ESLint configuration for Next.js.
- Ensure npm run lint executes non-interactively.
- Add a root-level quality script strategy for future CI.

Acceptance criteria:
- npm run lint runs without prompts.
- Lint output is stable in local and CI environments.

Validation/testing expectations:
- Run npm run lint from frontend.

Dependencies/unknowns:
- Decide whether to keep lint config in frontend only or expose root orchestration script.

README updates required:
- Add quality commands section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T0-03: Move runtime artifacts into dedicated data and runtime paths
Category: Repo Hygiene, Architecture

Implementation expectations:
- Add dedicated data directory and set default DB path there.
- Keep root directory clean after first run.
- Preserve env override behavior.

Acceptance criteria:
- Default run creates database under dedicated runtime/data location.
- Root remains clean from generated artifacts.

Validation/testing expectations:
- Run API startup and verify generated files path.

Dependencies/unknowns:
- Decide final path naming (data/, var/, runtime/).

README updates required:
- Update default database path and cleanup notes.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T0-04: Add minimum automated API smoke tests
Category: Testing

Implementation expectations:
- Create a repeatable smoke suite that verifies health and full CRUD flow.
- Include unauthorized write tests when auth token is set.

Acceptance criteria:
- Smoke suite passes locally from clean state.
- Failures point clearly to endpoint regressions.

Validation/testing expectations:
- Add one command to run all smoke tests.

Dependencies/unknowns:
- Select test runner strategy (shell, JS, Kujo script, or mixed).

README updates required:
- Add test execution section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

### Tier 1 - Core Refactor For Reusability

#### [x] T1-01: Split backend into modules for config, db, validation, handlers, and routes
Category: Architecture, DX

Implementation expectations:
- Decompose main.kujo into focused files under src/.
- Keep public behavior unchanged.

Acceptance criteria:
- All existing endpoint behavior remains identical.
- New developers can locate concerns quickly by directory.

Validation/testing expectations:
- Run smoke tests and compare baseline endpoint responses.

Dependencies/unknowns:
- Confirm Kujo module resolution and packaging conventions for this repo.

README updates required:
- Update project layout section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T1-02: DRY seed setup with data-driven fixture list
Category: Code Cleanup, Maintainability

Implementation expectations:
- Replace repeated seed blocks with one helper and one fixture list.
- Keep idempotent seed behavior.

Acceptance criteria:
- Same seed rows are ensured without duplication.
- Logic is concise and extensible.

Validation/testing expectations:
- Add tests for idempotent seeding.

Dependencies/unknowns:
- None.

README updates required:
- Document fixture strategy if relevant.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T1-03: DRY OPTIONS handling via reusable route registration helper
Category: Code Cleanup, Maintainability

Implementation expectations:
- Register OPTIONS handlers through shared helper.
- Keep CORS behavior unchanged.

Acceptance criteria:
- OPTIONS works for all current routes.
- Route additions require one registration pattern.

Validation/testing expectations:
- Add OPTIONS tests for each endpoint family.

Dependencies/unknowns:
- None.

README updates required:
- Optional.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T1-04: Centralize shared frontend utilities
Category: Frontend DX, Maintainability

Implementation expectations:
- Move duplicate timestamp formatter into shared utility file.
- Replace hardcoded API root link with env-derived URL.

Acceptance criteria:
- No duplicate timestamp formatting logic remains.
- Topbar API link follows configured API base URL.

Validation/testing expectations:
- Build and route-level manual checks.

Dependencies/unknowns:
- Define behavior when API base URL is missing/invalid.

README updates required:
- Clarify frontend env variable usage and defaults.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

### Tier 2 - Security Hardening

#### [x] T2-01: Define explicit security mode for demo versus production usage
Category: Security, Documentation

Implementation expectations:
- Add explicit MODE or SECURITY_PROFILE env strategy.
- Make insecure demo defaults clearly intentional and visible.

Acceptance criteria:
- Developers can run demo mode quickly.
- Production profile guidance is explicit and enforceable.

Validation/testing expectations:
- Add tests for mode-specific behavior.

Dependencies/unknowns:
- Decide whether mode changes are runtime-only or compile-time.

README updates required:
- Add security profiles section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T2-02: Add rate limiting for write routes
Category: Security, Reliability

Implementation expectations:
- Add IP or token-based rate limiting to POST/PUT/PATCH/DELETE.
- Return clear 429 responses.

Acceptance criteria:
- Write abuse is throttled.
- Legitimate usage remains practical.

Validation/testing expectations:
- Add burst tests verifying throttle and recovery behavior.

Dependencies/unknowns:
- Choose memory-only or persistent limiter strategy.

README updates required:
- Document limits and override env vars.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T2-03: Replace static bearer token with extensible auth strategy
Category: Security, Extensibility

Implementation expectations:
- Introduce pluggable auth validation abstraction.
- Keep static token as one supported strategy for demos.

Acceptance criteria:
- Current bearer workflow still works.
- Alternative provider hook exists for future integrations.

Validation/testing expectations:
- Add auth strategy unit and integration tests.

Dependencies/unknowns:
- Decide strategy interface and config format.

README updates required:
- Add auth strategy section and examples.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T2-04: Add request correlation IDs and structured security logs
Category: Security, Observability

Implementation expectations:
- Generate or propagate request ID.
- Include request ID in responses and logs.
- Standardize error logging shape.

Acceptance criteria:
- Every request can be traced across logs.
- Sensitive values are never logged.

Validation/testing expectations:
- Add tests for request ID propagation.

Dependencies/unknowns:
- Decide logger output format.

README updates required:
- Add observability and troubleshooting section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

### Tier 3 - Feature Completeness For Universal Reuse

#### [x] T3-01: Add second resource and relationship example
Category: Features, Architecture

Implementation expectations:
- Introduce a second resource (for example projects or users).
- Demonstrate one-to-many or many-to-many relation.

Acceptance criteria:
- Relation queries are documented and tested.
- Frontend can browse or reference relation data.

Validation/testing expectations:
- Add endpoint and relation integrity tests.

Dependencies/unknowns:
- Choose resource that is broadly reusable.

README updates required:
- Add schema and endpoint docs.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T3-02: Add sorting and search support to list endpoint
Category: Features, DX

Implementation expectations:
- Support safe sort field, direction, and text query filters.
- Validate all query params strictly.

Acceptance criteria:
- Common listing use cases are supported.
- Invalid sort/query params return clear 400 errors.

Validation/testing expectations:
- Add tests for valid and invalid search/sort combinations.

Dependencies/unknowns:
- Define max query length and allowed sort fields.

README updates required:
- Update list endpoint docs and examples.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T3-03: Add cursor pagination option
Category: Features, Performance

Implementation expectations:
- Add cursor-based pagination while keeping offset mode for backward compatibility.
- Return next cursor token when applicable.

Acceptance criteria:
- Cursor mode works consistently under inserts/deletes.
- Offset mode remains functional.

Validation/testing expectations:
- Add pagination consistency tests.

Dependencies/unknowns:
- Decide cursor encoding format.

README updates required:
- Add cursor pagination examples.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T3-04: Add optimistic concurrency control
Category: Data Integrity, Reliability

Implementation expectations:
- Enforce If-Unmodified-Since or version token checks on updates.
- Return conflict responses for stale writes.

Acceptance criteria:
- Concurrent updates are detected reliably.
- Client receives actionable conflict details.

Validation/testing expectations:
- Add race condition tests for update conflicts.

Dependencies/unknowns:
- Decide version field strategy.

README updates required:
- Add concurrency section.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

### Tier 4 - Developer Experience And Distribution

#### [x] T4-01: Introduce root-level command orchestration
Category: DX, Onboarding

Implementation expectations:
- Add one root command each for run-api, run-frontend, test, lint.
- Ensure commands work from repo root.

Acceptance criteria:
- New developer can run setup and quality checks without directory switching.

Validation/testing expectations:
- Verify root commands on clean clone.

Dependencies/unknowns:
- Choose Makefile, npm workspace scripts, task runner, or shell scripts.

README updates required:
- Simplify quick start and command sections.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T4-02: Add CI pipeline for lint and tests
Category: DX, Quality

Implementation expectations:
- Add CI workflow to run lint and automated tests.
- Fail pull requests on quality gate failures.

Acceptance criteria:
- CI status accurately reflects repository health.

Validation/testing expectations:
- Validate workflow on branch and pull request events.

Dependencies/unknowns:
- Confirm CI environment for Kujo runtime availability.

README updates required:
- Add CI badge and contribution workflow.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

#### [x] T4-03: Publish API contract and examples
Category: Documentation, Integration

Implementation expectations:
- Add OpenAPI spec or equivalent contract artifact.
- Include request/response examples for all endpoints.

Acceptance criteria:
- Integrators can implement clients without reading source code.

Validation/testing expectations:
- Validate contract against live API responses.

Dependencies/unknowns:
- Choose contract tooling compatible with Kujo ecosystem.

README updates required:
- Add API contract location and usage guidance.

Completion note:
- Date: 2026-05-21
- Branch: main
- Commit: HEAD

## Backlog Parking Lot (Optional After Tier 4)

- Add soft delete and restore workflow.
- Add bulk operations with idempotency keys.
- Add role-based access control examples.
- Add data export/import tooling.
- Add frontend E2E suite with Playwright.

## Work Log
Add one line per completed task:

- YYYY-MM-DD | Task ID | Agent/Author | Branch | Commit | Summary
- 2026-05-21 | T0-01 | Copilot | main | HEAD | Replaced unsafe contains negation for Content-Type parsing and added regression test coverage.
- 2026-05-21 | T0-02 | Copilot | main | HEAD | Added explicit ESLint config/dependencies and a root quality-check script for non-interactive linting.
- 2026-05-21 | T0-03 | Copilot | main | HEAD | Moved default DB path to data/ and added a runtime artifact placement regression test.
- 2026-05-21 | T0-04 | Copilot | main | HEAD | Added repeatable API smoke suite (CRUD + auth checks) and a single-command runner.
- 2026-05-21 | T1-01 | Copilot | main | HEAD | Split backend into src modules and kept root entrypoint as a thin bootstrap.
- 2026-05-21 | T1-02 | Copilot | main | HEAD | Replaced repeated seed blocks with a fixture-driven loop and added an idempotent seed regression test.
- 2026-05-21 | T1-03 | Copilot | main | HEAD | Replaced duplicated OPTIONS routes with a shared path registration loop and added OPTIONS route tests.
- 2026-05-21 | T1-04 | Copilot | main | HEAD | Centralized timestamp formatting and API base config, and removed hardcoded API root URL in layout.
- 2026-05-21 | T2-01 | Copilot | main | HEAD | Added explicit demo/production security profiles with production startup enforcement and mode-specific regression tests.
- 2026-05-21 | T2-02 | Copilot | main | HEAD | Added configurable write-route rate limiting with Retry-After semantics and burst/recovery regression tests.
- 2026-05-21 | T2-03 | Copilot | main | HEAD | Added pluggable write-auth strategy support (static bearer and header value) with integration coverage for each strategy.
- 2026-05-21 | T2-04 | Copilot | main | HEAD | Added request correlation IDs plus structured request/security logs and propagation tests.
- 2026-05-21 | T3-01 | Copilot | main | HEAD | Added projects resource with item relationships, relation endpoints, and frontend project-aware item workflows.
- 2026-05-21 | T3-02 | Copilot | main | HEAD | Added validated sort/search list query support (`sort_by`, `sort_dir`, `q`) with regression tests for valid and invalid combinations.
- 2026-05-21 | T3-03 | Copilot | main | HEAD | Added cursor-based pagination (`cursor`, `next_cursor`) alongside existing offset mode with insert-consistency regression coverage.
- 2026-05-21 | T3-04 | Copilot | main | HEAD | Enforced optimistic concurrency preconditions on item update/delete paths with 428/409 conflict semantics and regression tests.
- 2026-05-21 | T4-01 | Copilot | main | HEAD | Added root Makefile orchestration for run-api/run-frontend/lint/test and a full regression runner script.
- 2026-05-21 | T4-02 | Copilot | main | HEAD | Added GitHub Actions CI workflow for frontend lint/build plus backend regression tests with Kujo runtime setup.
- 2026-05-21 | T4-03 | Copilot | main | HEAD | Published OpenAPI contract + endpoint examples and added a live contract-validation regression script.
