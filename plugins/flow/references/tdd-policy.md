# TDD Policy

The default for code changes is **test-first**: write a failing test that expresses the desired behavior, then implement until it passes. This makes the spec visible in the test, prevents over-implementation, and keeps the commit history coherent (test + impl pairs).

## When TDD applies

- Any change to **business logic** (parsing, validation, state transitions, calculations)
- New **user-facing features** (the test encodes the user behavior)
- **Bug fixes** (write a test that reproduces the bug first — it locks the regression in)
- **API changes** (request/response shape, return types, error handling)

## When TDD does NOT apply

Skip TDD for these — but say so explicitly in `tasks.md`:

- **Config changes** — `.env`, `tsconfig.json`, `vite.config.ts`, ESLint rules
- **Dependency bumps** — `package.json` version updates (let existing tests verify)
- **Pure renames / refactors** — no behavior change; existing tests are the safety net
- **Docs-only edits** — Markdown, comments, JSDoc
- **Visual-only styling** — pure CSS, design tweaks (E2E or visual regression covers this, not unit tests)
- **Throwaway scripts** — one-shot data migrations, ad-hoc CLIs

If you're unsure whether to TDD: write the test. It's cheap insurance and forces clarity.

## Test stack (Web Frontend default)

Pre-implementation:
- **Vitest + React Testing Library** — unit and integration tests focused on user behavior, not implementation detail
- **MSW** (Mock Service Worker) — network mocks at the HTTP boundary
- **`vi.mock`** — only for non-HTTP dependencies (file system, timers, modules you don't own)

Post-implementation (after the main happy path is green):
- **Playwright** — end-to-end tests for the critical user journeys

## Test-writing style

- **Describe by behavior**, not by function name. `it('redirects to /dashboard after Google login')` beats `it('handleAuthCallback works')`.
- **Given / When / Then** in arrange-act-assert. Mirror the `tasks.md` checklist phrasing — the test should make the requirement obvious.
- **One assertion per concept.** A test that asserts five unrelated things obscures what it's locking down.
- **Don't test the framework.** Skip "renders without crashing" — it's noise.

## Coverage expectation

No hard percentage target. The right question is: *if this test passed but the feature was broken, what would the user notice?* If the answer is "nothing critical," the test is weak — rewrite it to cover the user-facing concern.

## How the develop skill applies this

`flow:develop` reads `tasks.md`, picks the next unchecked item, decides whether TDD applies (using the rules above), writes the test if it does, implements until green, commits atomically, then checks the box. Loops until tasks.md is fully checked.
