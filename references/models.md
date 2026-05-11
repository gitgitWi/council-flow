# Multi-LLM Model Registry

Single source of truth for model IDs and CLI invocation. Update this file when models change — skills read identifiers from here, do not hardcode.

## Coding agents available

| Role | CLI | Model ID | Use for |
|---|---|---|---|
| Orchestrator | (this session) | claude-opus-4-7 | Workflow control, output aggregation, final synthesis |
| Frontend / Heavy review | `gemini` | `gemini-3-pro-preview` | Frontend implementation, code review, plan review, brainstorming (architecture lens) |
| Fast research | `gemini` | `gemini-3-flash-preview` | Web research, quick lookups |
| Reasoning review | `opencode` | `opencode-go/kimi-k2.6` | Plan review, code review (alternative perspective). See "agent-mode cost" below. |
| Cost-efficient review | `opencode` | `opencode-go/deepseek-v4-pro` | Code review (alternative perspective). See "agent-mode cost" below. |
| Fast review | `opencode` | `opencode-go/glm-5.1` | Quick second opinion. See "agent-mode cost" below. |

Verification dates inline as comments — re-test when models move. Last full sweep: 2026-05-12 (verified `gemini-3-pro-preview` works for `--prompt` dispatch; `gemini-3.1-pro` from the older registry was not directly verified in this CLI environment).

## Agent-mode cost (opencode)

`opencode run` is a full agent session, not a stateless completion. Every call loads ~30k tokens of agent context (verified — a one-word reply costs 30,165 input tokens before the model emits anything). For latency-sensitive or token-sensitive dispatch (e.g., brainstorming with parallel lenses), this overhead compounds. Prefer Gemini for those steps; reserve opencode for review steps where the agent loop is wanted (e.g., reviewing a real diff with tool access).

## CLI invocation

### Gemini CLI

```bash
gemini --model <model-id> --yolo --skip-trust --prompt "<prompt>"
```

- `--yolo`: bypass interactive confirmations
- `--skip-trust`: skip workspace-trust prompt
- Output goes to stdout. Capture with `> file.md` or `$(...)`.

### OpenCode

```bash
opencode --model <model-id> --prompt "<prompt>"
```

- Output goes to stdout.

## Output handling rule

**Do not pipe other-LLM output back into the Claude conversation as raw text.** Always save to a file under `.planning/<task>/code-reviews/<model>.md` (or wherever the calling skill specifies) and read only the summary or relevant parts. This keeps Claude's context lean.

## When to use multi-LLM

Multi-LLM adds value when the task benefits from diverse perspectives:

- **plan-review** — different models catch different gaps in design
- **deploy/code-review** — three reviewers triangulate quality issues
- **research** (optional) — fast model crawls broadly while Claude focuses

Multi-LLM is overkill for:

- Atomic edits, renames, dependency bumps
- Simple research questions Claude can answer from context
- Anything where the user just wants speed
