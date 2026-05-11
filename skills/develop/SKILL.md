---
name: develop
description: Execute the implementation phase of the flow workflow — read `tasks.md`, pick the next unchecked behavior, write a failing test (when TDD applies), implement until green, commit atomically with conventional commits, and check the box. Use this for any actual code change in a flow task, whether or not a plan exists. Even when the user says "just implement this", invoke develop so the atomic-commit and TDD discipline applies. The skill resumes cleanly from interrupted sessions because `tasks.md` is the source of truth for progress.
---

# flow:develop — Implementation with TDD + atomic commits

Develop turns `tasks.md` into code, one checkbox at a time. Each unchecked behavior becomes a small loop: (write test → implement → green → commit → check the box). The skill is interruption-safe: re-entering finds the next unchecked item and resumes.

## Preconditions

- You are inside the task's worktree (`git rev-parse --show-toplevel` matches the worktree path).
- `<worktree>/.planning/<date>-<task>/tasks.md` exists.
- (Recommended) `plan.md` also exists. Develop can run without a plan if the user explicitly chose to skip planning, but only for size S.

If `tasks.md` does not exist and the user is asking for an implementation, run `flow:plan` first — even a 5-line `tasks.md` is better than freestyling.

## The core loop

For each unchecked item in `tasks.md`, top to bottom:

1. **Read the task line.** Re-parse the Given-When-Then. If it has nested sub-tasks, handle them in order.
2. **Decide: TDD or not?** Apply the rules from `../../references/tdd-policy.md`. If unsure, default to TDD.
3. **(TDD path) Write the failing test.** The test name should mirror the task's Given-When-Then phrasing. Run the test, confirm it fails for the right reason (not a syntax error or missing import).
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

For pure frontend implementation tasks — building a component, applying styling, wiring up a form — the user may prefer to delegate to Gemini. Defaults:

- **Delegate to Gemini** when: simple component, styling-heavy, follows existing patterns, no complex state or integration logic.
- **Keep on Claude** when: state machines, data fetching, error handling, accessibility, integration with backend, anything cross-cutting.

When in doubt, ask the user once at the start of develop ("Frontend portion — Claude or Gemini?") and remember the answer for this session. Do not ask before every task.

Gemini invocation:

```bash
gemini --model gemini-3.1-pro --yolo --skip-trust --prompt "$(cat <<'PROMPT'
You are implementing a frontend task. The plan and tasks live at:
- <abs-path>/.planning/<date>-<task>/plan.md
- <abs-path>/.planning/<date>-<task>/tasks.md

Implement only the next unchecked task: "<paste the task GWT verbatim>".
Follow the existing component patterns under <abs-path>/src/...
Write the Vitest test first.
Output the changed files as paths + full file content; I will apply them.
PROMPT
)" > /tmp/gemini-impl.txt
```

Then read the output, apply the changes via Edit/Write, run the test yourself, and commit. The Claude session retains responsibility for the test passing and the commit.

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
