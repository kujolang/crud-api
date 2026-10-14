# Changelog

## [1.0.1] - 2026-10-14

- Harden authentication secrets, proxy trust, CORS and typed environment parsing; enforce conflict and database integrity checks. Authentication secrets now require at least 16 characters by default; proxy trust defaults to false.

- Update Next.js to 15.5.28, PostCSS to 8.5.30 and Sharp to 0.35.5. Use ESLint Next config 14.2.35 with glob 10.5.0 because newer lint plugins depend on unpatched braces; retain core-web-vitals rules and verify lint/build with the Next.js 15 application. The locked dependency audit has zero findings.
