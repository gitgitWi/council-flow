---
name: plan
description: Produce a short, visual `plan.md` (goal + approach + a Mermaid diagram of the direction) and a concise checklist `tasks.md` for an upcoming task. Use this whenever the user is about to start a non-trivial change — a feature, multi-file fix, refactor — before any code is written. Even if the user just says "let's start", produce a plan first; the develop skill consumes these documents. Keep it lightweight — a one-minute read and a diagram beat a long document; the goal is fast plan→implement→review→fix iteration, not exhaustive up-front detail. The plan is for any coding agent (Claude, Codex, a teammate) to pick up and execute, so it must stand on its own.
---

# flow:plan — Authoring plan.md and tasks.md

A flow plan is **a short, visual one-pager that explains the approach, not the code**. The reader should finish in about a minute and know what is going to be built and how — mostly from a diagram.

## Operating philosophy — lightweight, visual, fast iteration

The point of planning is to start implementing sooner with a clear direction, **not** to specify everything up front. Heavy plans (the GSD/over-planning failure mode) make everyone lose the goal, over-invest in detail, and burn out before any real output appears.

- **Bias to brevity.** Write the *least* plan that conveys goal, direction, and scope. If a section is not earning its length, cut it.
- **Diagram over prose.** A Mermaid diagram of the flow/shape communicates direction faster than paragraphs. Reach for one before writing long prose (see `../../references/mermaid.md`).
- **Iterate fast.** plan → implement → review → fix, repeated, beats one big plan. Get something reviewable in front of the user quickly; refine on the next loop.
- The size ceilings below are **ceilings, not targets** — most plans should land well under them.

## Lock the goal, spec, and user flow before you plan

Brevity does **not** mean skipping the goal. The single most expensive failure mode is a plan that starts from an ambiguous goal: scope corrections then arrive piecemeal *after* implementation has begun ("actually mobile is out", "it must match prod pixel-for-pixel", "that field shouldn't exist"). Lock these three **before** drafting the approach — this is where clarity is cheap:

1. **Goal must be unambiguous.** If any part of what "done" means is unclear, **ask with `AskUserQuestion`** — offer concrete options so the user picks the direction, don't guess. Confirm the goal at the level of *the big direction*, not every detail.
2. **Write the spec + user flow explicitly.** State the behavioral contract (what the system does, for whom, in what order) and the **user flow** as a Mermaid `journey`/`sequenceDiagram`. A plan the user can't trace as a flow isn't specified yet.
3. **Decide the shape/schema *with* the user.** Any non-trivial data schema, API contract, or interface decision goes through `AskUserQuestion` before it's baked into the plan — a wrong schema is the most expensive thing to unwind later.
4. **Enumerate out-of-scope up front**, not just in-scope. The `## Non-goals` section is mandatory (not "near the end if you get to it") — list what you are deliberately *not* doing so it can't creep in during develop.

This is a few minutes at plan time that saves the piecemeal-correction spiral during develop. Keep it tight — options and a diagram, not prose.

## Prep precondition check (run first, every invocation)

Before writing anything, verify the worktree + branch + task directory exist. If not, the user has skipped `flow:kickoff` setup and `plan.md` would land in the wrong place.

```bash
# 1. Are we in a flow worktree? (heuristic: parent dir name ends in .worktrees)
WT_PATH="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo"; exit 1; }
WT_PARENT="$(basename "$(dirname "$WT_PATH")")"
case "$WT_PARENT" in *.worktrees) IN_WORKTREE=1;; *) IN_WORKTREE=0;; esac

# 2. Are we on a typed branch (feature/* | fix/* | chore/* | refactor/* | docs/*)?
BRANCH="$(git branch --show-current)"
case "$BRANCH" in feature/*|fix/*|chore/*|refactor/*|docs/*) ON_TASK_BRANCH=1;; *) ON_TASK_BRANCH=0;; esac

# 3. Is there a .flow/tasks/<date>-<task>/prepare.md to write into?
PREPARE="$(ls -1 .flow/tasks/*/prepare.md 2>/dev/null | head -n1)"
[[ -n "$PREPARE" ]] && HAS_TASK_DIR=1 || HAS_TASK_DIR=0
```

Decision matrix:

| In worktree | On task branch | Has `.flow/tasks/.../prepare.md` | Action |
|---|---|---|---|
| yes | yes | yes | Proceed. This is the normal post-prep state. |
| no | no | no | **Stop.** Tell the user setup was skipped and ask: (a) run `flow:kickoff` setup now (recommended), (b) proceed in-place on the current branch (only sensible for size S, and you must still create `.flow/tasks/<date>-<task>/prepare.md` manually before writing the plan), (c) abort. |
| any | yes | no | Branch exists but the task dir is missing. Ask the user whether the prior task dir was cleaned up (rare) or this is a new task on a reused branch (more common). Create `.flow/tasks/<date>-<task>/prepare.md` before writing the plan either way. |
| any | any | yes | Task dir exists. Proceed and write into the existing dir — do not create a second one for the same date+task. |

Do not silently fix the situation. The decision affects which branch commits land on and where artifacts get audited; the user should make it.

If the user picks "proceed in-place" without prep, write the size into the manually-created `prepare.md` so downstream skills (especially `flow:develop`) see consistent metadata.

## Output files

All written under `<worktree>/.flow/tasks/<date>-<task>/`:

- **`plan.md`** — approach, scope, architecture decisions, rollout. ~500 lines max for the whole thing (including any phase sub-plans). If it grows beyond that, split into `plan-phase-1.md`, `plan-phase-2.md` and let `plan.md` become a short index.
- **`tasks.md`** — concise behavior checkbox list (one-line behavior + pseudo-code test or Mermaid), the single source of truth for progress during develop.
- **`brainstorm.md`** — *conditional.* Multi-LLM brainstorming synthesis, written before `plan.md` when scope warrants (see "Multi-LLM brainstorming" below). Raw per-model outputs go under `artifacts/` (filenames prefixed `brainstorm-`).

All authored docs are **English** (any coding agent picks them up). Korean translations are dispatched as a separate step after drafting (see "Korean translation dispatch" below).

## Multi-LLM brainstorming (run when scope warrants)

Before drafting `plan.md`, run a brainstorming round when the change is large enough or cross-cutting enough that diverse perspectives meaningfully sharpen the approach. The point is to surface **architecture options, hidden risks, and security/correctness angles *before* committing to a shape**. (There is no separate plan-review step — keep planning light and let review concentrate on the result.)

### When to run

- **Size L** — always run. Large changes benefit most from multi-angle exploration.
- **Size M** — run when any of:
  - The change touches **multiple modules** (cross-module impact flagged in `prepare.md` or surfaced from `research.md`).
  - **Security-sensitive surface**: auth, payments, PII, cryptography, file uploads, anything user-controlled landing in a privileged context.
  - **Public surface area** (a new external API endpoint, a published SDK, a webhook contract).
  - The user explicitly asks for "options" / "alternatives" / "다각도로 보자" before planning.
- **Size S** — skip. One perspective is fine for an atomic edit.

If unsure for an M task, ask the user one short question. Default-no for plain M, default-yes for L.

### Lenses

Generate options through focused lenses so they are differentiated, not duplicated:

- **Architecture & alternatives** — 2–3 distinct shapes; load-bearing tradeoffs (cost / blast radius / reversibility); ecosystem analogues.
- **Risk & failure modes** — race conditions, partial states, rollback paths, observability gaps, regressions in adjacent modules.
- **Security & correctness** *(size L, or M with security-sensitive surface)* — auth/authz, injection, data exposure, dependency surface, secrets.

### Idempotency precondition

Before dispatching anything, check whether the brainstorm has already run:

```bash
BRAINSTORM=.flow/tasks/<date>-<task>/brainstorm.md
if [[ -f "$BRAINSTORM" ]] && grep -q '^status: active' "$BRAINSTORM"; then
  echo "brainstorm.md already exists (status: active)"
fi
```

If it does, **do not silently re-dispatch.** Ask the user: (a) keep the existing synthesis and skip the sub-phase, (b) regenerate (the existing `brainstorm.md` and its `artifacts/brainstorm-*` contributor files are moved aside to `artifacts/brainstorm.v<N>.md` and `artifacts/brainstorm-<lens>-<model>.v<N>.md`, mirroring the `artifacts/plan.v<N>.md` versioning convention), or (c) abort. The most common path after an interrupted session is (a) — re-running the brainstorm doubles cost and clobbers the audit trail.

### How it works

**The flow agent generates the options itself** — it is the frontier model; it does not dispatch external CLIs. Work each lens above in turn and capture the options directly into `brainstorm.md`.

If the user wants **external** diversity, write a short brainstorm brief (the lenses + context, pointing at `prepare.md`/`research.md`) to `artifacts/brainstorm-brief.md`, let the user run their chosen agent(s) against it, save each return as `artifacts/brainstorm-<agent>.md`, and fold them into the synthesis. This is the same brief → user-run-agents model as code-review (see `../../references/multi-llm.md`). Default is Claude-only; reach for external agents only when the stakes justify the round-trip.

Idempotency: if `brainstorm.md` already exists with `status: active`, don't silently redo it — ask the user to keep it, regenerate (move the old to `artifacts/brainstorm.v<N>.md`), or skip.

### Synthesis — `brainstorm.md`

Write a single English `brainstorm.md` at `.flow/tasks/<date>-<task>/brainstorm.md` — the options from your own lenses, plus any external-agent returns (read each once, extract load-bearing ideas). This is what the planner consults while drafting `plan.md`.

```markdown
---
title: "Brainstorm — <task name>"
type: brainstorm
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
size: <M|L>
parent: ./prepare.md
related:
  - ./research.md (if exists)
contributors:
  - flow-agent              # plus any external agent the user ran, e.g. antigravity, codex
---

# Brainstorm — <task>

## Architecture options
- 2–3 shapes the planner should weigh. One-line tradeoff each.

## Risks worth designing against
- Concrete failure modes raised by the brainstorm. Short and actionable.

## Security / correctness angles
- Threat-model bullets that should shape the plan or land as explicit non-goals.
  (Omit this section entirely when no security lens was run.)

## Convergence
- Where models agreed. These are usually safe assumptions for the plan.

## Divergence (most valuable section)
- Where models disagreed. Each entry: which model said what, and the planner's
  current lean — or "open question — needs user" when unresolved.

## Open questions for the user
- Anything the brainstorm could not resolve. Surface these before drafting the plan.
```

### What NOT to do

- **Don't brainstorm for size S.** It's noise.
- **Don't let the brainstorm become the plan.** Brainstorm is option-generation; the plan is the decision.

## Frontmatter (every generated document)

Both `plan.md` and `tasks.md` open with a YAML frontmatter block. The schema and per-type fields are in `../../references/frontmatter.md`; mirror `task` and `size` from `prepare.md`, and `task_date` from the directory name's date prefix. Do not skip this — `frontmatter.md` exists so future agents can locate documents by `type: plan` / `task: <name>` without reading bodies.

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
parent: ./prepare.md
related:
  - ./tasks.md (behavior checklist)
  - ./research.md (if exists — pre-plan investigation)
version: 1
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
  - ./prepare.md
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
Must be unambiguous — if it wasn't, you resolved it with the user (AskUser) before writing this.

## Spec & user flow
- The behavioral contract: what the system does, for whom, and in what order. Include any
  data schema / API shape that was decided (with the user) — enough that develop can build to it.
- A **user flow** as a Mermaid `journey` or `sequenceDiagram` — the path the user takes end to end.

## Scope
- **In:** the outcomes this task delivers.
- **Out:** what is deliberately excluded (also restated in `## Non-goals`). Fill this now, not later.

## Decision context
- Problem framing: who is affected, what outcome matters, and what constraints
  are already known.
- Premises: the assumptions this plan relies on. Mark any that are still
  unverified and explain how the plan avoids depending on them too heavily.
- Existing leverage: code, docs, tests, or workflows the plan will reuse rather
  than rebuild.

## Approach
The shape of the solution in 3-7 bullets. Talk about *what changes* and *why this
shape and not another*. Stay at the level of *direction* — the file-by-file detail
goes in `## Change map` below; per-task implementation lives in `tasks.md`.

**Lead with a Mermaid diagram.** A picture of the direction is the fastest read and
the most valuable part of the plan. Pick the type by what the change is (full
skeletons + GitHub gotchas in `../../references/mermaid.md`):

- Control / logic flow → `flowchart`
- API / message / async flow → `sequenceDiagram`
- Data model / schema change → `erDiagram`
- User-facing multi-step flow → `journey`

Render as a fenced ` ```mermaid ` block so GitHub / PR tools / docs sites pick it up.
Multiple diagrams are fine when distinct flows do not fit one — size L plans with
per-phase flows typically need more than one. The only time to skip the diagram is
the truly trivial "edit a function, add a test" shape, where a diagram is noise —
say so explicitly rather than defaulting to prose.

You may name concrete file paths and key type signatures inline when they sharpen
the shape (e.g., "extend `BridgeRouter` to a `Record<RequestType, Handler>`
dispatch table"). Resist pasting full implementations — if a snippet grows past
~5 lines, it belongs in `tasks.md` as a test signature or in the actual
implementation, not here.

## Change map
The file-level surface of the change. This section is what lets a reader (or
another agent) decide "do I need to touch this code?" without reading the rest of
the plan. Use lists, group by area when the change spans multiple modules. **One
bullet per file is the target — keep each file to a single list item, using
continuation lines under that bullet when needed.** When a file's change is
non-obvious, refer the reader to the relevant `## Approach` bullet rather than
inventing a sub-section.

### New
- `path/to/new-file.ts` — one-line purpose. Key exports / signatures when load-bearing.

### Modified
- `path/to/existing.ts` — was *<current behavior>* → becomes *<new behavior>*.
  Mention the specific function/symbol when the file is large.

### Deleted
- `path/to/dead-file.ts` — why it's dead, what (if anything) replaces it.

For size S where the change touches 1-3 files with obvious edits, the Change map
can collapse into a short paragraph or be omitted — the file paths are already in
`tasks.md`. For size M/L it is mandatory: this is the section the user reads to
decide whether the plan is ready for `flow:develop`.

## Alternatives considered
- Minimal viable: the smallest approach that could satisfy the goal.
- Local architecture fit: the approach that best matches current project patterns.
- Ideal / lateral: include only when meaningfully different.
- End with the chosen approach and the decision rationale. Mention effort, risk,
  reversibility, blast radius, and why rejected options were rejected.

## Phases (only if size = L)
- Phase 1: <one line>
- Phase 2: <one line>
Each phase gets its own `plan-phase-N.md` if it has more than ~10 tasks.

## Risks & open questions
Things that could derail the plan. Each entry: the risk, the mitigation, who
decides.

## Failure modes
- Concrete ways the change can fail in production or during agent execution.
- For each: expected handling, user/operator impact, and whether a test or
  verification step covers it.

## Test strategy
- Unit/integration/e2e/eval coverage that maps to the behavior in `tasks.md`.
- Existing tests to extend and new tests to add.
- Explicitly say when a task is non-TDD and why.

## Rollout
How does this ship? Feature flag? Migration? Backwards-compat shim? If the answer
is "just merge", say so explicitly.

## Non-goals
Bulleted. What is explicitly out of scope. Placed near the end because it is
boundary-setting context, not the headline — but still load-bearing: this list
prevents scope creep during develop, so don't omit it.

```

**Things to leave out of plan.md:**

- Full implementation code. Inline snippets >~5 lines belong in `tasks.md` (as
  test signatures) or in the actual implementation. **Exception:** Mermaid
  diagrams requested in `## Approach` are exempt from this limit — they are not
  implementation code, they are the picture of it.
- Long type signatures inside `## Change map`. Keep Change map entries to a
  single list item (continuation lines fine). Type signatures longer than that —
  or short contracts that need a few lines — belong in `## Approach`, not in
  Change map bullets.
- Step-by-step instructions. Those are `tasks.md`'s job.
- Restating what's in `research.md`. Reference it, don't copy it.

## Plan self-review

Before showing the plan to the user, review it with fresh eyes and fix gaps inline:

- **Goal locked:** Goal is unambiguous, the spec + user flow are written, and any
  schema/contract was decided with the user (AskUser) — not left implicit.
- **Coverage:** Every stated success criterion maps to at least one task.
- **Placeholders:** No TBD/TODO/fill-in-later language remains.
- **Change map present:** For size M/L, every file the plan implies touching
  appears in `## Change map` (New / Modified / Deleted). A reader can answer
  "what files change?" without reading the rest of the plan.
- **Change map coverage:** Every entry in `## Change map` is touched by at least
  one task in `tasks.md`, and every file edited by `tasks.md` appears in
  `## Change map` (or the section is intentionally collapsed for size S).
- **Flow legible:** Where the change involves message passing or non-trivial
  control flow, `## Approach` contains a Mermaid diagram (fenced ` ```mermaid `
  block). Prose-only is allowed *only* when the planner explicitly states why a
  diagram would be noise or infeasible — not as a default escape hatch.
- **Reuse:** The plan explains what existing code/docs/tests it reuses, or why not.
- **Alternatives:** At least two approaches were considered for non-trivial work,
  with a clear chosen approach and rejected-option rationale.
- **Failure modes:** Important nil/empty/error/timeout/concurrency paths are named
  and either handled, tested, or explicitly out of scope.
- **Scope:** Non-goals are explicit, and size S tasks are not bloated with M/L process.
- **Handoff:** `tasks.md` is specific enough for `flow:develop` to execute without
  rediscovering the architecture. Each task carries its expected commit hint(s).

## tasks.md structure

A **concise checkbox list of behaviors**. Each task is **a behavior, not a step**. The develop skill treats each unchecked item as a TDD cycle (write test → implement → commit).

**Do not use Given-When-Then prose.** GWT made tasks long and hard to scan for no benefit. Express each behavior in the shortest form that is still testable:

- A **one-line behavior statement** (imperative, concrete), and
- *for code work,* either a **pseudo-code test** snippet (the assertion you would write) **or** a small **Mermaid** `flowchart`/`journey` showing the behavior — whichever reads faster. Pick one; do not write both.
- *for non-code work* (config, deps, docs), just the one-line statement.

The pseudo-code test or diagram replaces the GWT body — it states the same "when X, expect Y" contract in a form a human scans in seconds and `flow:develop` can turn into a real test.

> **Format is non-negotiable: `- [ ]` bullets, never a markdown table.**
> "Checklist" in this plugin literally means "list of `- [ ]` items." A table cell cannot be checked off, cannot be appended to mid-task, and breaks `flow:develop`, which reads progress by scanning for `[ ]` vs `[x]`. The same rule applies to *any* file whose role is a checklist — audit checklists, status checklists, verification checklists. If you reach for a table to show "item / status / note," stop and use:
>
> ```markdown
> - [ ] **Item** — note. Status: ❌
> - [x] **Item** — note. Status: ✅
> ```
>
> Tables are fine for *inventories* or *comparison matrices* (read-only reference data). They are wrong for anything called a checklist.

Each TDD task carries an inline **commit hint** showing the expected commit boundary — typically one `test(...)` followed by one `feat(...)` (or `fix(...)`/`refactor(...)`). Non-TDD tasks carry a single hint.

Hints are **advisory and human-/reviewer-readable only**. `flow:develop` does not currently parse `→ ...` lines; it still derives commit messages from the task body and `references/commit-conventions.md`. Treat hints as a planner-side aid for catching badly-scoped tasks (a behavior that needs three commits probably needs three checkboxes) and as a reviewer signal for what the planned commit shape was — not as a contract the develop skill enforces. A future PR may wire `flow:develop` to read and honor hints (and to record deviations in the commit body); until then, do not rely on that behavior.

```markdown
# Tasks — <task name>

## Phase 1 (optional grouping)

- [ ] Redirect to Google's OAuth consent screen when a user without a linked
      account clicks "Sign in with Google".
      ```
      test: click sign-in → expect redirect URL host == accounts.google.com
      ```
      → `test(auth): redirect to Google consent on sign-in click`
      → `feat(auth): wire Google OAuth redirect`

- [ ] Issue a session and land on `/dashboard` on a valid Google callback.
      ```
      test: callback(validCode) → expect session token set && route == /dashboard
      ```
      → `test(auth): issue session on valid Google callback`
      → `feat(auth): implement Google callback handler`

- [ ] Show a non-technical error and stay on `/login` when Google denies consent.
      (diagram alternative when a flow is clearer than an assertion:)
      ```mermaid
      flowchart LR
        cb[callback] -->|error/denied| err[show message] --> login["/login"]
      ```
      → `test(auth): show error and stay on /login when Google denies`
      → `feat(auth): handle Google error/denial path`

## Non-TDD tasks

- [ ] Update `.env.example` with `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.
      → `chore(env): add Google OAuth env vars`
- [ ] Add Google OAuth library to `package.json` (no test — dep bump).
      → `chore(deps): add google-auth-library`
```

**Rules:**

- **Every item is a `- [ ]` checkbox.** No markdown tables, no plain bullets, no numbered lists. If `flow:develop` can't toggle it from `[ ]` to `[x]`, it doesn't belong here.
- **One-line behavior, then one of: pseudo-code test *or* a small Mermaid diagram** — never the verbose Given-When-Then prose, never both forms at once.
- One behavior per checkbox. Don't bundle.
- **Commit hint(s) on every task.** → `<type>(<scope>): <subject>` lines, one per planned commit (arrow outside the backticks). Follow `../../references/commit-conventions.md`.
- Mention "non-TDD" explicitly for config/dep/rename tasks — see `../../references/tdd-policy.md`.
- The order roughly follows implementation order, but the develop skill picks the next unchecked task and decides if dependencies require reordering.
- Sub-tasks are allowed (nested checkboxes) when a behavior splits naturally into validation + happy-path + error-path. Keep nesting one level deep.

## Workflow

1. **Read** `prepare.md` and `research.md` (if it exists). Don't restart research — build on it.
2. **Read** the user's task goal in their words. If anything is ambiguous, ask one or two focused questions. Don't ask 10 questions; the user reads the plan before develop, and review concentrates on the result.
3. **Decide** whether to brainstorm (see "Multi-LLM brainstorming" above for the trigger criteria). If yes, generate options across the lenses (optionally a brief for external agents), synthesize `brainstorm.md`, and resolve any "open questions for the user" before drafting.
4. **Choose** the approach. Use `research.md` candidate approaches and `brainstorm.md`
   divergence as inputs. For size M/L, if two viable approaches remain close or the
   choice changes user-visible scope, pause once and ask the user to choose before
   writing the final plan.
5. **Draft** plan.md. Drafting order can differ from document order: it is normal to write Approach first (clarifying the shape often sharpens the Goal), then sketch the **Change map** (this surfaces missed files and forces the approach to be concrete), then Goal, Risks, Rollout, and finally Non-goals once scope boundaries are visible. The rendered document leads with Goal → Decision context → Approach → Change map (두괄식, then file surface) and pushes Non-goals near the end as boundary context. If `brainstorm.md` exists, consult it as you go — convergence informs assumptions, divergence informs explicit decisions in Alternatives considered and Approach.
6. **Draft** tasks.md. Each task should look like something you could write a failing test for, except the explicit "non-TDD" ones. Add the commit hint(s) inline as you go — drafting the hint forces you to confirm the commit boundary fits one behavior. Cross-check that every entry in `## Change map` is touched by at least one task.
7. **Self-review** plan.md and tasks.md using the checklist above. Fix gaps inline before presenting them.
8. **Dispatch Korean translation.** Generate `artifacts/plan.ko.md` and `artifacts/tasks.ko.md` (see "Korean translation dispatch" below).
9. **Show** both files to the user for a quick read, then proceed to `flow:develop` on go-ahead. Keep this fast — the plan is short and visual; deep review happens on the result.

## Korean translation dispatch

After self-review passes, generate Korean translations of `plan.md` and `tasks.md` so the user can skim the plan quickly in Korean. Translations live under `artifacts/` (filenames `plan.ko.md` / `tasks.ko.md`) — they are user-facing reading copies, not LLM-facing artifacts.

### Dispatch method

**Primary — Sonnet subagent.** Spawn a Claude Code Task agent with `model: sonnet`. The subagent reads `plan.md` and `tasks.md` from the task directory and writes:

- `artifacts/plan.ko.md`
- `artifacts/tasks.ko.md`

Prompt the subagent to preserve all structural formatting (headings, checkboxes, code blocks, Mermaid diagrams) and translate only the prose. The subagent writes the files directly via its Write tool.

**Alternative — GLM 5.1 via opencode CLI.** If the user requests a cost-efficient translation (e.g., "GLM으로 번역해줘"), use `opencode run -m opencode-go/glm-5.1` with the file-write contract instead. Pipe the prompt via stdin per `references/multi-llm.md`. This is opt-in only — do not default to it.

### Translation frontmatter

Each translation file carries frontmatter for agentic search:

```yaml
---
title: "Plan (Korean) — <task name>"
type: plan-translation          # or tasks-translation
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
size: <S|M|L>
parent: ../plan.md              # or ../tasks.md
source: ../plan.md              # the English file this translates
language: ko
translator: sonnet              # or glm-5.1
---
```

### Version management

If the plan is **substantively revised** after the user has seen it, move the old versions into `artifacts/` with a `.v<N>` suffix before writing the new one:

- `plan.md` → `artifacts/plan.v<N>.md`
- `artifacts/plan.ko.md` → `artifacts/plan.v<N>.ko.md`

Then re-dispatch Korean translation for the new `plan.md` using the same method above. Same logic for `tasks.md` / `tasks.ko.md`. With lightweight fast-iteration most revisions are small in-place edits — only version when the change is large enough that the old plan is worth keeping.

### When to skip

Size S plans (20-50 lines, 1-3 tasks) — skip translation unless the user explicitly asks. The plan is short enough to scan in English.

## Sizing decisions

Treat these as ceilings, not targets — keep plans as short as the work allows.

- **Size S** — plan.md 20-50 lines. tasks.md 1-3 checkboxes (each with its commit hint). Skip phases and brainstorming. Change map can collapse into a sentence or be omitted when the touched files are obvious from `tasks.md`.
- **Size M** — plan.md ~100-200 lines, ideally less. tasks.md ~5-15 checkboxes. Lead `## Approach` with a Mermaid diagram. **Change map mandatory** (New / Modified / Deleted, one bullet per file). Include meaningful alternatives, failure modes, and test strategy. Brainstorm when cross-module / security-sensitive / public-surface (else skip).
- **Size L** — plan.md + per-phase files; keep each phase file lean. tasks.md scoped by phase. Mermaid diagram(s) in `## Approach`. **Change map mandatory and grouped by area/phase** when the change spans >10 files. Include decision context, alternatives, failure-mode registry, rollout/rollback posture, and test strategy. Brainstorming expected (incl. security lens). Even at L, prefer splitting into smaller sub-tasks/sub-issues over one giant plan.

## Reference

- Directory layout: `../../references/directory-structure.md`
- Frontmatter schema: `../../references/frontmatter.md`
- TDD policy (what gets tests, what doesn't): `../../references/tdd-policy.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
- Mermaid diagram types & skeletons: `../../references/mermaid.md`
- Multi-LLM brief model (used by brainstorming): `../../references/multi-llm.md`
- Model registry (research tier + external agents): `../../references/models.md`
