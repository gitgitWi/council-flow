---
name: plan
description: Produce a tight one-pager `plan.md` and a Given-When-Then checklist `tasks.md` for an upcoming task. Use this whenever the user is about to start a non-trivial change — a feature, multi-file fix, refactor — before any code is written. Even if the user just says "let's start", produce a plan first; the develop skill consumes these documents. The plan is for any coding agent (Claude, Codex, Gemini, a teammate) to pick up and execute, so it must stand on its own.
---

# flow:plan — Authoring plan.md and tasks.md

A flow plan is **a one-pager that explains the approach, not the code**. Inspired by Amazon's one-pager / six-pager: short, explicit, and self-contained. The reader should finish in five minutes and know what is going to be built and how.

## Prep precondition check (run first, every invocation)

Before writing anything, verify the worktree + branch + planning directory exist. If not, the user has skipped `flow:prep` and `plan.md` would land in the wrong place.

```bash
# 1. Are we in a flow worktree? (heuristic: parent dir name ends in .worktrees)
WT_PATH="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo"; exit 1; }
WT_PARENT="$(basename "$(dirname "$WT_PATH")")"
case "$WT_PARENT" in *.worktrees) IN_WORKTREE=1;; *) IN_WORKTREE=0;; esac

# 2. Are we on a typed branch (feature/* | fix/* | chore/* | refactor/* | docs/*)?
BRANCH="$(git branch --show-current)"
case "$BRANCH" in feature/*|fix/*|chore/*|refactor/*|docs/*) ON_TASK_BRANCH=1;; *) ON_TASK_BRANCH=0;; esac

# 3. Is there a .planning/<date>-<task>/meta.md to write into?
META="$(ls -1 .planning/*/meta.md 2>/dev/null | head -n1)"
[[ -n "$META" ]] && HAS_PLANNING=1 || HAS_PLANNING=0
```

Decision matrix:

| In worktree | On task branch | Has `.planning/.../meta.md` | Action |
|---|---|---|---|
| yes | yes | yes | Proceed. This is the normal post-prep state. |
| no | no | no | **Stop.** Tell the user prep was skipped and ask: (a) run `flow:prep` now (recommended), (b) proceed in-place on the current branch (only sensible for size S, and you must still create `.planning/<date>-<task>/meta.md` manually before writing the plan), (c) abort. |
| any | yes | no | Branch exists but planning dir is missing. Ask the user whether the prior planning was cleaned up (rare) or this is a new task on a reused branch (more common). Create `.planning/<date>-<task>/meta.md` before writing the plan either way. |
| any | any | yes | Planning dir exists. Proceed and write into the existing dir — do not create a second one for the same date+task. |

Do not silently fix the situation. The decision affects which branch commits land on and where artifacts get audited; the user should make it.

If the user picks "proceed in-place" without prep, write the size into the manually-created `meta.md` so downstream skills (especially `flow:develop`) see consistent metadata.

## Output files

Both written under `<worktree>/.planning/<date>-<task>/`:

- **`plan.md`** — approach, scope, architecture decisions, rollout. ~500 lines max for the whole thing (including any phase sub-plans). If it grows beyond that, split into `plan-phase-1.md`, `plan-phase-2.md` and let `plan.md` become a short index.
- **`tasks.md`** — Given-When-Then checklist, the single source of truth for progress during develop.

Both files are **English** (any coding agent picks them up). Add a `## Korean summary (요약)` at the bottom of `plan.md` if the user wants to skim it quickly.

## Frontmatter (every generated document)

Both `plan.md` and `tasks.md` open with a YAML frontmatter block. The schema and per-type fields are in `../../references/frontmatter.md`; mirror `task`, `task_date`, and `size` from `meta.md`. Do not skip this — `frontmatter.md` exists so future agents can locate documents by `type: plan` / `task: <name>` without reading bodies.

`plan.md`:

```yaml
---
title: "Plan — <task name>"
type: plan
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: draft         # bump to "active" once the user signs off, "done" after deploy
size: <S|M|L>
parent: ./meta.md
related:
  - ./tasks.md (GWT checklist)
  - ./research.md (if exists — pre-plan investigation)
version: 1
plan_review_run: false
---
```

`tasks.md`:

```yaml
---
title: "Tasks — <task name>"
type: tasks
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: draft         # bump to "active" once develop starts, "done" after all boxes checked
size: <S|M|L>
parent: ./plan.md
related:
  - ./meta.md
version: 1
total_tasks: <count at authoring time>
---
```

For size-L plans broken into phase files (`plan-phase-1.md`, …): each phase file uses `type: plan-phase` with a `phase: <N>` field and `parent: ./plan.md` (the index). See `frontmatter.md` for the full per-type spec.

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

Given-When-Then **checkbox list**. Each task is **a behavior, not a step**. The develop skill will treat each unchecked item as a TDD cycle (write test → implement → commit).

> **Format is non-negotiable: `- [ ]` bullets, never a markdown table.**
> "Checklist" in this plugin literally means "list of `- [ ]` items." A table cell cannot be checked off, cannot be appended to mid-task, and breaks `flow:develop`, which reads progress by scanning for `[ ]` vs `[x]`. The same rule applies to *any* file whose role is a checklist — audit checklists, status checklists, verification checklists. If you reach for a table to show "item / status / note," stop and use:
>
> ```markdown
> - [ ] **Item** — note. Status: ❌
> - [x] **Item** — note. Status: ✅
> ```
>
> Tables are fine for *inventories* or *comparison matrices* (read-only reference data). They are wrong for anything called a checklist.

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

- **Every item is a `- [ ]` checkbox.** No markdown tables, no plain bullets, no numbered lists. If `flow:develop` can't toggle it from `[ ]` to `[x]`, it doesn't belong here.
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
- Frontmatter schema: `../../references/frontmatter.md`
- TDD policy (what gets tests, what doesn't): `../../references/tdd-policy.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
