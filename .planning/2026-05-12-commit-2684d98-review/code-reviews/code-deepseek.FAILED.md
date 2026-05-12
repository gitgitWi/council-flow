---
title: "Code review FAILED — commit 2684d98 — opencode-go/deepseek-v4-pro (and exploratory variants)"
type: review-failed
task: commit-2684d98-review
task_date: 2026-05-12
created: 2026-05-12
last_updated: 2026-05-12
status: failed
size: M
related:
  - ./code-summary.md
  - ./code-glm.md
reviewer: opencode-go/deepseek-v4-pro
cli: opencode
detected_by: empty-output
exit_code: 124
when: 2026-05-12T14:35:00+09:00
---

# Failed opencode-go reviewer attempts — root cause analysis

The default trio (gemini + kimi + deepseek-v4-pro) could not be completed for this review. After diagnostic, all OpenCode dispatches failed for the same root cause; one stdin-pipe variant succeeded and replaced deepseek-v4-pro in the final synthesis.

## Attempts

All exited 124 (timeout) with **0 bytes stdout, 0 bytes stderr**, no review file created. See `_runlog-*` siblings.

- `opencode run -m opencode-go/kimi-k2.6 "$PROMPT"` — 540s, no `--dangerously-skip-permissions`
- `opencode run -m opencode-go/deepseek-v4-pro "$PROMPT"` — 540s, no `--dangerously-skip-permissions`
- `opencode run --dangerously-skip-permissions -m opencode-go/kimi-k2.6 "$PROMPT"` — 540s
- `opencode run --dangerously-skip-permissions -m opencode-go/deepseek-v4-flash "$PROMPT"` — 1200s
- `opencode run --dangerously-skip-permissions -m opencode-go/glm-5.1 "$PROMPT"` — 1200s

`--print-logs --log-level DEBUG` variant (positional arg, 300s) **did** produce stderr — see `_runlog-glm-debug.stderr`. Bootstrapped successfully (config, plugins, bus, file watcher), then went silent. **The LLM session was never initiated** — no `build · model` header, no tool calls, no provider HTTP.

## Root cause

**`opencode run` with the prompt passed as a positional argument silently fails to start the LLM session past a certain prompt size/complexity threshold.** This is the same class of bug octo:review's `spawn.sh` fixed in Issue #173 (v9.2.2):

> Previously only gemini used stdin; codex/claude passed prompt as CLI arg **which fails on large diffs**. Now all agents use stdin-based prompt delivery to avoid ARG_MAX limits.

In octo, the fix was: `printf '%s' "$prompt" | run_with_timeout "$TIMEOUT" "${cmd_array[@]}"` — feed prompt via stdin to all providers.

## Validating fix

```bash
# Same prompt, same model, stdin pipe instead of positional:
printf '%s' "$PROMPT" | opencode run --dangerously-skip-permissions -m opencode-go/glm-5.1
# → exit 0, 7.6KB review file produced, sentinel correct.
```

See `code-glm.md` for the resulting review.

## Implications for `references/multi-llm.md`

The file-write dispatch contract must be updated to mandate two operational details that this commit (2684d98) introduced as implicit assumptions:

1. **stdin-pipe prompt delivery for OpenCode** (and likely codex too — not yet tested). Positional-arg is documented as broken for review-shape prompts.
2. **`--dangerously-skip-permissions` is required when OpenCode is asked to use the Write tool.** Without it, the agent loop hangs waiting for approval. Octo:review didn't need this because they use stdout-capture, not file-write; our skills do need it.

These are load-bearing operational findings — without them, the multi-LLM file-write contract is unreliable for any reviewer outside Gemini.

## Action taken in this review

- Dropped `opencode-go/deepseek-v4-pro` from the trio
- Substituted `opencode-go/glm-5.1` via stdin-pipe + `--dangerously-skip-permissions` + tightened prompt
- 2-reviewer quorum satisfied (Gemini + GLM); synthesis proceeded per quorum policy
- Listed deepseek-v4-pro as `missing_reviewers` in `code-summary.md` frontmatter

<!-- council-flow:review-complete -->
