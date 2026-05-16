---
name: orchestrate
description: Run the full flow workflow end-to-end — prep → optional research → optional brainstorm → plan → optional plan-review → develop → deploy — based on a single task goal from the user. Use this when the user wants to hand off a complete task and let the workflow run, rather than driving each step manually. Skips research, brainstorming, and plan-review automatically for size S tasks; runs the full pipeline for size L. Even when the user just says "build me X", consider this skill if the task warrants the full discipline.
---

# flow:orchestrate — End-to-end workflow runner

Orchestrate is a thin sequencer. It does not reimplement any of the individual skills — it invokes them in order, with skip logic based on size and explicit user signals.

## Inputs

1. **Task goal** — what the user wants built, in their words.
2. **Type hint** (optional) — feature / fix / chore / refactor / docs. Inferred from the goal if not given.
3. **Explicit skips** (optional) — e.g., "skip research", "skip plan-review", "don't multi-LLM the code review at the end". Honor without arguing.

## The sequence

```
1. flow:prep
   └── creates worktree, branch, .planning/, meta.md (with size estimate)

2. flow:research          [skip if size = S, or user opted out]
   └── writes research.md
   └── may suggest flow:brainstorm if candidate approaches list has 3+
       comparable shapes (advisory — orchestrate, not research, dispatches)

3. flow:brainstorm        [run if size = L, or size = M with cross-module /
                           security-sensitive / public-surface flag; ask
                           otherwise; skip if size = S]
   └── writes brainstorm.md (synthesis) + brainstorms/ (raw per-model output)

4. flow:plan              [always]
   └── writes plan.md, tasks.md (consults brainstorm.md when it exists)

5. flow:plan-review       [run if size = L; ask user if size = M; skip if size = S]
   └── writes code-reviews/plan-*.md and plan-summary.md
   └── if substantive changes: bumps plan.md → plan.v1.md, writes new plan.md

6. — Checkpoint with user —
   Show plan.md, tasks.md, and plan-summary.md (if exists). Wait for go/no-go.

7. flow:develop           [after user confirms]
   └── executes tasks.md, atomic commits, all checkboxes filled

8. flow:deploy            [as a separate session — see below]
   └── pushes, opens Korean PR, runs multi-LLM review, posts inline comments
```

`flow:brainstorm` is also invocable standalone (`/flow:brainstorm`) outside the
orchestrate pipeline — useful when the user wants to weigh options on a sketch
without committing to a plan yet. Orchestrate is one of several callers, not
the only one.

## Size-based skip logic

| Step | size = S | size = M | size = L |
|---|---|---|---|
| prep | yes | yes | yes |
| research | skip | ask | yes |
| brainstorm | skip | ask (default yes if cross-module / security / public-surface) | yes |
| plan | yes | yes | yes |
| plan-review | skip | ask | yes |
| user checkpoint | skip | yes | yes |
| develop | yes | yes | yes |
| deploy | yes | yes | yes |

"Ask" means: surface the decision to the user with the size-based default pre-selected. Don't bounce every step.

## The user checkpoint before develop

This is the only mandatory pause in orchestrate. Show the user:

1. The plan summary (Korean section of plan.md, or plan-summary.md if plan-review ran)
2. The tasks.md checkbox list
3. Anything that came up as an open question

Wait for an explicit go-ahead before invoking `flow:develop`. The reason for the pause: develop runs for a while and produces commits — the user should sign off on what is about to be built. After the checkpoint, develop runs without further interruption unless it hits a blocker.

## Deploy as a separate session

Deploy intentionally runs as its own session. Orchestrate's job at the end of develop is:

1. Confirm `tasks.md` is fully checked.
2. Confirm tests pass.
3. Tell the user: "Develop complete. Start a new session and invoke `flow:deploy` to open the PR and run the multi-LLM review."

Do **not** auto-invoke deploy inside orchestrate. The reasons:

- Develop's session has the implementation context loaded; deploy benefits from a fresh context where the reviewer LLMs are not influenced by Claude's own implementation decisions.
- The user usually wants to look at the diff themselves before kicking off review.
- Token cost — keeping deploy in a fresh session is cheaper than dragging develop's history along.

If the user objects and explicitly says "just run deploy too", you may invoke it inline, but mention the trade-off.

## Failure handling

Each sub-skill should report its outcome. If any step fails:

- **prep fails** (branch exists, dirty tree, etc.) — surface the error, ask the user.
- **research / plan / plan-review fail** — usually recoverable, show what went wrong and offer to retry.
- **plan-review reviewer CLI(s) fail** (auth, rate limit, network, etc.) — the per-skill quorum policy applies (see `../../references/multi-llm.md`): ≥2 valid reviews → continue with synthesis and a `## 결손 리뷰어` note; 1 valid → ask user; 0 valid → stop. Orchestrate does not override these decisions.
- **develop fails mid-implementation** — stop. The tasks.md state shows progress; the user can resume by invoking `flow:develop` directly when they want to continue.

Do not retry silently. Orchestrate is a sequencer, not a self-healing pipeline.

## Reference

Each individual skill is the source of truth for its own behavior. This skill only sequences them:

- `flow:prep`
- `flow:research`
- `flow:brainstorm`
- `flow:plan`
- `flow:plan-review`
- `flow:develop`
- `flow:deploy`
