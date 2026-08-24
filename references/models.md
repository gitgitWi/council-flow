# Model Registry

How `flow` uses models, and the model IDs per harness. The plugin uses models **three** ways:

1. **Bundled agent tiers** — in-harness subagents shipped with the plugin (`flow:planner`, `flow:developer`, `flow:researcher`, `flow:reviewer`, plus the frontend-only `flow:browser-tester` and `flow:react-reviewer`) that the orchestrator delegates phases to, each pinned to a cost-appropriate tier.
2. **Research subagents** — the `flow:researcher` tier above (and ad-hoc `Explore`/`Task` subagents), spawned cheap to gather context.
3. **External review agents** — diverse models that judge a brief the flow agent writes. Either the **user** runs them (Route A, default) or the flow agent **dispatches** them through a supervisor (Route B, opt-in).

> **Hand-rolled CLI shell-outs stay deprecated.** The old "agent runs `opencode`/`codex` with a file-write contract, quorum, sentinels, heartbeats" mechanism is not coming back — it drifted from actual CLI output and had no timeout or supervision. What *is* allowed is dispatch through a supervisor that owns auth, timeouts, and schema-enforced returns: `paseo run` (claude / codex / opencode / …) and `agy -p` (Antigravity). Never `opencode ...` / `codex ...` directly. See `multi-llm.md`.

## Bundled agent tiers (Claude Code)

The plugin bundles six subagents (registered in `.claude-plugin/plugin.json` → `agents`). The orchestrator delegates each phase to the matching tier instead of running everything on the frontier model. Invoke them scoped: `flow:planner`, `flow:developer`, `flow:researcher`, `flow:reviewer`, `flow:browser-tester`, `flow:react-reviewer`.

| Agent | Tier (alias) | Phase | Why this tier |
|---|---|---|---|
| `flow:planner` | `opus` (frontier) | plan | Synthesis and trade-off decisions need the strongest reasoning. |
| `flow:developer` | `sonnet` | develop | Mechanical TDD build is cost-sensitive; delegate off the frontier. |
| `flow:researcher` | `sonnet` | research | Context-gathering, fanned out in parallel; cheap and disposable. |
| `flow:reviewer` | `fable` | review (in-harness, optional) | Fast local fresh-eyes pass; complements the external-agent review. |
| `flow:browser-tester` | `sonnet` | review — frontend only | Real-browser QA (rendering / events / CDP-observed API); runs in parallel with review. |
| `flow:react-reviewer` | `fable` (opus for high-stakes) | review — frontend only | Composition/reuse audit of React code; runs in parallel with review. |

The last two are **frontend-only** and run **in parallel with `flow:reviewer`** — a review *lane*, not a sequential step. They no-op on non-frontend changes. The lane is **dispatched by `flow:deploy`** (Step 4), because deploy runs in the session where the PR exists; `flow:orchestrate` describes the parallel/supervision model but has already ended before deploy. See `flow:deploy` and `flow:orchestrate`.

Agent frontmatter pins the **alias** (`opus` / `sonnet` / `fable`) — stable across model versions — so this registry stays the single place mapping aliases to full per-harness IDs. Delegation is optional: the orchestrator may still run plan/develop inline when a task is small. The `flow:reviewer` in-harness pass does **not** replace the external-agent review below; it is the no-setup option.

**Model availability & fallback.** There is no fallback-list syntax in the `model:` field (`model: fable, opus` is not a thing). If an org's `availableModels` allowlist excludes a tier, Claude Code silently runs that agent on the **inherited** model instead ([sub-agents docs](https://code.claude.com/docs/en/sub-agents)). So `flow:reviewer` on `fable` degrades to the orchestrator's model (Opus in flow's frontier setup) when Fable is unavailable — a higher-quality, still-correct fallback. To make the fallback explicit rather than incidental: remap the alias session-wide (`export ANTHROPIC_DEFAULT_FABLE_MODEL=claude-opus-4-8`), set the reviewer to `model: inherit`, or have the orchestrator spawn it with an explicit `model: opus` override (the Agent-tool `model` param beats frontmatter in the resolution order).

**Claude Code only.** The bundled agents (`agents/*.md` + the `agents` array in `.claude-plugin/plugin.json`) and the `opus`/`sonnet`/`fable` aliases are a Claude Code mechanism — Codex CLI and Antigravity do not recognize them (cross-harness agent/model behavior is undocumented). In those harnesses the portable layer is the **skills + the per-harness tier table below**: the orchestrator there spawns that harness's native subagents on its own models (Codex 5.6 Terra, Gemini Flash, …). For a genuinely different model *family* as reviewer from inside Claude Code, use an external agent rather than a bundled tier — e.g. the [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) `/codex:review` command or its `codex:codex-rescue` subagent, which shell out to the local Codex CLI on a GPT/Codex model. See *External review agents* and `multi-llm.md`.

## Research subagent tier (cost-efficient — use before serious planning)

All **research-type work** — codebase exploration, GitHub Issue/PR/commit-history search, web lookups for references / best practices — runs in **subagents on a cost-efficient model**, never the frontier orchestrator. Frontier reasoning is reserved for synthesis, planning decisions, and the final brief. Pick the cheap tier by which harness is running:

| Harness | Research subagent model |
|---|---|
| Claude Code | `claude-sonnet-4-6` (Sonnet, not Opus) |
| Antigravity | Gemini 3.5 Flash |
| Codex | Codex 5.6 Terra |

Parallelism is **not limited to research.** Independent tasks/sub-issues (non-overlapping files) and the review lane (code review + browser QA + React quality) also run concurrently — the orchestrator delegates and supervises rather than working serially. See `flow:orchestrate` → *Run non-overlapping work in parallel* and *Supervise and rework*.

Rules:
- Fan research out to **parallel subagents** (one per area: code, issues/PRs, history, web); each returns a tight digest, not raw dumps — keep the orchestrator's context lean.
- The orchestrator (frontier model) reads digests and decides; it does not crawl itself.
- These are **in-harness** subagents, not external CLIs. In Claude Code, delegate to the bundled `flow:researcher` agent (Sonnet); fan out several, one per area.

## External review agents

These are the agents that judge a review/brainstorm brief. Which ones to use is project config (`.flow/config.yaml` → `review.agents`); how they are launched is per-step (Route A user-run vs Route B dispatch — see `multi-llm.md`).

Reasoning effort: pin each model's **highest supported** level.

| Agent | Runner | Model | Effort | Notes |
|---|---|---|---|---|
| Claude Code | `paseo --provider claude` | `claude-fable-5` | `--thinking max` | Same family; synthesis and body work. `ultracode` sits above `max` but changes behavior, not just effort. |
| Codex | `paseo --provider codex` | `gpt-5.6-sol` | `--thinking max` | Code / security second opinion. `max` is already its default; `ultra` sits above it. |
| opencode | `paseo --provider opencode` | `opencode-go/kimi-k3` | `--thinking max` | Cross-check. |
| opencode | `paseo --provider opencode` | `opencode-go/qwen3.8-max` | none | Cross-check. **Cannot take `--output-schema`** — the provider rejects forced `tool_choice` in thinking mode; run schema-less and read via `paseo logs`. |
| Antigravity | `agy` (not a Paseo provider) | `gemini-3.7-flash-high` | `--effort high` | UX / design lens. Effort is baked into the model ID; `gemini-3.1-pro-high` for a deeper pass. |

Availability moves — confirm with `paseo provider ls` before dispatching, and read opencode model IDs from `opencode models` (Paseo's opencode catalog mismaps the `google/*` namespace). opencode is currently limited to `opencode-go/*` and `*-free`; Zen paid and OpenRouter have no credit.

The brief tells each agent which lens to apply (architecture, risk, security, UX, etc.) so different agents produce differentiated, non-duplicated feedback.

For a fast local pass without spinning up external agents, Claude Code can also delegate to the bundled in-harness `flow:reviewer` (Fable) — see *Bundled agent tiers* above. It complements, not replaces, the external review: a different model *family* is the whole point of the external pass, so prefer it when the change is large, cross-module, or security-sensitive.

## Output handling rule

**Do not pipe raw other-LLM output back into the flow agent's conversation.** When the user brings reviewer output back, save it to a file under `.flow/tasks/<task>/artifacts/` and read only the parts that matter. Keeps context lean.

## When multi-LLM is worth it

Worth a brief + external review when the work benefits from diverse perspectives:

- **code-review** — multiple lenses (UX, quality, security, stability) triangulate issues on the result.
- **brainstorm** — option generation across angles before the plan commits.

Skip it for atomic edits, renames, dependency bumps, or anything where the user just wants speed.
