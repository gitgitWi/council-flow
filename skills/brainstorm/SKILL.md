---
name: brainstorm
description: Run a multi-LLM brainstorming round and synthesize a single `brainstorm.md` (plus per-model raw outputs under `brainstorms/`) surfacing architecture options, hidden risks, and security/correctness angles for an upcoming change. Use this whenever the user wants to weigh "options", "alternatives", "다각도로 보자", a "second opinion before planning", or whenever a non-trivial change benefits from diverse perspectives BEFORE the planner commits to a shape. Invoked directly by the user (`/flow:brainstorm`), or as an optional sub-phase from `flow:research` / `flow:plan`. Runs without any prior `.planning/` directory — accepts an inline task brief when needed.
---

# flow:brainstorm — Multi-LLM option-generation

Brainstorm is **option-generation, not decision-making**. The point is to surface
architecture shapes, risks, and security angles BEFORE the planner commits — not
to second-guess a plan after it lands (that's `flow:plan-review`). The output is
`brainstorm.md`, a single synthesized file the planner consults while drafting
`plan.md`. Raw per-model outputs live under `brainstorms/` for audit; the planner
should never read them directly.

## When to run

This skill is callable in three contexts; the triggers differ.

### As a sub-phase of `flow:plan` (most common)

- **Size L** — always run.
- **Size M** — run when any of:
  - The change touches **multiple modules** (cross-module impact flagged in
    `meta.md` or surfaced from `research.md`).
  - **Security-sensitive surface**: auth, payments, PII, cryptography, file
    uploads, anything user-controlled landing in a privileged context.
  - **Public surface area** (a new external API endpoint, a published SDK, a
    webhook contract).
  - The user explicitly asks for "options" / "alternatives" / "다각도로 보자"
    before planning.
- **Size S** — skip. One perspective is fine for an atomic edit.

If unsure for an M task, ask the user one short question. Default-no for plain M,
default-yes for L.

### As a sub-phase of `flow:research`

Research suggests brainstorming when its *Candidate approaches* list has 3+
viable shapes with comparable risk, or when the user explicitly asks for
option-generation. Research itself does not auto-dispatch; the suggestion lands
in `research.md` and the user (or `flow:orchestrate`) decides.

### Standalone (`/flow:brainstorm`, no prior pipeline)

The user wants to weigh options on a sketch without committing to a plan yet. No
`.planning/` dir exists. The skill accepts a one-paragraph **inline task brief**
from the user, creates an ad-hoc working directory (see *Input precedence*
below), and runs the same dispatch + synthesis flow.

## Input precedence

Resolved at the start of every invocation, in this order:

1. **`research.md` + `meta.md` exist** in the current
   `.planning/<date>-<task>/`. Richest context — read both, dispatch
   contributors with both paths.
2. **Only `meta.md` exists.** Same as today's plan-internal flow — dispatch
   contributors with `meta.md` only.
3. **Neither exists** (standalone invocation, no `.planning/` dir at all).
   Prompt the user inline:
   - "I don't see a `.planning/` task directory. Give me a one-paragraph task
     brief — what change are you weighing options on?"
   - Derive a **slug** from the brief: first 4–6 content words, kebab-cased,
     stopwords (`a`, `the`, `for`, `to`, `with`, `and`, `or`) stripped, ASCII
     only. Example brief: "Should we move auth tokens out of localStorage into
     httpOnly cookies?" → `auth-tokens-localstorage-cookies`.
   - Create
     `<repo-root>/.planning/<yyyy-mm-dd>-brainstorm-<slug>/` (today's date,
     local timezone). If the directory already exists for the same date+slug,
     append `-2`, `-3` until unique. This mirrors the existing
     `.planning/<yyyy-mm-dd>-pr<N>-review/` ad-hoc variant
     (`../../references/directory-structure.md#naming-rules`).
   - Write a minimal `meta.md` to that directory with `type: meta`,
     `size: M` (default — bump to L if the brief clearly warrants), and the
     brief copied verbatim under `goal:`. This becomes the input contributors
     read.

`$TASK_DIR` below refers to whichever directory was resolved.

## Idempotency precondition

Before dispatching anything, check whether the brainstorm has already run:

```bash
BRAINSTORM="$TASK_DIR/brainstorm.md"
if [[ -f "$BRAINSTORM" ]] && grep -q '^status: active' "$BRAINSTORM"; then
  echo "brainstorm.md already exists (status: active)"
fi
```

If it does, **do not silently re-dispatch.** Ask the user: (a) keep the
existing synthesis and exit, (b) regenerate (the existing `brainstorm.md` and
`brainstorms/` files are moved to `brainstorm.v<N>.md` / `brainstorms.v<N>/`,
mirroring the `plan.v<N>.md` versioning convention), or (c) abort. The most
common path after an interrupted session is (a) — re-running the brainstorm
doubles cost and clobbers the audit trail.

## Provider roles

Two providers minimum (the `../../references/multi-llm.md` ≥2 quorum); three
when size is L or the user requested a security lens. Each model gets a
**focused lens** so outputs are differentiated, not duplicated.

- **`gemini-3.1-pro` — Architecture & alternatives.** Surface 2–3 distinct
  architectural shapes for the change. Name load-bearing tradeoffs (cost /
  blast radius / reversibility). Bring ecosystem analogues.
- **`opencode-go/kimi-k2.6` — Risk & failure modes.** Enumerate what could go
  wrong: race conditions, partial states, rollback paths, observability gaps,
  regressions in adjacent modules. Be concrete.
- **`opencode-go/deepseek-v4-pro` — Security & correctness** *(size L, or M
  with security-sensitive surface)*. Threat-model the change: auth/authz,
  injection, data exposure, dependency surface, secrets handling.

Model IDs come from `../../references/models.md` — if they move, edit there,
not here.

## How to dispatch

Follow the full dispatch + verification + quorum pattern in
`../../references/multi-llm.md`. Key points specific to brainstorming:

- **File-write contract.** Each contributor uses its native Write tool to
  write its output to a specific absolute path. The orchestrator captures
  stdout to a **runlog** file (diagnostic only — not the review). See
  `../../references/multi-llm.md` "Dispatch contract."
- **Sentinel.** Every contributor file must end with
  `<!-- council-flow:review-complete -->`. Absent sentinel = treat as failed
  even if file size looks reasonable.
- **Heartbeat.** Run `watch_review` (defined in `../../references/multi-llm.md`)
  in parallel with each dispatch so progress is visible at 1-minute
  resolution. A dispatch without a heartbeat is indistinguishable from a hung
  one for 10+ minutes.

```bash
mkdir -p "$TASK_DIR/brainstorms"

REVIEW_ARCH="$TASK_DIR/brainstorms/architecture-gemini.md"
RUNLOG_ARCH="$TASK_DIR/brainstorms/_runlog-architecture-gemini.txt"

# Build the read-list for the contributor prompt. research.md is optional.
READ_LIST="$TASK_DIR/meta.md"
[[ -f "$TASK_DIR/research.md" ]] && READ_LIST="$READ_LIST and $TASK_DIR/research.md"

( timeout 600 gemini --model gemini-3.1-pro-preview --yolo --skip-trust \
    --prompt "$(cat <<PROMPT
You are a non-interactive reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the task brief at: $READ_LIST
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

Apply the full post-call verification (exit code, non-empty, **sentinel
present**, **structural content present**, no failure signature) and quorum
policy from `../../references/multi-llm.md`. If only one contributor
succeeds, stop and ask the user (re-auth, swap, or proceed labeled
"single-perspective").

## Synthesis — `brainstorm.md`

Read each raw output **once**, extract load-bearing ideas, and write a single
English `brainstorm.md` at `$TASK_DIR/brainstorm.md`. This is what the planner
(or the user, in standalone mode) consults next.

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

## What NOT to do

- **Don't run brainstorming for size S.** It's noise.
- **Don't paste raw model output into the conversation.** Files only — that's
  the whole point of `../../references/multi-llm.md`.
- **Don't let the brainstorm become the plan.** The planner still drafts
  `plan.md`. Brainstorm is option-generation; plan is decision. In standalone
  mode, `brainstorm.md` is the final artifact — but it still presents options,
  not a chosen direction.
- **Don't run brainstorm *and* `flow:plan-review` on the same plan as a
  default.** They serve different stages — brainstorm before drafting,
  plan-review after. Doubling up is justified only when plan-review surfaces
  re-architecting questions that need fresh brainstorming.
- **Don't auto-dispatch from `flow:research`.** Research *suggests*; the user
  or orchestrate decides.

## Handoff

- **Sub-phase mode**: when invoked from `flow:plan` or `flow:research`, return
  to the caller after `brainstorm.md` is written. The caller continues from
  where it paused (typically: planner reads `brainstorm.md` and drafts
  `plan.md`).
- **Standalone mode**: print the path to `brainstorm.md` and a one-line summary
  of the divergence section. The user decides whether to next invoke
  `flow:prep` + `flow:plan`, iterate on the brief, or stop here.

## Reference

- Multi-LLM dispatch & quorum: `../../references/multi-llm.md`
- Model registry (lenses + IDs): `../../references/models.md`
- Directory layout (including `.planning/<date>-brainstorm-<slug>/` variant):
  `../../references/directory-structure.md`
- Frontmatter schema (`brainstorm` + `brainstorm-contribution` types):
  `../../references/frontmatter.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
