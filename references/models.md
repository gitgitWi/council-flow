# Model Registry

How `flow` uses models, and the model IDs per harness. The plugin uses models **two** ways:

1. **Research subagents** — cheap, in-harness subagents the flow agent spawns to gather context.
2. **External review agents** — diverse models the **user runs themselves** against a brief the flow agent writes.

> **The flow agent does not dispatch external review/brainstorm CLIs anymore.** The old "agent runs `gemini`/`opencode`/`codex` with a file-write contract" mechanism is **deprecated**: the Gemini CLI was discontinued and its Antigravity replacement has no non-interactive mode yet, and opencode agent sessions carry ~30k-token startup overhead. Instead the flow agent writes a **brief** (base document) and the user runs whichever agent(s) they prefer. See `multi-llm.md`.

## Research subagent tier (cost-efficient — use before serious planning)

All **research-type work** — codebase exploration, GitHub Issue/PR/commit-history search, web lookups for references / best practices — runs in **subagents on a cost-efficient model**, never the frontier orchestrator. Frontier reasoning is reserved for synthesis, planning decisions, and the final brief. Pick the cheap tier by which harness is running:

| Harness | Research subagent model |
|---|---|
| Claude Code | `claude-sonnet-4-6` (Sonnet, not Opus) |
| Antigravity | Gemini 3.5 Flash |
| Codex | Codex 5.5 Mini |

Rules:
- Fan research out to **parallel subagents** (one per area: code, issues/PRs, history, web); each returns a tight digest, not raw dumps — keep the orchestrator's context lean.
- The orchestrator (frontier model) reads digests and decides; it does not crawl itself.
- These are **in-harness** subagents (e.g. a Claude Code Task agent on Sonnet), not external CLIs.

## External review agents (user-run)

These are the agents the **user** runs against a review/brainstorm brief — the flow agent never invokes them. Which ones to use is project config (`.flow/config.yaml` → `review.agents`). Common choices:

| Agent | Model | Notes |
|---|---|---|
| Claude Code | Sonnet | Same harness; good default reviewer. |
| Antigravity | Gemini 3.5 Flash | Replaces the discontinued Gemini CLI; interactive only for now. |
| Codex | Codex 5.5 Mini | Codex stack second opinion. |
| opencode | kimi / deepseek / glm | Still scriptable, but heavy per-call overhead; optional. |

The brief tells the user which lenses to ask for (architecture, risk, security, UX, etc.) so different agents produce differentiated, non-duplicated feedback.

## Output handling rule

**Do not pipe raw other-LLM output back into the flow agent's conversation.** When the user brings reviewer output back, save it to a file under `.planning/<task>/artifacts/` and read only the parts that matter. Keeps context lean.

## When multi-LLM is worth it

Worth a brief + external review when the work benefits from diverse perspectives:

- **code-review** — multiple lenses (UX, quality, security, stability) triangulate issues on the result.
- **brainstorm** — option generation across angles before the plan commits.

Skip it for atomic edits, renames, dependency bumps, or anything where the user just wants speed.
