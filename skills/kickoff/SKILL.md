---
name: kickoff
description: The single entry point for any flow task — it both frames the work AND sets up the workspace, so there is nothing to call before it. Start here for every new piece of work — a feature, bug fix, debug, chore, refactor, or research question — even a one-line "fix X" or "이거 작업하자". Kickoff figures out the task type (asking if unstated), runs cost-efficient research subagents for just-enough context, writes a short visual brief (goal + acceptance + scope, with a Mermaid diagram), then creates the isolated worktree, branch, and `.flow/tasks/<date>-<task>/` directory — landing you ready to plan or develop. It replaces retyping the same kickoff prompt and forces the fields that were chronically missing (how do we know it's done? how is it verified? what is out of scope?). Do not start coding from here. Also fires on "frame this task", "create a worktree", "세션 시작", "이거 작업 시작하자".
---

# flow:kickoff — The single front door (framing + setup)

Every flow task starts here. There is **one** entry point, not several — the user should never have to remember whether to call `prep` or `plan` or `orchestrate` first. They describe what they want; kickoff frames it, sets up the workspace, and routes into the pipeline.

Kickoff codifies the kickoff-prompt template the user converged on across dozens of real sessions, and closes the gaps that made the weaker sessions stall (missing acceptance criteria, vague scope, no verification method). It also absorbs task setup (worktree / branch / `.flow/tasks/`) — previously a separate `prep` step — so framing and scaffolding happen in one move.

## Operating philosophy — fast iteration over heavy planning

This is the load-bearing principle of the whole flow, and it starts here:

> **Plan → implement → review → fix, fast, many times.** A short brief the user can read in a minute and a diagram that shows the direction at a glance beats a 500-line plan every time. Heavy up-front planning makes everyone lose sight of the goal, over-invest in detail, and burn out. Keep every authored doc short, goal-and-output focused, and visual.

Concretely: write the *least* brief that still answers "what, done-when, out-of-scope." Push depth to the implementation, not the document. If you find yourself writing long prose, replace it with a Mermaid diagram or cut it.

> **Fast lane:** if the user is confident the task is trivial and wants to skip framing, `flow:quick` is the express entry — it applies a green/yellow/red rubric and, when the task really is small, jumps straight to `flow:develop`. Kickoff is the default; quick is the shortcut for the genuinely simple.

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

Each subagent returns a **tight digest**, not raw dumps. The orchestrator reads digests and decides. Model tier per harness (Claude Code → Sonnet, Antigravity → Gemini Flash, Codex → Codex 5.6 Terra) is in `../../references/models.md`. Skip an area that is obviously irrelevant — research is a means to a good brief, not a phase to complete.

## Step 3 — Write the brief (short + visual)

Compose `brief.md` (English — LLM-facing). Keep it tight. The non-negotiable fields — the ones the review showed are usually missing — are **MUST**. Note the task directory does not exist until Step 4 creates it: draft the brief now and **write it into `.flow/tasks/<date>-<task>/` (root) right after setup**, or if setup already ran, write it there directly. Do not scatter a `brief.md` at the repo root.

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
- **In:** <the outcomes this task delivers>
- **Out:** <what is explicitly excluded — fill this now, don't let it arrive piecemeal later>

## Direction
<a Mermaid diagram showing the intended flow/shape — flowchart, sequence, or user
journey. A picture of the approach the user can scan in seconds. See ../../references/mermaid.md.>

## Background
- Links (PR/Issue), exact file paths, prior attempts. (Bugs: repro steps + error/response payload, verbatim.)

## Hypothesis (challenge, don't follow)
- The user's guess at cause/approach — to be validated, not assumed.
```

Rules learned from the session review:
- **Ambiguous goal → AskUser, don't guess.** If any part of what "done" means could be read more than one way, resolve it with `AskUserQuestion` (concrete options) *before* writing the brief. Confirm the big direction, not every detail.
- **Always resolve acceptance + verification.** A goal with no "done" signal is the #1 cause of drift. If the user did not state it, ask.
- **Always set both scope boundaries.** In *and* Out. "점검 / 파악 / 검토" without an In/Out line is the highest-risk prompt shape; a missing Out line is why exclusions arrive piecemeal mid-build.
- **Decide schema/contract with the user.** Any non-trivial data schema or API shape the task hinges on goes through `AskUserQuestion` before it's committed — the most expensive thing to unwind later. (Plan re-confirms this; see `flow:plan`.)
- **Bugs need repro + payload.** Symptom alone forces a clarification round.
- **Multi-goal → prioritize or split.** If the goal has more than ~3 independent parts, propose splitting into sub-tasks/sub-issues. The longest, most painful sessions were under-scoped single briefs.

## Step 4 — Set up the workspace (worktree · branch · `.flow/tasks/`)

With the brief written, scaffold the isolated workspace so the pipeline has somewhere to run. This is the old `prep` step, now folded in.

### 4a — Settle the setup inputs

You already know the goal, type, and size from the brief. Fill the rest, asking only what you cannot infer:

- **Task name** (kebab-case → branch suffix) — derive from the goal; if several forms fit, propose two or three via `AskUserQuestion` and let the user pick.
- **Base branch** — default `main`.
- **Type** for the branch/commit prefix — `feature | fix | chore | refactor | docs` (map from the brief category).
- **Size** — `S | M | L`, carried from the brief. Heuristics if still unset:
  - **S** — single file / component tweak / isolated bug fix / dependency bump. Usually no research.
  - **M** — one module / a few files (≤ ~5), small new surface, no schema change. Default for most features.
  - **L** — crosses modules, new domain concepts, schema or public-API change, or replaces a subsystem. Prefer splitting (see below).

If the goal was vague enough that the task name or scope boundary is genuinely ambiguous, resolve it **before** scaffolding — a wrong branch name is annoying to undo once the worktree exists. Offer concrete options with `AskUserQuestion`; skip the round entirely when the request is already clear.

### 4b — Run the setup script

```bash
bash <plugin-dir>/scripts/prep.sh \
  --task <kebab-name> \
  --type <feature|fix|chore|refactor|docs> \
  --base <main-or-other> \
  --size <S|M|L> \
  --goal "<one-line goal>"
```

The script is idempotent. It creates the worktree at `<repo-parent>/<repo-name>.worktrees/<task>`, the branch, and `.flow/tasks/<date>-<task>/` with a seeded `prepare.md`; ensures `.flow/tasks/` is gitignored; and auto-installs dependencies (detects pnpm > bun > npm > yarn > uv; non-fatal on failure). It prints the worktree path on stdout — **capture it; every subsequent skill operates inside that path.**

`.flow/tasks/` is **local working memory and is never committed** — the durable copy of briefs/plans/reviews lives in GitHub Issues / PR bodies. Write (or move) `brief.md` into `.flow/tasks/<date>-<task>/` (root) now that the directory exists. Store any secrets/tokens the task needs under `.flow/tasks/<date>-<task>/artifacts/secret.*` and reference them **by path** — never paste raw tokens into chat. (`prep.sh` gitignores `.flow/tasks/` here; on the skip-setup / in-place path, **verify `.flow/tasks/` is gitignored before writing any secret** so a later `git add` can't commit it.) See `../../references/directory-structure.md`.

### 4c — Land in the worktree

1. **`cd` into the worktree** and confirm with `git rev-parse --show-toplevel`. Every later change assumes the working directory is the worktree; staying in the original dir lands commits on the wrong branch.
2. **Verify** `.flow/tasks/<date>-<task>/prepare.md` exists and carries size/goal. Append detail to its Notes section if the one-line goal was insufficient.
3. **Report** the worktree path, branch, and size.

**Skip-setup path:** if the user says "just do this on the current branch", skip the worktree but still create `.flow/tasks/<date>-<task>/` + `prepare.md`, and tell the user no isolated worktree was created.

## Step 5 — Publish & hand off

- **Non-code docs live in GitHub**, not the repo. By default (Fix/Debug/Research/Feature) **post the brief as a GitHub Issue** — render the Issue body in **Korean** (user/team-facing), keep `brief.md` in English. Use the `gh` CLI. Apply assignee/labels/milestone per the working rules below. (In ordered lists inside GitHub bodies, do **not** prefix numbers with `#` — GitHub auto-links `#N` as an issue reference.)
- **Record the Issue URL in `brief.md` frontmatter** — `issue: <full URL>` plus `issue_role: leaf` (or `parent` for an umbrella issue from a split). This is the handoff to `flow:deploy`, which links the Issue from the PR body. `gh issue create` prints the URL on stdout, so capture it:

  ```bash
  ISSUE_URL=$(gh issue create --title "<title>" --body-file <(…) \
    --assignee "<config>" --label "<config>" --milestone "<config>")
  echo "$ISSUE_URL"   # https://github.com/<org>/<repo>/issues/41
  ```

  Then write `issue: $ISSUE_URL` into the frontmatter. Skip it only when no Issue was created — and say so, because deploy will then have to ask the user for the link.
- **Hand off by size** (see routing): **S** → `flow:develop`; **M/L** → `flow:plan`. Do not code from this skill.

## Working rules (auto-filled — don't make the user retype)

Emit these automatically; surface only to override. Project-specific values (assignee, milestone, label seeds, worktree root, whether issue-first is on) should live in a project `.flow/config.yaml` rather than be re-typed every session. See `../../references/config.md`.

- **Worktree**: `<repo-parent>/<repo>.worktrees/<task>`; sync to `origin/<base>` first.
- **Issue-first**: research + plan go to a GitHub Issue, user approves, *then* code. No local commits during research/plan.
- **Critical review**: working from an existing plan/issue → review it critically, flag gaps, get approval before deviating.
- **Commits**: atomic, Conventional Commits, body 1–3 lines (max 5). See `../../references/commit-conventions.md`.
- **PR**: opened at the end; title/body Korean; assignee + labels + milestone as the project requires. (See `flow:commit-pr` for the fast commit→push→PR loop.)
- **Tooling**: `gh` CLI directly (not MCP) for Issues/PRs.
- **Ask when ambiguous** instead of guessing.

## Size & routing

Set `size` (S/M/L) with the heuristics above. It decides the route — but bias toward the *shortest* route that ships something reviewable:

- **S** → develop directly. No research, no `plan.md` — but still write a **minimal `tasks.md`** (a few checkboxes), because `flow:develop` requires one to execute. (`flow:plan` can produce just `tasks.md` for an S task; or write the short list by hand.)
- **M** → plan → develop. (Plan stays short; diagram over prose.)
- **L** → full pipeline, but still keep each plan doc lean. **Strongly prefer splitting** (below) over one large task.

## Right-sizing: split oversized tasks into sub-issues

Fast iteration depends on tasks that fit a single focused session. Before routing, check for **oversized** signals:

- The GOAL has **more than ~3 independent outcomes**.
- The work spans clearly separable areas (e.g. "fix auth" + "redo the settings UI" + "add a deploy script").
- It implies an open-ended build-test-diagnose loop (the kind that ran 50–100+ turns and exhausted context in past sessions).

When oversized, **don't proceed as one task.** Propose a split and, on the user's OK, create the issue tree with `gh`:

1. Write/keep the kickoff brief as the **parent** GitHub Issue (the umbrella goal + the split rationale).
2. Create **one sub-issue per independent part** — each a self-contained brief (its own GOAL, acceptance, scope). Link them under the parent (a task-list in the parent body, and each sub-issue referencing the parent `#N`).
3. Order them: which is the blocker / first reviewable slice.
4. Run the flow on the **first** sub-issue only (scaffold that one via Step 4). The rest wait — each becomes its own kickoff→…→deploy loop later.

```bash
# gh issue create prints the new issue's URL on stdout — capture it, derive the number.
PARENT_URL=$(gh issue create --title "<umbrella>" --body-file parent-brief.md \
  --assignee "<config>" --label "<config>" --milestone "<config>")
PARENT="${PARENT_URL##*/}"
# then per part:
gh issue create --title "<part 1>" --body "<sub-brief>

부모: #${PARENT}" --assignee "<config>" ...
```

Record the **sub-issue** URL as `issue:` in the brief of the part you actually scaffold (with `issue_role: leaf`), and the parent URL in that brief's `related:`. The parent issue gets `issue_role: parent` — deploy must not `Closes` it, or the remaining sub-issues are orphaned.

A split of 3–6 sub-issues is typical for an L that was really several tasks. Prefer more, smaller sub-issues over fewer fat ones — the whole point is that each finishes fast and gets reviewed on its result.

## Common pitfalls

- **Naming collision with an existing branch.** `prep.sh` errors unless `--force` is set. Do not pass `--force` without asking — an existing branch usually means the task is already in progress (resume? rename?).
- **Running from inside another worktree.** Fine — the script uses `git rev-parse --show-toplevel` to find the canonical repo and creates the new worktree as a sibling.
- **Forgetting to cd.** Stay in the original repo dir and every change lands on the wrong branch. Always cd into the worktree before continuing.

## Reference

- `.flow/tasks/` layout & `prepare.md` schema: `../../references/directory-structure.md`
- Mermaid diagram types & skeletons: `../../references/mermaid.md`
- Research subagent tier: `../../references/models.md`
- Commit / PR conventions: `../../references/commit-conventions.md`
- Project defaults (`.flow/config.yaml`): `../../references/config.md`
- Document style (Simplified Technical English, lists over tables, KO/EN split): `../../references/doc-style.md`
