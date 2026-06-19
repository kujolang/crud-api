# CRUD API Next-Session Hardening Plan

## Current Assessment

`crud-api` is a strong Kujo showcase and reusable starter, but it should not be described as universally enterprise production-ready yet. It now has modular backend code, SQLite persistence, idempotent seed data, validation, auth strategies, write rate limiting, request IDs, structured logs, optimistic concurrency, OpenAPI docs, a Next.js playground, regression tests, performance and DR drills, and clearer production guardrails.

The next phase should focus on broader real-world integration patterns, stronger operational controls, and presentation polish that helps new users understand both the app and Kujo itself quickly.

## Completed In This Review

- Kept `main.kujo` as the intentional public bootstrap while confirming runtime implementation belongs under `src/`.
- Added production auth-secret length enforcement.
- Made `X-Forwarded-For` rate-limit identity opt-in through `KUJO_CRUD_TRUST_PROXY_HEADERS`.
- Removed raw authorization-header values from rate-limit bucket keys.
- Added SQLite indexes for common item filter and sort paths.
- Converted duplicate project names from generic database failure to explicit `409`.
- Updated README, OpenAPI, and copyable examples for the new behavior.
- Added regression coverage for production secret length, proxy-header trust behavior, and duplicate project conflicts.

## Recommended Next Work

### P0 - Product Presentation

#### [ ] N1: Add a Kujo showcase tour section to the README
Explain which parts of the repo demonstrate Kujo strengths: server entrypoint, modules, SQLite access, HTTP routes, validation, and tests. Keep it technical and practical, not marketing-only.

Acceptance criteria:
- A new user can identify the five best Kujo learning examples in under two minutes.
- README links directly to the source files that demonstrate each concept.
- The language still says showcase/starter, not production-certified platform.

#### [ ] N2: Add architecture notes
Create a short architecture document with route flow, module responsibilities, data model, auth flow, and request lifecycle.

Acceptance criteria:
- Includes one diagram.
- Explains why `main.kujo` remains at the root.
- Documents the boundary between backend, frontend, tests, and generated runtime data.

### P1 - API Robustness

#### [ ] N3: Add project update and delete endpoints
Projects can currently be created and read, but not updated or deleted. Add `PUT /projects/:id`, `PATCH /projects/:id`, and a safe delete policy.

Acceptance criteria:
- Conflict handling for duplicate names.
- Safe behavior when projects have items.
- OpenAPI, README, examples, frontend, and tests updated.

#### [ ] N4: Add bulk item operations with idempotency keys
Add a practical example of robust API design for batch creates or status updates.

Acceptance criteria:
- Idempotency key prevents duplicate processing.
- Partial failure response is deterministic.
- Tests cover replay and mixed-validity batches.

### P2 - Security And Operations

#### [ ] N5: Add configurable trusted origins list
Move beyond a single CORS origin string and support a comma-separated allowlist.

Acceptance criteria:
- Production still rejects wildcard.
- Requests from allowed origins receive the matching origin.
- Requests from disallowed origins do not receive credential-capable CORS headers.

#### [ ] N6: Add backup/export commands or scripts
The DR drill proves restore behavior, but users need copyable operational commands.

Acceptance criteria:
- Add scripts for SQLite backup/export and restore validation.
- Document when to stop the server versus using online backup.
- Add tests that run without external services.

### P3 - Frontend Showcase

#### [ ] N7: Add project management to the playground
The frontend currently focuses on item workflows. Add project create/edit views so relationship behavior is visible without curl.

Acceptance criteria:
- Users can create projects and assign items from the UI.
- Duplicate project conflict errors are displayed clearly.
- Frontend lint and build pass.

#### [ ] N8: Add Playwright smoke coverage
Add one browser-level flow that verifies the playground can load projects, create an item, edit it, and see concurrency errors.

Acceptance criteria:
- Runs headlessly in CI or is documented as an optional local gate.
- Uses deterministic test data and isolated API DB path.

## Validation Commands For Future Sessions

```bash
make test KUJO_BIN=/path/to/kujo
KUJO_BIN=/path/to/kujo ./scripts/run-smoke-tests.sh
./scripts/quality-check.sh
cd frontend && npm run build
```

## Root File Hygiene Notes

- Keep `main.kujo` at the root as the stable bootstrap entrypoint.
- Keep source implementation under `src/`.
- Keep generated runtime SQLite files under `data/`; they are ignored.
- Keep smoke/test artifacts under `.tmp/`; they are ignored.
- Do not move `.github`, `Makefile`, `README.md`, `SECURITY.md`, `RELEASE.md`, or `CONTRIBUTING.md` into `src/`; they are repository-level artifacts.
