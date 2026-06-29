---
name: kickoff
description: The single entry point for any flow task. Start here for every new piece of work — a feature, bug fix, debug, chore, refactor, or research question — even a one-line "fix X" or "이거 작업하자". Kickoff figures out the task type (asking the user if it is not stated), runs cost-efficient research subagents to gather just-enough context, and writes a short, visual brief (goal + acceptance criteria + scope, with a Mermaid diagram for direction) — then hands off to flow:prep. It replaces the habit of retyping the same kickoff prompt every session, and forces the fields that were chronically missing (how do we know it's done? how is it verified? what is out of scope?). Do not start coding from here. Also fires on "frame this task", "세션 시작", "이거 작업 시작하자".
---

# flow:kickoff — The single front door

Every flow task starts here. There is **one** entry point, not several — the user should never have to remember whether to call `prep` or `plan` or `orchestrate` first. They describe what they want; kickoff figures out the rest and routes into the pipeline.

Kickoff codifies the kickoff-prompt template the user converged on across dozens of real sessions, and closes the gaps that made the weaker sessions stall (missing acceptance criteria, vague scope, no verification method).

## Operating philosophy — fast iteration over heavy planning

This is the load-bearing principle of the whole flow, and it starts here:

> **Plan → implement → review → fix, fast, many times.** A short brief the user can read in a minute and a diagram that shows the direction at a glance beats a 500-line plan every time. Heavy up-front planning makes everyone lose sight of the goal, over-invest in detail, and burn out. Keep every authored doc short, goal-and-output focused, and visual.

Concretely: write the *least* brief that still answers "what, done-when, out-of-scope." Push depth to the implementation, not the document. If you find yourself writing long prose, replace it with a Mermaid diagram or cut it.

## Step 1 — Determine the task type

Categories: `Feature` · `Fix` · `Debug & Fix` · `Refactor` · `Chore` · `Research` · `UI Fix` · `Question`.

- If the user **stated** the type (e.g. "## Fix - …", "debug this", "research X"), use it.
- If it is **not** stated and cannot be confidently inferred from the verb, **ask** with the `AskUserQuestion` tool — one question, the categories as options, recommended one first. Do not guess silently.

The type drives size estimate and which downstream steps run (see `flow:orchestrate`).

## Step 2 — Research with cost-efficient subagents (just enough)

Before framing, gather context — but **delegate it to cost-efficient subagents, never the frontier orchestrator model**, and keep it light. Fan out in parallel, one subagent per area that is actually relevant:

- **Codebase** — find the files/symbols/patterns the task touches.
- **GitHub** — related Issues / PRs / labels / milestones (`gh` CLI).
- **History** — recent commits in the touched area.
- **Web** — references / best practices, only when the task depends on external API/library shape.

Each subagent returns a **tight digest**, not raw dumps. The orchestrator reads digests and decides. Model tier per harness (Claude Code → Sonnet, Antigravity → Gemini Flash, Codex → Codex mini) is in `../../references/models.md`. Skip an area that is obviously irrelevant — research is a means to a good brief, not a phase to complete.

## Step 3 — Write the brief (short + visual)

Write `brief.md` to the task directory root (English — LLM-facing). Keep it tight. The non-negotiable fields — the ones the review showed are usually missing — are **MUST**.

```markdown
---
title: "Brief — <title>"
type: brief
task: <kebab-task>
category: <Feature|Fix|Debug & Fix|Refactor|Chore|Research|UI Fix|Question>
size: <S|M|L>
status: active
created: <yyyy-mm-dd>
related: []        # PR/Issue URLs from research
---

## Goal
One or two outcome bullets ("X가 정상 동작한다"), not a task list.

## Acceptance & verification (MUST)
- <measurable signal> — verified by <simulator / real device / test / script exit / screenshot>

## Scope (MUST)
- In: <…>   Out: <…>

## Direction
<a Mermaid diagram showing the intended flow/shape — flowchart, sequence, or user
journey. A picture of the approach the user can scan in seconds. See ../../references/mermaid.md.>

## Background
- Links (PR/Issue), exact file paths, prior attempts. (Bugs: repro steps + error/response payload, verbatim.)

## Hypothesis (challenge, don't follow)
- The user's guess at cause/approach — to be validated, not assumed.
```

Rules learned from the session review:
- **Always resolve acceptance + verification.** A goal with no "done" signal is the #1 cause of drift. If the user did not state it, ask.
- **Always set a scope boundary.** "점검 / 파악 / 검토" without an In/Out line is the highest-risk prompt shape.
- **Bugs need repro + payload.** Symptom alone forces a clarification round.
- **Multi-goal → prioritize or split.** If the goal has more than ~3 independent parts, propose splitting into sub-tasks/sub-issues. The longest, most painful sessions were under-scoped single briefs.

## Step 4 — Publish & hand off

- **Non-code docs live in GitHub**, not the repo. By default (Fix/Debug/Research/Feature) **post the brief as a GitHub Issue** — render the Issue body in **Korean** (user/team-facing), keep `brief.md` in English. Use the `gh` CLI. Apply assignee/labels/milestone per the working rules below.
- **Hand off to `flow:prep`** with task name, type, base, size, and goal. The pipeline continues from there. Do not code from this skill.

## Working rules (auto-filled — don't make the user retype)

Emit these automatically; surface only to override. Project-specific values (assignee, milestone, label seeds, worktree root, whether issue-first is on) should live in a project `flow.config` rather than be re-typed every session.

- **Worktree**: `~/Codes/<repo>.worktrees/<task>` (via `flow:prep`); sync to `origin/<base>` first.
- **Issue-first**: research + plan go to a GitHub Issue, user approves, *then* code. No local commits during research/plan.
- **Critical review**: working from an existing plan/issue → review it critically, flag gaps, get approval before deviating.
- **Commits**: atomic, Conventional Commits, body 1–3 lines (max 5). See `../../references/commit-conventions.md`.
- **PR**: opened at the end; title/body Korean; assignee + labels + milestone as the project requires. (See `flow:commit-pr` for the fast commit→push→PR loop.)
- **Tooling**: `gh` CLI directly (not MCP) for Issues/PRs.
- **Ask when ambiguous** instead of guessing.

## Size & routing

Set `size` (S/M/L) with the `flow:prep` heuristics. It decides the route — but bias toward the *shortest* route that ships something reviewable:

- **S** → prep → develop. No research phase.
- **M** → prep → plan → develop. (Plan stays short; diagram over prose.)
- **L** → full pipeline, but still keep each plan doc lean and split oversized work into sub-issues.

## Reference

- `.planning/` layout & `prepare.md` schema: `../../references/directory-structure.md`
- Mermaid diagram types & skeletons: `../../references/mermaid.md`
- Research subagent tier: `../../references/models.md`
- Commit / PR conventions: `../../references/commit-conventions.md`
- Document style (lists over tables, KO/EN split): `../../references/doc-style.md`
