# Commit Conventions

## Format

[Conventional Commits](https://www.conventionalcommits.org/) — `<type>(<scope>)?: <subject>`.

Common types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `perf`, `build`, `ci`.

Scope is optional but useful when the repo has clear modules (`feat(auth):`, `fix(api):`).

## Atomic policy

Each commit captures **one logically complete unit of change** — typically one checkbox in `tasks.md` (or one passing test in TDD flow). Rules:

- **One concern per commit.** Don't bundle "fix the bug + rename a variable + add a test for something else."
- **Compiles and passes the relevant tests at every commit.** Bisectability matters.
- **Subject ≤ 72 chars**, imperative mood ("add", not "added").
- **Body** when the *why* is non-obvious. Skip body for trivial changes.

## TDD-flow commit pattern

When following TDD, commits typically come in pairs:

```
test(auth): add failing test for Google OAuth callback redirect
feat(auth): implement Google OAuth callback redirect
```

You can also collapse the pair into a single commit if the test and impl together represent one atomic unit and the failing-test step was instantaneous. Prefer the pair when the change is non-trivial — it makes the spec-first intent visible in history.

## When NOT to commit

- WIP code that doesn't compile (use `git stash` or a worktree instead)
- Generated artifacts (lockfile bumps are OK, build outputs aren't)
- Secrets / `.env` files
- Mixed concerns that can't be cleanly described in one subject line — split first

## Branch naming

Match the task type to the branch prefix:

- `feature/<task-name>` — new user-facing capability
- `fix/<task-name>` — bug fix
- `chore/<task-name>` — tooling, deps, build, config
- `refactor/<task-name>` — internal restructuring with no behavior change
- `docs/<task-name>` — docs-only

`<task-name>` is kebab-case and matches the `.planning/yyyy-mm-dd-<task-name>/` directory.

## Sign-off

This plugin does not require Co-Authored-By tags on commits. Individual projects may have their own conventions — defer to project CLAUDE.md or recent `git log` patterns.
