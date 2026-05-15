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

All written under `<worktree>/.planning/<date>-<task>/`:

- **`plan.md`** — approach, scope, architecture decisions, rollout. ~500 lines max for the whole thing (including any phase sub-plans). If it grows beyond that, split into `plan-phase-1.md`, `plan-phase-2.md` and let `plan.md` become a short index.
- **`tasks.md`** — Given-When-Then checkbox list, the single source of truth for progress during develop.
- **`brainstorm.md`** — *conditional.* Multi-LLM brainstorming synthesis, written before `plan.md` when scope warrants (see "Multi-LLM brainstorming" below). Raw per-model outputs go under `brainstorms/`.

All authored docs are **English** (any coding agent picks them up). Add a `## Korean summary (요약)` at the bottom of `plan.md` if the user wants to skim it quickly.

## Multi-LLM brainstorming (run when scope warrants)

Before drafting `plan.md`, run a multi-LLM brainstorming round when the change is large enough or cross-cutting enough that diverse perspectives meaningfully sharpen the approach. The point is to surface **architecture options, hidden risks, and security/correctness angles *before* the planner commits to a shape** — not to second-guess the plan afterward (that's `flow:plan-review`).

### When to run

- **Size L** — always run. Large changes benefit most from multi-angle exploration.
- **Size M** — run when any of:
  - The change touches **multiple modules** (cross-module impact flagged in `meta.md` or surfaced from `research.md`).
  - **Security-sensitive surface**: auth, payments, PII, cryptography, file uploads, anything user-controlled landing in a privileged context.
  - **Public surface area** (a new external API endpoint, a published SDK, a webhook contract).
  - The user explicitly asks for "options" / "alternatives" / "다각도로 보자" before planning.
- **Size S** — skip. One perspective is fine for an atomic edit.

If unsure for an M task, ask the user one short question. Default-no for plain M, default-yes for L.

### Provider roles

Two providers minimum (the `references/multi-llm.md` ≥2 quorum); three for size L. Each model gets a **focused lens** so outputs are differentiated, not duplicated.

- **`gemini-3.1-pro` — Architecture & alternatives.** Surface 2–3 distinct architectural shapes for the change. Name load-bearing tradeoffs (cost / blast radius / reversibility). Bring ecosystem analogues.
- **`opencode-go/kimi-k2.6` — Risk & failure modes.** Enumerate what could go wrong: race conditions, partial states, rollback paths, observability gaps, regressions in adjacent modules. Be concrete.
- **`opencode-go/deepseek-v4-pro` — Security & correctness** *(size L, or M with security-sensitive surface)*. Threat-model the change: auth/authz, injection, data exposure, dependency surface, secrets handling.

Model IDs come from `references/models.md` — if they move, edit there, not here.

### Idempotency precondition

Before dispatching anything, check whether the brainstorm has already run:

```bash
BRAINSTORM=.planning/<date>-<task>/brainstorm.md
if [[ -f "$BRAINSTORM" ]] && grep -q '^status: active' "$BRAINSTORM"; then
  echo "brainstorm.md already exists (status: active)"
fi
```

If it does, **do not silently re-dispatch.** Ask the user: (a) keep the existing synthesis and skip the sub-phase, (b) regenerate (the existing `brainstorm.md` and `brainstorms/` files are moved to `brainstorm.v<N>.md` / `brainstorms.v<N>/`, mirroring the `plan.v<N>.md` versioning convention), or (c) abort. The most common path after an interrupted session is (a) — re-running the brainstorm doubles cost and clobbers the audit trail.

### How to dispatch

Follow the full dispatch + verification + quorum pattern in `references/multi-llm.md`. Key points specific to brainstorming:

- **File-write contract.** Each contributor uses its native Write tool to write its review to a specific absolute path. The orchestrator captures stdout to a **runlog** file (diagnostic only — not the review). See `references/multi-llm.md` "Dispatch contract."
- **Sentinel.** Every contributor file must end with `<!-- council-flow:review-complete -->`. Absent sentinel = treat as failed even if file size looks reasonable.
- **Heartbeat.** Run `watch_review` (defined in `references/multi-llm.md`) in parallel with each dispatch so progress is visible at 1-minute resolution. A dispatch without a heartbeat is indistinguishable from a hung one for 10+ minutes.

```bash
mkdir -p .planning/<date>-<task>/brainstorms

REVIEW_ARCH=.planning/<date>-<task>/brainstorms/architecture-gemini.md
RUNLOG_ARCH=.planning/<date>-<task>/brainstorms/_runlog-architecture-gemini.txt

( timeout 600 gemini --model gemini-3.1-pro-preview --yolo --skip-trust \
    --prompt "$(cat <<PROMPT
You are a non-interactive reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the task brief at <abs>/meta.md and (if it exists) the research at <abs>/research.md.
2. Write your brainstorm using the Write tool to: $REVIEW_ARCH
3. The LAST LINE of the file MUST be exactly:
     <!-- council-flow:review-complete -->
4. Print only: "wrote architecture-gemini.md"

Your lens: ARCHITECTURE & ALTERNATIVES.
- Propose 2–3 distinct architectural shapes for this change.
- For each: the shape in 2 sentences, and load-bearing tradeoffs (cost / blast radius / reversibility).
- Name relevant ecosystem analogues.
- Surface non-obvious design constraints the planner should know.

Output format inside the file (Markdown, no preamble):
## Option A — <name>
- Shape: ...
- Tradeoffs: ...
## Option B — <name>
...
## Constraints surfaced
- ...
PROMPT
)" > "$RUNLOG_ARCH" 2> "$RUNLOG_ARCH.stderr"; \
  echo $? > "$RUNLOG_ARCH.exit" ) || true &

# Run watch_review (from multi-llm.md) in parallel so progress is visible at 1-min resolution.
watch_review "$REVIEW_ARCH" 25 &

# Same wrapping for risk lens (kimi) — file-write to brainstorms/risk-kimi.md
# Same wrapping for security lens (deepseek) — size L or security-sensitive only

wait
```

Apply the full post-call verification (exit code, non-empty, **sentinel present**, **structural content present**, no failure signature) and quorum policy from `multi-llm.md`. If only one contributor succeeds, stop and ask the user (re-auth, swap, or proceed labeled "single-perspective").

### Synthesis — `brainstorm.md`

Read each raw output **once**, extract load-bearing ideas, and write a single English `brainstorm.md` at `.planning/<date>-<task>/brainstorm.md`. This is what the planner consults while drafting `plan.md`.

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
parent: ./meta.md
related:
  - ./research.md (if exists)
  - ./brainstorms/architecture-gemini.md
  - ./brainstorms/risk-kimi.md
contributors:
  - gemini-3.1-pro
  - opencode-go/kimi-k2.6
missing_contributors: []
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

- **Don't run brainstorming for size S.** It's noise.
- **Don't paste raw model output into the conversation.** Files only — that's the whole point of `multi-llm.md`.
- **Don't let the brainstorm become the plan.** The planner still drafts `plan.md`. Brainstorm is option-generation; plan is decision.
- **Don't run brainstorm *and* plan-review on the same plan as a default.** They serve different stages — brainstorm before drafting, plan-review after. Doubling up is justified only when plan-review surfaces re-architecting questions that need fresh brainstorming.

### Future refactor (open question)

A self-brainstorm of this section by `gemini-3.1-pro-preview` recommended an alternative shape: **extract brainstorming into a dedicated explore phase between `flow:research` and `flow:plan`**, with a hard user checkpoint after `brainstorm.md` lands. The argument is context isolation (the planner LLM never reads raw contributor output) and reversibility (the user can steer between option-generation and plan-drafting). The current sub-phase shape is a pragmatic compromise; revisit if Option A produces planner drift or if users keep wanting to weigh in between brainstorm and plan.

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

When the change has non-trivial control flow, message passing, or state
transitions, include **at least one Mermaid sequence (or flow) diagram** here,
rendered as a fenced ` ```mermaid ` code block so downstream renderers (GitHub,
PR review tools, docs sites) pick it up correctly. Multiple diagrams are fine
when distinct flows do not fit into one — size L plans with per-phase flows
typically need more than one. Diagrams are a faster read than prose for "who
calls what, in what order." Skip the diagram when the shape is "edit a function,
add a test" — diagrams for trivial flows are noise.

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

## Korean summary (요약)
3-5 bullets, 사용자 빠른 확인용.
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

Each TDD task carries an inline **commit hint** showing the expected commit boundary — typically one `test(...)` followed by one `feat(...)` (or `fix(...)`/`refactor(...)`). Non-TDD tasks carry a single hint.

Hints are **advisory and human-/reviewer-readable only**. `flow:develop` does not currently parse `→ ...` lines; it still derives commit messages from the task body and `references/commit-conventions.md`. Treat hints as a planner-side aid for catching badly-scoped tasks (a behavior that needs three commits probably needs three checkboxes) and as a reviewer signal for what the planned commit shape was — not as a contract the develop skill enforces. A future PR may wire `flow:develop` to read and honor hints (and to record deviations in the commit body); until then, do not rely on that behavior.

```markdown
# Tasks — <task name>

## Phase 1 (optional grouping)

- [ ] **Given** a user without a Google account linked,
      **when** they click "Sign in with Google",
      **then** they are redirected to Google's OAuth consent screen.
      → `test(auth): redirect to Google consent on sign-in click`
      → `feat(auth): wire Google OAuth redirect`

- [ ] **Given** Google returns a valid auth code,
      **when** the callback handler processes it,
      **then** a session token is issued and the user lands on `/dashboard`.
      → `test(auth): issue session and redirect on valid Google callback`
      → `feat(auth): implement Google callback handler`

- [ ] **Given** Google returns an error or the user denies consent,
      **when** the callback handler processes it,
      **then** the user sees a non-technical error message and stays on `/login`.
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
- One behavior per checkbox. Don't bundle.
- **Commit hint(s) on every task.** → `<type>(<scope>): <subject>` lines under the GWT body, one per planned commit (arrow outside the backticks, matching the example block above). Follow `../../references/commit-conventions.md` for type/scope vocabulary.
- Mention "non-TDD" explicitly for config/dep/rename tasks — see `../../references/tdd-policy.md` for which tasks skip TDD.
- The order roughly follows implementation order, but the develop skill picks the next unchecked task and decides if dependencies require reordering.
- Sub-tasks are allowed (nested checkboxes) when a single behavior splits naturally into validation + happy-path + error-path. Keep nesting one level deep.

## Workflow

1. **Read** `meta.md` and `research.md` (if it exists). Don't restart research — build on it.
2. **Read** the user's task goal in their words. If anything is ambiguous, ask one or two focused questions. Don't ask 10 questions; the plan-review step will surface anything you miss.
3. **Decide** whether to brainstorm (see "Multi-LLM brainstorming" above for the trigger criteria). If yes, dispatch providers, synthesize `brainstorm.md`, and resolve any "open questions for the user" before drafting.
4. **Choose** the approach. Use `research.md` candidate approaches and `brainstorm.md`
   divergence as inputs. For size M/L, if two viable approaches remain close or the
   choice changes user-visible scope, pause once and ask the user to choose before
   writing the final plan.
5. **Draft** plan.md. Drafting order can differ from document order: it is normal to write Approach first (clarifying the shape often sharpens the Goal), then sketch the **Change map** (this surfaces missed files and forces the approach to be concrete), then Goal, Risks, Rollout, and finally Non-goals once scope boundaries are visible. The rendered document leads with Goal → Decision context → Approach → Change map (두괄식, then file surface) and pushes Non-goals near the end as boundary context. If `brainstorm.md` exists, consult it as you go — convergence informs assumptions, divergence informs explicit decisions in Alternatives considered and Approach.
6. **Draft** tasks.md. Each task should look like something you could write a failing test for, except the explicit "non-TDD" ones. Add the commit hint(s) inline as you go — drafting the hint forces you to confirm the commit boundary fits one behavior. Cross-check that every entry in `## Change map` is touched by at least one task.
7. **Self-review** plan.md and tasks.md using the checklist above. Fix gaps inline before presenting them.
8. **Show** both files to the user for a quick review. Make any obvious edits before invoking `flow:plan-review` (if size warrants).

## Sizing decisions

- **Size S** — plan.md can be 20-50 lines. tasks.md may have just 1-3 checkboxes (each with its commit hint). Skip phases, skip brainstorming, skip `flow:plan-review`. Change map can collapse into a sentence or be omitted when the touched files are obvious from `tasks.md`.
- **Size M** — plan.md ~100-300 lines. tasks.md ~5-15 checkboxes. Include meaningful alternatives, failure modes, and test strategy. **Change map mandatory** (New / Modified / Deleted, one bullet per file). Add a Mermaid sequence/flow diagram in `## Approach` when message passing or non-trivial control flow is in scope. Brainstorming when cross-module / security-sensitive / public-surface (else skip). Plan-review optional, default to yes when brainstorming ran or external API integration is involved.
- **Size L** — plan.md ~300-500 lines + per-phase files. tasks.md scoped by phase. Include explicit decision context, alternatives, failure-mode registry, rollout/rollback posture, and test strategy. **Change map mandatory and grouped by area/phase** when the change spans >10 files; each phase file repeats its own scoped Change map. Mermaid diagram(s) expected in `## Approach`. Brainstorming mandatory (3 providers including security lens). Plan-review mandatory.

## Reference

- Directory layout: `../../references/directory-structure.md`
- Frontmatter schema: `../../references/frontmatter.md`
- TDD policy (what gets tests, what doesn't): `../../references/tdd-policy.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
- Multi-LLM dispatch & quorum (used by brainstorming): `../../references/multi-llm.md`
- Model registry (lenses + IDs): `../../references/models.md`
