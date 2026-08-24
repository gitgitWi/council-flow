# Multi-LLM: brief-first, two execution routes

How `flow` gets diverse-model perspectives. The **brief** is always the artifact. What changed (2026-08-24) is that the brief can now be *dispatched* by the flow agent through Paseo / `agy`, instead of only being handed to the user.

## Two routes — pick per step

| | **Route A — user-run** (default) | **Route B — Paseo/agy dispatch** (opt-in) |
|---|---|---|
| Who executes | The user, in whatever agent they prefer | The flow agent, via `paseo run` / `agy -p` |
| When | Default. Interactive judgment wanted, or the user is already in that tool | Fan-out over 3+ lenses, or a step the user asked to automate |
| Returns | User saves output under `artifacts/` | Structured JSON via `--output-schema` / `--json-schema` |
| Cost | On the user's chosen account | On that provider's account, out-of-process |

Route B does **not** replace the brief — it consumes the same document. Write the brief first either way.

## Still deprecated: ad-hoc CLI shelling

The old mechanism — the flow agent hand-rolling `opencode`/`codex` invocations with a file-write contract, quorum counting, sentinel files, and heartbeats — stays **deprecated**. Its failure modes were the harness, not the idea:

- Hand-rolled file-write contracts drifted from what the CLI actually produced.
- No supervision: a hung CLI blocked the flow agent with no timeout.
- Interactive-only agents had no scriptable entry point at all.

Route B is allowed because a supervisor now handles exactly those three: Paseo's daemon owns provider auth and sessions, `--wait-timeout` / `--print-timeout` bound the call, and both `paseo run` and `agy -p` are first-class non-interactive entry points with schema-enforced output. **Do not go back to bare `opencode ...` / `codex ...` shell-outs.**

What did *not* get solved: **agents still hallucinate file paths.** Verifying every cited `file:line` against the repo remains mandatory in both routes.

## The brief model

Each step that wants diverse perspectives produces a **brief** — a base document:

- The context a reviewer needs (the diff or plan + the original intent + the user's key requests).
- The **lenses** to review through, tailored to the actual work (see below).
- Which agents run which lens — from `.flow/config.yaml` → `review.agents`.

Producers: `flow:code-review-brief` (PR review brief) and the optional brainstorm sub-phase of `flow:plan`.

In Route A the flow agent writes the brief and stops. In Route B it writes the brief, dispatches it, and reports back — but it still never edits the brief to suit a model.

## Lenses (pick what fits the work)

- **Architecture & alternatives** — distinct shapes, tradeoffs.
- **Risk & failure modes** — races, partial states, rollback, regressions.
- **Security & correctness** — auth/authz, injection, data exposure, secrets, deps.
- **UX** — experience, accessibility, edge states (for UI changes).
- **Code quality** — readability, naming, cohesion, test coverage, pattern fit.
- **Redundant / over-engineered** — duplicates existing code, or hand-rolls what a library/framework provides simply.
- **Stability** — error/timeout/concurrency paths, blast radius.

Drop lenses irrelevant to the change; redundant lenses are noise.

## Route B — dispatch reference

Verify availability before dispatching (`paseo provider ls`); credit state and model IDs move. Do not hardcode a lens→model map in a skill.

| Role | Runner | Model | Effort flag |
|---|---|---|---|
| Body / synthesis | `paseo --provider claude` | `claude-fable-5` | `--thinking max` |
| Code / security | `paseo --provider codex` | `gpt-5.6-sol` | `--thinking max` |
| Cross-check A | `paseo --provider opencode` | `opencode-go/kimi-k3` | `--thinking max` |
| Cross-check B | `paseo --provider opencode` | `opencode-go/qwen3.8-max` | none — see caveat |
| UX / design | `agy` (not a Paseo provider) | `gemini-3.7-flash-high` | `--effort high` |

Shape of a dispatch:

```bash
paseo run -d --label round=<task> --title "review:<lens>" \
  --provider codex --model gpt-5.6-sol --thinking max \
  --cwd <repo> --output-schema "$FINDINGS_SCHEMA" --wait-timeout 15m \
  "$(cat <brief>)

Lens: <lens>. Judge only the diff in the brief. Answer via the schema only. Do not edit files."

paseo wait <id> --timeout 900 && paseo inspect <id> --json
```

`agy` is driven directly, outside Paseo:

```bash
agy --model gemini-3.7-flash-high --effort high --output-format json \
  --json-schema "$FINDINGS_SCHEMA" --print-timeout 15m --add-dir <repo> \
  -p="$(cat <brief>)

Lens: UX. Answer via the schema only." > artifacts/<step>-agy.json
```

Caveats that bite:

- **`-p` must be attached** (`-p='...'`) and last. Space-separated, it eats the next flag as the prompt.
- **`opencode-go/qwen3.8-max` cannot take `--output-schema`** — the provider rejects forced `tool_choice` in thinking mode (400). Run it schema-less and read the result with `paseo logs <id> --tail N`.
- **opencode is limited to `opencode-go/*` and `*-free`.** Zen paid and OpenRouter paths have no credit.
- **`--output-schema` failure loses the work** — only the error JSON survives. For long tasks prefer schema-less + `paseo inspect`.
- **Isolate parallel writers.** Agents touching the same repo concurrently need `--new-workspace worktree`; a flow session is itself often a Paseo agent, so an un-flagged `paseo run` lands in the *same* workspace.
- Clean up after a round: `paseo ls -g --label round=<task> --json` (the agent name field is `name`, not `title`) then `paseo delete`.

## Bringing results back

Identical in both routes:

- Each agent's output lands at `.flow/tasks/<task>/artifacts/<step>-<agent>.md` (or `.json` for schema returns).
- The flow agent reads each **once**, synthesizes a Korean summary where relevant, and verifies every cited `file:line` against the repo (agents hallucinate paths).
- **Do not pipe raw other-LLM output into the flow agent's main conversation.** File it; read only what matters. Schema returns exist precisely so the narration never enters context.

## When it's worth it

- **code-review** — on PRs, the main event. Route B pays off here: several lenses at once, structured returns.
- **brainstorm** — size L or cross-cutting work; usually the flow agent generates the options itself and reaches for external models only when stakes justify the round-trip.

Skip entirely for atomic edits, renames, dependency bumps, or when the user just wants speed.
