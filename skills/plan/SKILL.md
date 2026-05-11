---
name: plan
description: Produce a tight one-pager `plan.md` and a Given-When-Then checklist `tasks.md` for an upcoming task. Use this whenever the user is about to start a non-trivial change — a feature, multi-file fix, refactor — before any code is written. Even if the user just says "let's start", produce a plan first; the develop skill consumes these documents. The plan is for any coding agent (Claude, Codex, Gemini, a teammate) to pick up and execute, so it must stand on its own.
---

# flow:plan — Authoring plan.md and tasks.md

A flow plan is **a one-pager that explains the approach, not the code**. Inspired by Amazon's one-pager / six-pager: short, explicit, and self-contained. The reader should finish in five minutes and know what is going to be built and how.

## Output files

Both written under `<worktree>/.planning/<date>-<task>/`:

- **`plan.md`** — approach, scope, architecture decisions, rollout. ~500 lines max for the whole thing (including any phase sub-plans). If it grows beyond that, split into `plan-phase-1.md`, `plan-phase-2.md` and let `plan.md` become a short index.
- **`tasks.md`** — Given-When-Then checklist, the single source of truth for progress during develop.

Both files are **English** (any coding agent picks them up). Add a `## Korean summary (요약)` at the bottom of `plan.md` if the user wants to skim it quickly.

## plan.md structure

```markdown
# Plan — <task name>

## Goal
One paragraph. What does success look like for the user? Avoid mentioning files.

## Non-goals
Bulleted. What is explicitly out of scope. This list is more important than people
think — it prevents scope creep during develop.

## Approach
The shape of the solution in 3-7 bullets. Talk about *what changes* and *why this
shape and not another*. No code blocks. If you're tempted to write code, write a
test signature in `tasks.md` instead.

## Phases (only if size = L)
- Phase 1: <one line>
- Phase 2: <one line>
Each phase gets its own `plan-phase-N.md` if it has more than ~10 tasks.

## Risks & open questions
Things that could derail the plan. Each entry: the risk, the mitigation, who
decides.

## Rollout
How does this ship? Feature flag? Migration? Backwards-compat shim? If the answer
is "just merge", say so explicitly.

## Korean summary (요약)
3-5 bullets, 사용자 빠른 확인용.
```

**Things to leave out of plan.md:**

- Detailed code. That goes in `tasks.md` (as test signatures) and in the actual implementation.
- Step-by-step instructions. Those are `tasks.md`'s job.
- Restating what's in `research.md`. Reference it, don't copy it.

## tasks.md structure

Given-When-Then checklist. Each task is **a behavior, not a step**. The develop skill will treat each unchecked item as a TDD cycle (write test → implement → commit).

```markdown
# Tasks — <task name>

## Phase 1 (optional grouping)

- [ ] **Given** a user without a Google account linked,
      **when** they click "Sign in with Google",
      **then** they are redirected to Google's OAuth consent screen.

- [ ] **Given** Google returns a valid auth code,
      **when** the callback handler processes it,
      **then** a session token is issued and the user lands on `/dashboard`.

- [ ] **Given** Google returns an error or the user denies consent,
      **when** the callback handler processes it,
      **then** the user sees a non-technical error message and stays on `/login`.

## Non-TDD tasks

- [ ] Update `.env.example` with `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.
- [ ] Add Google OAuth library to `package.json` (no test — dep bump).
```

**Rules:**

- One behavior per checkbox. Don't bundle.
- Mention "non-TDD" explicitly for config/dep/rename tasks — see `../../references/tdd-policy.md` for which tasks skip TDD.
- The order roughly follows implementation order, but the develop skill picks the next unchecked task and decides if dependencies require reordering.
- Sub-tasks are allowed (nested checkboxes) when a single behavior splits naturally into validation + happy-path + error-path. Keep nesting one level deep.

## Workflow

1. **Read** `meta.md` and `research.md` (if it exists). Don't restart research — build on it.
2. **Read** the user's task goal in their words. If anything is ambiguous, ask one or two focused questions. Don't ask 10 questions; the plan-review step will surface anything you miss.
3. **Draft** plan.md (Approach + Non-goals first, then Goal, Risks, Rollout). It is normal to write Approach before Goal — clarifying the approach often sharpens the goal.
4. **Draft** tasks.md. Each task should look like something you could write a failing test for, except the explicit "non-TDD" ones.
5. **Show** both files to the user for a quick review. Make any obvious edits before invoking `flow:plan-review` (if size warrants).

## Sizing decisions

- **Size S** — plan.md can be 20-50 lines. tasks.md may have just 1-3 checkboxes. Skip phases. Skip `flow:plan-review`.
- **Size M** — plan.md ~100-300 lines. tasks.md ~5-15 checkboxes. Plan-review optional, default to yes if any of: external API integration, security-sensitive code, public surface area.
- **Size L** — plan.md ~300-500 lines + per-phase files. tasks.md scoped by phase. Plan-review mandatory.

## Reference

- Directory layout: `../../references/directory-structure.md`
- TDD policy (what gets tests, what doesn't): `../../references/tdd-policy.md`
