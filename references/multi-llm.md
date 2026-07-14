# Multi-LLM: brief → user-run agents

How `flow` gets diverse-model perspectives now that the agent **no longer runs reviewer CLIs**.

## Why no agent-run CLI dispatch

The old mechanism (the flow agent runs `opencode`/`codex` with a file-write contract, quorum, sentinels, heartbeats) is **deprecated**:

- Some agents are interactive-only, with no scriptable non-interactive mode.
- opencode agent sessions cost ~30k tokens of startup overhead per call.
- Driving external CLIs from the agent was fragile (auth, timeouts, hallucinated paths) and slowed the iteration loop.

So the model is now: **the flow agent writes a brief; the user runs whichever agent(s) they prefer** and brings the output back (or posts it straight to the PR).

## The brief model

Each step that wants diverse perspectives produces a **brief** — a base document:

- The context a reviewer needs (the diff or plan + the original intent + the user's key requests).
- The **lenses** to review through, tailored to the actual work (see below).
- Which agents to run — from `.flow/config.yaml` → `review.agents` — with a suggested lens split (e.g. Codex = security/stability, Antigravity = UX/quality).

The flow agent **never invokes** the external agents. It writes the brief and stops.

Producers: `flow:code-review-brief` (PR review brief) and the optional brainstorm sub-phase of `flow:plan`.

## Lenses (pick what fits the work)

- **Architecture & alternatives** — distinct shapes, tradeoffs.
- **Risk & failure modes** — races, partial states, rollback, regressions.
- **Security & correctness** — auth/authz, injection, data exposure, secrets, deps.
- **UX** — experience, accessibility, edge states (for UI changes).
- **Code quality** — readability, naming, cohesion, test coverage, pattern fit.
- **Redundant / over-engineered** — duplicates existing code, or hand-rolls what a library/framework provides simply.
- **Stability** — error/timeout/concurrency paths, blast radius.

Drop lenses irrelevant to the change; redundant lenses are noise.

## Bringing results back

- The user saves each agent's output to `.planning/<task>/artifacts/<step>-<agent>.md`.
- The flow agent reads each **once**, synthesizes a Korean summary where relevant, and verifies any cited `file:line` against the repo (agents hallucinate paths).
- **Do not pipe raw other-LLM output into the flow agent's main conversation.** File it; read only what matters. Keeps context lean.

## When it's worth it

- **code-review** — on PRs, the main event (the user runs the agents on the brief). With small-task fast iteration, review concentrates on the *result*, not the plan.
- **brainstorm** — size L or cross-cutting work; usually the flow agent generates the options itself and reaches for external agents only when stakes justify the round-trip.

Skip entirely for atomic edits, renames, dependency bumps, or when the user just wants speed.
