---
name: orchestrate
description: Run the full flow workflow end-to-end — kickoff (framing + setup) → optional research → plan (with optional multi-LLM brainstorming) → develop → deploy → optional cleanup — based on a single task goal from the user. Use this when the user wants to hand off a complete task and let the workflow run, rather than driving each step manually. Skips research and brainstorming automatically for size S tasks; runs the full pipeline for size L. Even when the user just says "build me X", consider this skill if the task warrants the full discipline.
---

# flow:orchestrate — End-to-end workflow runner

Orchestrate is a thin sequencer. It does not reimplement any of the individual skills — it invokes them in order, with skip logic based on size and explicit user signals.

## Inputs

1. **Task goal** — what the user wants built, in their words.
2. **Type hint** (optional) — feature / fix / chore / refactor / docs. Inferred from the goal if not given.
3. **Explicit skips** (optional) — e.g., "skip research", "skip the code-review brief at the end". Honor without arguing.

## The sequence

```
0. flow:kickoff           [front door — framing AND setup in one step]
   └── writes brief.md (GOAL, acceptance criteria + verification, scope, hypothesis,
       working rules), sets category + size, optionally posts a Korean GitHub Issue
   └── then scaffolds: worktree, branch, .planning/, prepare.md (with size estimate)
   └── if oversized (GOAL with >3 independent parts / separable areas): splits into a
       parent + sub-issues. Then orchestrate runs the loop below on the FIRST sub-issue
       only; each remaining sub-issue is its own kickoff→…→deploy run later.

   (Fast lane: flow:quick is the alternate entry for a user-asserted trivial task — it
    classifies green/yellow/red and, on green, jumps straight to develop. See flow:quick.)

1. flow:research          [skip if size = S, or user opted out]
   └── writes research.md

2. flow:plan              [always]
   └── (sub-phase) multi-LLM brainstorm if size = L, or size = M with cross-module /
       security-sensitive / public-surface flag → writes brainstorm.md + artifacts/brainstorm-*.md
   └── writes plan.md, tasks.md

3. — Checkpoint with user —
   Show plan.md (or artifacts/plan.ko.md) and tasks.md. The user reads the
   lightweight plan quickly and gives go/no-go. (No plan-review step — review
   concentrates on the result, not the plan.)

4. flow:develop           [after user confirms]
   └── executes tasks.md, atomic commits, all checkboxes filled

5. flow:deploy            [as a separate session — see below]
   └── pushes, opens Korean PR, then asks (default yes) and on confirm runs
       flow:code-review-brief; the user then runs their own agent(s) on the brief
```

## Default tier map — apply it, don't ask for it

The orchestrator (frontier model, e.g. Opus) is the **team lead**: it analyzes the task, decomposes large work into phases, delegates each phase to a cost-appropriate subagent, and reviews what comes back. Apply this tier map **by default, every session** — the user should never have to restate it (see `../../references/models.md`):

- **orchestrate / plan** → **Opus** (this session, or `flow:planner` in a fresh context). Synthesis and trade-offs stay on the frontier.
- **research** → **Sonnet** (`flow:researcher`), or **Haiku** for a trivial single-fact lookup. Fanned out, one per area.
- **develop** → **Sonnet** (`flow:developer`). Mechanical TDD build off the frontier.
- **code review** → **Fable** (`flow:reviewer`), **Opus** for high-stakes/cross-repo, or hand to an external agent (`codex:codex-rescue` / `codex:review`).
- **browser QA** *(frontend only)* → **Sonnet** (`flow:browser-tester`).
- **React quality** *(frontend only)* → **Fable / Opus** (`flow:react-reviewer`).

Delegation is a cost/context optimization, not a hard rule: for size S tasks, running a phase inline is fine. The user checkpoint before develop and the separate deploy session are unchanged regardless of delegation.

## Run non-overlapping work in parallel

The orchestrator is not just a sequencer — it runs independent work **concurrently**. Two rules:

1. **Independent tasks/issues run in parallel.** When sub-issues or tasks touch **non-overlapping files**, dispatch their subagents at the same time rather than one after another. If two would edit the same files, serialize them (or isolate each in its own worktree). When unsure whether they overlap, check the change map before parallelizing.
2. **The review lane is parallel.** After deploy opens the PR, the review is a **lane, not a step**: run **code review** (`flow:reviewer` / external agent), **browser QA** (`flow:browser-tester`, frontend only), and **React quality** (`flow:react-reviewer`, frontend only) **at the same time**. They inspect the same diff from different angles and don't depend on each other.

While a subagent runs, keep the orchestrator busy with the next independent piece (e.g. plan the next phase while the current one builds) instead of blocking.

## Supervise and rework — the orchestrator owns quality

The orchestrator does not blindly accept subagent output. Every delegated phase runs a supervision loop:

1. **Instruct** — give the subagent a scoped task and the acceptance signal.
2. **Review the result** — read the returned digest/diff/report against the brief's acceptance criteria and the plan. Did it do what was asked? Any gap, drift, or unverified claim?
3. **Decide**:
   - **Accept** → move on.
   - **Rework** → send it back with specific corrections (this is normal, not failure).
   - **Escalate** → if it's blocked or the approach is wrong, stop and bring it to the user.

For review-lane findings: **small issues → fix in place** before merge; **large issues → a follow-up PR/issue** rather than blocking the current one. Keep off-critical-path investigations in their own subagent so the orchestrator's context stays clean — pull back only the conclusion.

## Rate-limit / tier fallback

Long parallel runs hit model rate limits (weekly / session / external-CLI quota). Decide the fallback **before** dispatching a big batch, so a mid-run cutoff doesn't strand the work:

- If a tier is exhausted, fall back to the next available one (e.g. external `codex:*` review → `flow:reviewer` on Fable/Sonnet; Opus plan → Sonnet) and note the downgrade to the user.
- For a long queue, prefer resumable checkpoints (tasks.md progress, an issue comment handoff) over one unbroken run, so a new session can pick up.

## Size-based skip logic

| Step | size = S | size = M | size = L |
|---|---|---|---|
| kickoff (framing + setup) | yes | yes | yes |
| research | skip | ask | yes |
| plan (always) | yes | yes | yes |
| ↳ brainstorm sub-phase | skip | ask (default yes if cross-module / security / public-surface) | yes |
| user checkpoint | skip | yes | yes |
| develop | yes | yes | yes |
| deploy | yes | yes | yes |

"Ask" means: surface the decision to the user with the size-based default pre-selected. Don't bounce every step.

## The user checkpoint before develop

This is the only mandatory pause in orchestrate. Show the user:

1. The plan (`plan.md`, or `artifacts/plan.ko.md` for a Korean read)
2. The tasks.md checkbox list
3. Anything that came up as an open question

Wait for an explicit go-ahead before invoking `flow:develop`. The reason for the pause: develop runs for a while and produces commits — the user should sign off on what is about to be built. After the checkpoint, develop runs without further interruption unless it hits a blocker.

## Deploy as a separate session

Deploy intentionally runs as its own session. Orchestrate's job at the end of develop is:

1. Confirm `tasks.md` is fully checked.
2. Confirm tests pass.
3. Tell the user: "Develop complete. Start a new session and invoke `flow:deploy` to open the PR and write the code-review brief."

Do **not** auto-invoke deploy inside orchestrate. The reasons:

- Develop's session has the implementation context loaded; deploy benefits from a fresh context so the PR and the review brief reflect a clean final diff.
- The user usually wants to look at the diff themselves before opening the PR.
- Token cost — keeping deploy in a fresh session is cheaper than dragging develop's history along.

## After the review (recommend-only, not part of the sequence)

Two recommend-only steps follow the sequence. Orchestrate **never auto-invokes** either — mention them as next steps, each usually run in its own session:

- **`flow:review-triage`** — once reviewers have left feedback on the PR, pull all the comments, triage validity + priority, plan fixes, and apply them after sign-off.
- **`flow:cleanup`** — once the PR is merged, tear down the task's transient resources: kill the dev server / e2e / Playwright processes, remove the worktree, prune stale preview deployments.

If the user objects and explicitly says "just run deploy too", you may invoke it inline, but mention the trade-off.

## Failure handling

Each sub-skill should report its outcome. If any step fails:

- **kickoff setup fails** (branch exists, dirty tree, etc.) — surface the error, ask the user.
- **research / plan fail** — usually recoverable, show what went wrong and offer to retry.
- **develop fails mid-implementation** — stop. The tasks.md state shows progress; the user can resume by invoking `flow:develop` directly when they want to continue.

Do not retry silently. Orchestrate is a sequencer, not a self-healing pipeline.

## Reference

Each individual skill is the source of truth for its own behavior. This skill only sequences them:

- `flow:kickoff`
- `flow:research`
- `flow:plan`
- `flow:develop`
- `flow:deploy`
