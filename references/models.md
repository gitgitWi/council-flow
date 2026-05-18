# Multi-LLM Model Registry

Single source of truth for model IDs and CLI invocation. Update this file when models change — skills read identifiers from here, do not hardcode.

## Coding agents available

| Role | CLI | Model ID | Use for |
|---|---|---|---|
| Orchestrator | (this session) | claude-opus-4-7 | Workflow control, output aggregation, final synthesis |
| Frontend / Heavy review | `gemini` | `gemini-3.1-pro-preview` | Frontend implementation, code review, plan review, brainstorming (architecture lens) |
| Fast research | `gemini` | `gemini-3-flash-preview` | Web research, quick lookups |
| Reasoning review | `opencode` | `opencode-go/kimi-k2.6` | Plan review, code review (alternative perspective). See "agent-mode cost" below. |
| Deep review | `opencode` | `opencode-go/deepseek-v4-pro` | Code review (deepest analysis, slowest). See "agent-mode cost" below. |
| Cost-efficient review | `opencode` | `opencode-go/deepseek-v4-flash` | Faster DeepSeek variant — good signal/latency tradeoff. See "agent-mode cost" below. |
| Fast review | `opencode` | `opencode-go/glm-5.1` | Quickest second opinion. See "agent-mode cost" below. |
| Codex-side review | `codex` | `gpt-5.5` | Plan/code review from the codex stack — default third reviewer alongside gemini + kimi. See "Codex sandbox" below. |

Verification dates inline as comments — re-test when models move. Last full sweep: 2026-05-12.

- `gemini-3.1-pro-preview` — verified for `--prompt` dispatch with `--yolo --skip-trust`.
- `opencode-go/kimi-k2.6`, `opencode-go/deepseek-v4-pro`, `opencode-go/deepseek-v4-flash`, `opencode-go/glm-5.1` — provider authenticated via `opencode auth list` (OpenCode Go: api). Invocation must use `-m provider/model`; **do not** pass `--format json` (emits JSONL events, not formatted completion).
- `gpt-5.5` via `codex exec` — verified flags: `--skip-git-repo-check`, `-m`, `-s/--sandbox`, `-C/--cd`. Default sandbox blocks Write tool; pass `--sandbox workspace-write` for the file-write dispatch contract.

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
opencode run -m <provider/model> "<prompt>"
```

- `-m, --model` — use the `provider/model` form (e.g., `opencode-go/kimi-k2.6`).
- Prompt is the positional `[message..]` argument; can also be piped via stdin.
- **Do not pass `--format json`** unless you intend to parse the JSONL event stream; default formatted output is what runlog wrappers expect.
- Output (formatted) goes to stdout; if the prompt uses the file-write contract, the review lands at the path the model wrote to, and stdout is just a diagnostic runlog.

### Codex CLI

```bash
codex exec --skip-git-repo-check \
           --model <model-id> \
           --sandbox workspace-write \
           --cd <abs-path> \
           "<prompt>"
```

- `--skip-git-repo-check` — required when CWD is not a git repo or codex's repo detection is conservative.
- `--sandbox workspace-write` — required for the file-write contract; the default sandbox blocks the Write tool. Other values: `read-only`, `danger-full-access`.
- `--cd <abs-path>` — pin the working directory; codex otherwise inherits the orchestrator's CWD.
- Prompt is the positional `[PROMPT]` argument or `-` to read from stdin.
- **Reviewer framing matters** — codex defaults to "implement" intent; spell out "review, do not implement" in the prompt.
- For fully unattended dispatch on a trusted machine: `--dangerously-bypass-approvals-and-sandbox` (use sparingly; opt-in per skill).

#### Codex sandbox

Codex's `--sandbox` controls what the model's generated shell/tool calls can do, not what the wrapper does. The three useful values:

- `read-only` — cannot write files. Use for "just analyze, never modify" jobs.
- `workspace-write` — can write only inside the CWD subtree. The right default for reviewers writing into `.planning/<task>/review/`.
- `danger-full-access` — unrestricted; reserve for explicit user opt-in.

## Output handling rule

**Do not pipe other-LLM output back into the Claude conversation as raw text.** Always save to a file under `.planning/<task>/review/<model>.md` (or wherever the calling skill specifies) and read only the summary or relevant parts. This keeps Claude's context lean.

## When to use multi-LLM

Multi-LLM adds value when the task benefits from diverse perspectives:

- **plan-review** — different models catch different gaps in design
- **deploy/code-review** — three reviewers triangulate quality issues
- **research** (optional) — fast model crawls broadly while Claude focuses

Multi-LLM is overkill for:

- Atomic edits, renames, dependency bumps
- Simple research questions Claude can answer from context
- Anything where the user just wants speed
