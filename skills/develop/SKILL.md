---
name: develop
description: Execute the implementation phase of the flow workflow — read `tasks.md`, pick the next unchecked behavior, write a failing test (when TDD applies), implement until green, commit atomically with conventional commits, and check the box. Use this for any actual code change in a flow task, whether or not a plan exists. Even when the user says "just implement this", invoke develop so the atomic-commit and TDD discipline applies. The skill resumes cleanly from interrupted sessions because `tasks.md` is the source of truth for progress.
---

# flow:develop — Implementation with TDD + atomic commits

Develop turns `tasks.md` into code, one checkbox at a time. Each unchecked behavior becomes a small loop: (write test → implement → green → commit → check the box). The skill is interruption-safe: re-entering finds the next unchecked item and resumes.

## Preconditions

- You are inside the task's worktree (`git rev-parse --show-toplevel` matches the worktree path).
- `<worktree>/.flow/tasks/<date>-<task>/tasks.md` exists.
- (Recommended) `plan.md` also exists. Develop can run without a plan if the user explicitly chose to skip planning, but only for size S.

If `tasks.md` does not exist and the user is asking for an implementation, get one first — even a 5-line `tasks.md` is better than freestyling. For a **fast-lane / size-S entry** (`flow:quick` green route, or a size-S `flow:kickoff`), that minimal `tasks.md` is written by the entry skill before it hands off here — so a 3-line checklist with no `plan.md` is a valid state to run in, not a reason to stop. Only bounce to `flow:plan` when there is genuinely nothing to execute and no entry skill produced a list.

> Trigger note: develop's description says "even when the user says 'just implement this', invoke develop" — but when the user is **asserting the task is trivial** and no `tasks.md` exists yet, `flow:quick` is the entry point. It classifies green/yellow/red, writes the minimal `tasks.md` on green, and then calls develop. Don't skip that guardrail for a "just do it / quick fix" phrasing.

### Prep precondition check (run first, every invocation)

Before touching code, verify the workspace is the one prep would have created. If not, commits will land on the wrong branch.

```bash
# Worktree + branch + task dir presence
WT_PATH="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo"; exit 1; }
WT_PARENT="$(basename "$(dirname "$WT_PATH")")"
case "$WT_PARENT" in *.worktrees) IN_WORKTREE=1;; *) IN_WORKTREE=0;; esac
BRANCH="$(git branch --show-current)"
case "$BRANCH" in feature/*|fix/*|chore/*|refactor/*|docs/*) ON_TASK_BRANCH=1;; *) ON_TASK_BRANCH=0;; esac
TASKS="$(ls -1 .flow/tasks/*/tasks.md 2>/dev/null | head -n1)"
```

Decision matrix:

| Worktree | Task branch | `tasks.md` | Action |
|---|---|---|---|
| yes | yes | yes | Proceed with the core loop. |
| any | any | no | **Stop.** Run `flow:plan` first — develop has nothing to execute without `tasks.md`. |
| no | no | yes | Suspicious: there is a tasks file but no isolated worktree/branch. Tell the user, then ask: (a) run `flow:kickoff` setup to move the work into a worktree (preferred — preserves the in-progress branch by `--force` only with explicit consent), (b) continue in-place on the current branch (commits land here — confirm the user accepts that). Do not auto-decide. |
| no | yes | yes | On a task branch but not in a worktree. Usually fine (the user just opened the branch directly without prep). Confirm with the user once at the start of the session, then continue. Future commits land on this branch. |

Special case — **uncommitted changes on a non-task branch (e.g., `main`)**: stop immediately. Do not commit on `main`. Offer to stash + run `flow:kickoff` setup to move the work into a fresh worktree.

## The core loop

For each unchecked item in `tasks.md`, top to bottom:

1. **Read the task line.** Parse the one-line behavior and its pseudo-code test or Mermaid diagram. If it has nested sub-tasks, handle them in order.
2. **Decide: TDD or not?** Apply the rules from `../../references/tdd-policy.md`. If unsure, default to TDD.
3. **(TDD path) Write the failing test.** Turn the task's pseudo-code test (or the behavior the diagram describes) into a real test; the test name should mirror the behavior statement. Run it, confirm it fails for the right reason (not a syntax error or missing import).
4. **Implement** the minimum code to make the test pass. Resist refactoring on the same commit — that comes later if it's worth doing.
5. **Run the test.** Confirm green. Run the broader test suite to make sure nothing else broke.
6. **Commit** atomically with a conventional-commit message. See `../../references/commit-conventions.md`. For TDD pairs, you may either commit test and impl separately (two commits) or together (one commit). Prefer two commits when the change is non-trivial — the failing-test step is informative in history.
7. **Update `tasks.md`** — check the box. Save the file. This must happen *after* the commit, so a partial work-in-progress doesn't show as completed if the session is interrupted.
8. **Repeat** until tasks.md is fully checked.

## Resumption protocol

When develop is invoked and `tasks.md` already has some checked items:

1. Read `tasks.md` start-to-finish.
2. Run `git status` and `git log --oneline -n 10`.
3. If there are uncommitted changes, **stop and ask the user**. There are a few possibilities:
   - Mid-implementation of the next task (continue from where they left off)
   - Abandoned work (offer to stash or discard)
   - Out-of-scope edits that snuck in (offer to commit separately or stash)
4. Resume from the first unchecked item.

Never auto-discard uncommitted changes. Always ask first.

## Frontend delegation (optional)

For pure frontend implementation tasks — building a component, applying styling, wiring up a form — you can delegate to the bundled `flow:developer` (Sonnet) instead of building on the frontier orchestrator. For a genuinely different model family, hand the task to an external agent (e.g. Antigravity, or codex-plugin-cc's `codex:codex-rescue`) — the flow agent does not shell out to model CLIs itself.

- **Delegate** when: simple component, styling-heavy, follows existing patterns, no complex state or integration logic.
- **Keep on the frontier orchestrator** when: state machines, data fetching, error handling, accessibility, backend integration, anything cross-cutting.

Whichever runs it, the flow session keeps responsibility: write the Vitest test first, apply/verify the changes, run the test yourself, and make the atomic commit.

## Web Frontend test stack (default)

If the worktree looks like a web frontend project (Vite/Next.js, React, etc.):

- **Unit/integration**: Vitest + React Testing Library. Mock HTTP at the boundary with **MSW**. Use `vi.mock` only for things you don't own (file system, timers, third-party modules).
- **E2E**: Playwright. Add E2E tests for the *critical user journey* only — usually once after the happy path is fully implemented, not per-task. Don't write Playwright tests for every checkbox.

For other stacks (backend Node, Python, Go), use whatever the repo already uses. Don't introduce a new test framework — that's a separate task.

## What NOT to do

- **Don't refactor on the same commit as a behavior change.** Either pure refactor (no behavior change) or pure behavior change. Mixing them makes review and bisect harder.
- **Don't skip the test step just because it feels obvious.** "Trivially correct" code is exactly the kind that hides subtle bugs.
- **Don't update `tasks.md` before committing.** Commit first, then check the box.
- **Don't expand scope mid-task.** If you notice something else that should change, add it as a new line in `tasks.md` and keep moving.

## Reference

- TDD policy: `../../references/tdd-policy.md`
- Commit conventions: `../../references/commit-conventions.md`
- Multi-LLM invocation: `../../references/multi-llm.md`
- Model registry: `../../references/models.md`
- Doc style (Simplified Technical English, lists over tables): `../../references/doc-style.md`
