---
name: kickoff
description: Turn a rough task idea into a structured kickoff brief before any worktree, research, or code — capturing GOAL, background, the user's own hypothesis, explicit acceptance criteria + verification method, scope boundary, and the standard working rules (worktree, issue-first, atomic commits, PR conventions). Use this as the front door of the flow workflow whenever the user describes a new feature, bug fix, chore, refactor, or research task — even a one-line "fix X" or "debug Y". It is what every session-starting prompt should have been: it forces the fields that are chronically missing (how do we know it's done? how do we verify? what is out of scope?) so develop does not drift. Hands off to flow:prep. Also fires on "frame this task", "write the brief", "세션 시작", "이거 작업 시작하자".
---

# flow:kickoff — Task framing brief

You are turning a rough task description into a **kickoff brief**: a tight, self-contained statement of what to build, how we will know it is done, and the rules of engagement. This is the front door of the `flow` workflow. It runs *before* `flow:prep` and produces `brief.md`, which seeds `prepare.md`'s goal and (by default) a GitHub Issue.

This skill is the codified form of the prompt template the user converged on across dozens of real sessions. Its job is to make every session start as strong as the user's *best* sessions — and to fill the fields the user's *weaker* sessions silently dropped.

## Why this exists

A review of real session-starting prompts found that ~1/3 of sessions stalled, looped, or needed corrective follow-ups, and the causes clustered tightly:

- **No acceptance criteria or verification method** (the single most common gap). A GOAL stated the intent but never the measurable "done" signal, nor *how* it would be checked (simulator? real device? test? screenshot?).
- **Vague scope verbs** — "점검", "파악해줘", "검토" — with no in/out boundary, leading to bikeshedding and scope creep.
- **Bug reports with a symptom but no reproduction** or no error/response payload.
- **Multi-goal prompts with no prioritization**, or a second larger goal that only surfaced mid-session.
- **Prompts sent truncated** because they were typed live in the terminal.

The brief format below closes each of these by construction.

## Inputs to resolve (ask only what you cannot infer)

Read the conversation and any `<ide_selection>` / attached files first. Ask the user **only** for fields you genuinely cannot infer. Prefer one consolidated question over many round-trips. The non-negotiable fields — the ones the review showed are usually missing — are marked **MUST**.

- **Category** — one of: `Feature` · `Fix` · `Debug & Fix` · `Refactor` · `Chore` · `Research` · `Research & Plan` · `UI Fix` · `Question`. Infer from the verb; this drives the size estimate and which downstream steps run.
- **Title** — short imperative phrase; becomes the brief heading, the branch name suffix, and the Issue title.
- **GOAL (MUST)** — the desired end state written as an *outcome*, not a task. Prefer "X가 정상적으로 보인다 / Y로 통일된다" over "X를 고친다". One to three bullets.
- **Acceptance criteria + verification (MUST)** — how we will *know* the goal is met, and *how* it will be checked. Be concrete: "Android Emulator + iOS Simulator both show the in-app browser", "the failing build script exits 0", "unit test covers the 400 branch". If the user has not stated this, **ask** — do not invent a criterion and proceed.
- **Scope boundary (MUST)** — what is explicitly *out* of scope. Even one line ("Windows Electron untouched", "extension only, web already works") prevents the most common derailment. For "review/check/audit"-type tasks this is mandatory; "점검" without a boundary is the highest-risk prompt shape.
- **Background** — links to related PRs/Issues, what was already tried, relevant file paths (use exact paths or `@`-mentions; abbreviated paths cost a clarification turn). For bugs, **reproduction steps** and any **error / response payload** verbatim.
- **Hypothesis (수정 방향)** — the user's own guess at cause/approach, *explicitly framed as a guess* so Claude is told to challenge it rather than follow it blindly. This is a strength of the user's best prompts — preserve it, never suppress it.
- **Working rules** — auto-filled from the defaults below; only surface them if the user wants to override.

If multiple goals are present, **make the user prioritize** ("which is the blocker?") and consider splitting into separate briefs/tasks. A brief whose GOAL has more than ~3 independent bullets is a sign the task is too large for one session — say so and propose a split (see *Right-sizing* below).

## The brief format

Write `brief.md` to the task directory root (English — it is LLM-facing and consumed by `prep`/`research`/`plan`). Structure:

```markdown
---
title: "Brief — <title>"
type: brief
task: <kebab-task>
category: <Feature|Fix|Debug & Fix|Refactor|Chore|Research|...>
size: <S|M|L>
status: active
created: <yyyy-mm-dd>
related: []        # PR/Issue URLs
---

## GOAL
- <outcome 1>
- <outcome 2>

## Acceptance criteria & verification
- <measurable signal> — verified by <method: simulator / real device / test / script exit / screenshot>

## Scope
- In: <…>
- Out: <…>

## Background
- <links, prior attempts, exact file paths>
- Repro (bugs): <steps>
- Payload (bugs): <error / response, verbatim>

## Hypothesis (challenge before following)
- <user's guess at cause / approach — to be validated, not assumed>

## Working rules
<the standard block, see below>
```

## Standard working rules (auto-filled)

These are the conventions the user repeats almost verbatim every session. Emit them automatically; do not make the user retype them. Adjust per project where the conversation makes the value obvious.

- **Worktree**: create under `~/Codes/<repo>.worktrees/<task>` (handled by `flow:prep`); sync to `origin/<base>` first.
- **Issue-first**: post research + plan as a GitHub Issue and get user approval **before** writing code. No local commits during the research/plan phase (`로컬 커밋 X`).
- **Critical review**: if working from an existing plan/issue, review it critically — do not follow blindly; flag missing or wrong parts and get approval before deviating.
- **Commits**: atomic, per logical unit; Conventional Commits; body 1–3 lines, max 5. (See `../../references/commit-conventions.md` and `../../references/tdd-policy.md`.)
- **PR**: open at the end; title/body in Korean; assignee + labels (reuse existing, create only if needed) + milestone as the project requires.
- **Tooling**: use the GitHub CLI directly (not MCP) for Issues/PRs unless told otherwise.
- **Ask when ambiguous**: surface genuinely uncertain points to the user instead of guessing.

Project-specific defaults (assignee, milestone, label seeds, worktree root) are the kind of thing that should live in a project `flow.config` rather than be re-typed — note any you infer in the brief so `prep`/`deploy` reuse them.

## Right-sizing and size estimate

Set `size` (S/M/L) using the same heuristics as `flow:prep` (single edit = S; a few files = M; cross-module / schema / public-API / subsystem replacement = L). The estimate decides what runs next:

- **S** → `prep` then straight to `develop`. Skip research/plan-review.
- **M** → `prep → plan` (research/plan-review only if cross-module or external dependencies).
- **L** → full pipeline `prep → research → plan → plan-review → develop`.

If the brief looks like it will exceed one focused session (very large surface, exploratory build-test-diagnose loops, or a GOAL with many independent parts), **propose splitting into sub-tasks / sub-issues** up front. The review found the longest sessions (50+ turns, repeated context exhaustion) were almost all under-scoped single briefs that should have been several.

## Output & handoff

1. Write `brief.md` to `.planning/<date>-<task>/` (create the directory if `prep` has not run yet, or let `prep` create it and write the brief into it — either order is fine as long as the brief lands there).
2. **Post the brief as a GitHub Issue** when the user wants the issue-first flow (the default for Fix/Debug/Research/Feature). Render it in **Korean** for the Issue body (user- and team-facing), keep `brief.md` in English. Use the GitHub CLI. Apply assignee/labels/milestone per the working rules.
3. **Hand off to `flow:prep`** with the resolved task name, category→type, base, size, and goal. From there the normal flow continues.

Do not start coding from this skill. Its deliverable is the brief (and optionally the Issue) — the agreed framing that every later step builds on.

## Anti-patterns this skill prevents

- Shipping a brief with a GOAL but no way to tell when it is met — **always** resolve acceptance + verification.
- Accepting "점검 / 파악 / 검토" as a task without an explicit scope boundary.
- Letting a second, larger goal appear mid-session — surface and prioritize all goals at framing time.
- Following the user's hypothesis as if it were established fact — it is labelled a hypothesis precisely so it gets challenged.
- One mega-brief that should have been three — right-size before prep.

## Reference

- `.planning/` layout and `prepare.md` schema: `../../references/directory-structure.md`
- Frontmatter field list (add `brief` type here when extending): `../../references/frontmatter.md`
- Commit / PR conventions: `../../references/commit-conventions.md`
- Document style (lists over tables, Korean/English split): `../../references/doc-style.md`
