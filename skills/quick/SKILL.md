---
name: quick
description: The express entry for a task the user judges trivial — skip framing/research/plan and go straight toward develop, but only after a fast sanity check. Use when the user says the work is small and wants speed ("그냥 바로 해줘", "간단한 거니까 바로", "바로 develop", "just do it", "quick fix", "skip the planning"). Quick applies a green/yellow/red rubric: green → straight to flow:develop, yellow → ask the user whether to plan first, red → the task is bigger than "simple" so escalate to flow:kickoff. It still forces a one-line goal + done-check and keeps branch-not-main + atomic-commit discipline. It is the shortcut; flow:kickoff is the default front door.
---

# flow:quick — Fast lane with a safety check

The user has judged the task simple and wants to skip the full front door. Quick honors that — but does **not** blindly trust "simple". It runs a fast classification and routes accordingly, so a task that's actually bigger than it looked doesn't blow up mid-develop with no plan and no branch.

The whole point is speed *with* a guardrail. Spend seconds, not minutes.

## Step 1 — Classify: green / yellow / red

Read the request against these signals. Take the **highest** severity that applies.

**🟢 Green — go straight to develop.** ALL of:
- One file, or a few tightly-localized edits.
- The goal is unambiguous and you can state the "done" signal in one line.
- Reversible; no schema / API / public-contract change.
- No new dependency, no architecture decision, no security/auth/payment surface.
- Familiar code the user clearly knows.

Examples: a copy/typo fix, a style tweak, a dependency bump, a one-line bug fix with an obvious cause.

**🟡 Yellow — ask first.** Any of:
- Touches ~2–3 files across a boundary, or a small new surface.
- Minor ambiguity in the goal, or a small user-flow change.
- You could do it directly, but a 3-line plan would de-risk it.

**🔴 Red — escalate, don't fast-lane.** Any of:
- Crosses modules / subsystems, or is unfamiliar territory.
- Schema / API / data-contract change; migration; anything destructive or hard to reverse.
- Security / auth / payment surface.
- Needs a new dependency or an architecture/interface decision.
- The goal has more than ~one outcome.

## Step 2 — Route

- **🟢 Green** → confirm a **one-line goal + done-check** to the user (e.g. "Goal: 헤더 오타 수정 → done when the header reads X"), ensure a task branch exists (never work on `main` — if on `main`, create/switch to a typed branch first), then write a **minimal `.planning/<date>-<task>/tasks.md`** — 1–3 checkboxes derived from the goal. `flow:develop`'s precondition requires a `tasks.md` to execute (it will otherwise stop and bounce to `flow:plan`, defeating the fast lane); a 3-line checklist is enough — no `plan.md`, no research. Then hand to **`flow:develop`**.
- **🟡 Yellow** → use `AskUserQuestion`: "This is a bit more than a one-liner — quick 3-line plan first (`flow:plan`), or straight to develop?" Default to a quick plan for anything touching multiple files. Route per the answer.
- **🔴 Red** → tell the user plainly: "This is bigger than a quick fix — it touches <reason>. I'd start from `flow:kickoff` (framing + a short plan) so we lock the goal and don't rework later." Recommend `flow:kickoff`; proceed the fast way only if the user overrides after hearing the risk.

Even on green, do not silently expand scope: if you discover mid-change that the task is actually yellow/red (a schema appears, a second module is involved), **stop and reclassify** rather than pressing on.

## Non-negotiables (even on the fast lane)

- **Never commit on `main`/default.** Quick still works on a task branch; if setup was skipped, create the branch (or run `flow:kickoff` setup) before the first commit.
- **A minimal `tasks.md` is required, not optional.** `flow:develop` refuses to run without one. Writing the 1–3 line checklist is what lets the green path reach develop instead of bouncing back to plan.
- **Atomic Conventional Commits.** Speed doesn't excuse bundling unrelated changes — `flow:develop` discipline still applies.
- **State the goal in one line.** The one thing quick refuses to skip is naming what "done" means — that single line prevents the most common fast-lane failure (drift on a fuzzy goal).

## Reference

- Default front door (framing + setup): `../kickoff/SKILL.md`
- Implementation loop: `../develop/SKILL.md`
- Lightweight plan (yellow path): `../plan/SKILL.md`
- End-to-end runner: `../orchestrate/SKILL.md`
