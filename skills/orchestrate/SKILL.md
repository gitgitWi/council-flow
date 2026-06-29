---
name: orchestrate
description: Run the full flow workflow end-to-end — kickoff → prep → optional research → plan (with optional multi-LLM brainstorming) → develop → deploy — based on a single task goal from the user. Use this when the user wants to hand off a complete task and let the workflow run, rather than driving each step manually. Skips research and brainstorming automatically for size S tasks; runs the full pipeline for size L. Even when the user just says "build me X", consider this skill if the task warrants the full discipline.
---

# flow:orchestrate — End-to-end workflow runner

Orchestrate is a thin sequencer. It does not reimplement any of the individual skills — it invokes them in order, with skip logic based on size and explicit user signals.

## Inputs

1. **Task goal** — what the user wants built, in their words.
2. **Type hint** (optional) — feature / fix / chore / refactor / docs. Inferred from the goal if not given.
3. **Explicit skips** (optional) — e.g., "skip research", "skip the code-review brief at the end". Honor without arguing.

## The sequence

```
0. flow:kickoff           [front door — frame the task before any setup]
   └── writes brief.md (GOAL, acceptance criteria + verification, scope, hypothesis,
       working rules), sets category + size, optionally posts a Korean GitHub Issue
   └── if oversized (GOAL with >3 independent parts / separable areas): splits into a
       parent + sub-issues. Then orchestrate runs the loop below on the FIRST sub-issue
       only; each remaining sub-issue is its own kickoff→…→deploy run later.

1. flow:prep
   └── creates worktree, branch, .planning/, prepare.md (with size estimate)

2. flow:research          [skip if size = S, or user opted out]
   └── writes research.md

3. flow:plan              [always]
   └── (sub-phase) multi-LLM brainstorm if size = L, or size = M with cross-module /
       security-sensitive / public-surface flag → writes brainstorm.md + artifacts/brainstorm-*.md
   └── writes plan.md, tasks.md

4. — Checkpoint with user —
   Show plan.md (or artifacts/plan.ko.md) and tasks.md. The user reads the
   lightweight plan quickly and gives go/no-go. (No plan-review step — review
   concentrates on the result, not the plan.)

5. flow:develop           [after user confirms]
   └── executes tasks.md, atomic commits, all checkboxes filled

6. flow:deploy            [as a separate session — see below]
   └── pushes, opens Korean PR, then recommends flow:code-review-brief
       (user-driven) — the user makes the brief and runs their own agent(s)
```

## Size-based skip logic

| Step | size = S | size = M | size = L |
|---|---|---|---|
| kickoff | yes | yes | yes |
| prep | yes | yes | yes |
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

Once reviewers have left feedback on the PR, the user can run `flow:review-triage` — in its own session — to pull all the comments, triage validity + priority, plan fixes, and apply them after sign-off. Orchestrate **never auto-invokes** it; just mention it as the next step when deploy/review is done.

If the user objects and explicitly says "just run deploy too", you may invoke it inline, but mention the trade-off.

## Failure handling

Each sub-skill should report its outcome. If any step fails:

- **prep fails** (branch exists, dirty tree, etc.) — surface the error, ask the user.
- **research / plan fail** — usually recoverable, show what went wrong and offer to retry.
- **develop fails mid-implementation** — stop. The tasks.md state shows progress; the user can resume by invoking `flow:develop` directly when they want to continue.

Do not retry silently. Orchestrate is a sequencer, not a self-healing pipeline.

## Reference

Each individual skill is the source of truth for its own behavior. This skill only sequences them:

- `flow:kickoff`
- `flow:prep`
- `flow:research`
- `flow:plan`
- `flow:develop`
- `flow:deploy`
