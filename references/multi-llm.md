# Multi-LLM Invocation Patterns

For model IDs and CLI flags, see `models.md`. This file is about *how* to drive other coding agents from inside a flow skill.

## Core principle

**Never paste raw output from another LLM into your conversation.** Always pipe to a file, then read only the parts you need. Other LLMs emit verbose preambles, restatements, and reasoning that bloat the orchestrator's context.

## Calling pattern (Gemini)

```bash
gemini --model gemini-3.1-pro --yolo --skip-trust --prompt "$(cat <<'PROMPT'
You are reviewing a plan document for a software change.

Read the plan at <abs-path>/plan.md and the task list at <abs-path>/tasks.md.
Produce a review with the following sections in Markdown:
- Strengths
- Risks / gaps
- Concrete suggestions (file:line where applicable)
- Verdict: ship / revise

Focus on correctness and missed edge cases. Be specific.
PROMPT
)" > .planning/<task>/code-reviews/plan-gemini.md
```

## Calling pattern (OpenCode)

```bash
opencode --model opencode-go/kimi-k2.6 --prompt "$(cat <<'PROMPT'
... same kind of prompt ...
PROMPT
)" > .planning/<task>/code-reviews/plan-kimi.md
```

## Parallel execution

For Plan Review and Code Review, run all reviewer CLIs in parallel — they are independent.

```bash
# In your skill, kick all three off in the same step
gemini --model gemini-3.1-pro ... > .../plan-gemini.md &
opencode --model opencode-go/kimi-k2.6 ... > .../plan-kimi.md &
opencode --model opencode-go/deepseek-v4-pro ... > .../plan-deepseek.md &
wait
```

If invoking from Claude tool calls instead of a single shell pipeline, issue the Bash calls in the same message so Claude executes them in parallel.

## After invocation

1. Verify each output file exists and is non-empty.
2. **Read each file once** to extract structured findings — strengths, risks, suggestions, verdict. Do not dump all three into context simultaneously.
3. Synthesize a Korean summary (`plan-summary.md` / `code-summary.md`):
   - 합의된 강점
   - 합의된 위험 요소
   - 모델 간 의견이 갈리는 지점 (이 부분이 가장 중요)
   - 권장 후속 조치

## Prompt construction tips

- Always give the reviewer an absolute file path, not a relative path. Different CLIs have different working-directory assumptions.
- Tell the reviewer the **format** of output you want (sections, headings). Otherwise output varies wildly between models.
- Tell the reviewer **what role** to take — "you are reviewing a plan" vs "you are reviewing code" leads to different attention.
- For code review, include `git diff` output or the changed file paths so the model has something concrete to react to.

## When to skip multi-LLM

- Task size `S` (single-file edits)
- User said "just plan it" / "just ship it"
- The reviewers would all read the same small change and produce the same review

When skipping, write a `plan-summary.md` (or `code-summary.md`) explaining that multi-LLM was skipped and why, so the audit trail is complete.

## Failure handling and fallback

External CLIs fail in predictable ways: missing binary, expired auth, exhausted free-tier quota, network blip, mid-stream cutoff. Multi-LLM steps must degrade gracefully — losing one reviewer is not a reason to abort the whole workflow.

### Pre-flight check

Before invoking any reviewer, verify the CLI is installed and at least nominally usable:

```bash
command -v gemini   >/dev/null 2>&1 || echo "gemini: missing"
command -v opencode >/dev/null 2>&1 || echo "opencode: missing"
command -v claude   >/dev/null 2>&1 || echo "claude: missing"
```

If a CLI is missing, do not attempt to call it. Mark it skipped (see "Recording a skipped/failed reviewer" below) and continue with the rest.

### Wrapping each invocation

Wrap each call so that **the orchestrator never reads raw error output into context**, and so a single failure cannot kill the parent shell. Use `timeout`, capture stderr to a sidecar file, and check the exit code explicitly. Recommended pattern:

```bash
# Run with a hard timeout. Always succeed at the shell level so `wait` doesn't abort.
( timeout 600 gemini --model gemini-3.1-pro --yolo --skip-trust \
    --prompt "$(cat <<'PROMPT'
... reviewer prompt ...
PROMPT
)" > .planning/<task>/code-reviews/plan-gemini.md \
    2> .planning/<task>/code-reviews/plan-gemini.stderr; \
  echo $? > .planning/<task>/code-reviews/plan-gemini.exit ) || true &
```

Repeat per reviewer in the same shell pipeline (or in parallel Bash tool calls), then `wait`.

### Post-call verification (mandatory)

After all reviewers return, for each reviewer file run **all three** of these checks before reading the file content:

1. **Exit code** — read `.exit` sidecar. `0` = success, `124` = timeout, anything else = CLI error.
2. **File exists and is non-empty** — `[[ -s plan-gemini.md ]]`. Empty output usually means the CLI printed only to stderr.
3. **No known failure signature in the output file** — case-insensitive grep for any of these tokens in the *first 40 lines* of the output (don't scan the whole file — the reviewer's own analysis may legitimately mention these words):

   ```
   rate limit | quota exceeded | usage limit | 429
   unauthorized | authentication failed | invalid api key | 401 | 403
   not logged in | please log in | login required | re-authenticate
   network error | enotfound | econnrefused | timed out | connection reset
   model not found | model unavailable | service unavailable | 503
   ```

   A match means the file contains an error message instead of a review. Treat it as a failure even if exit code was 0 — some CLIs print errors to stdout and exit 0.

### Recording a skipped/failed reviewer

When a reviewer fails (any of the three checks above), do **not** delete the partial output. Instead:

1. Move the partial file aside: `mv plan-gemini.md plan-gemini.partial.md` (only if it has content; if empty, delete it).
2. Write a short failure record at `code-reviews/plan-gemini.FAILED.md`:

   ```markdown
   # plan-gemini — FAILED

   - **Reviewer**: gemini-3.1-pro (CLI: gemini)
   - **When**: 2026-05-11 15:42 KST
   - **Detected by**: <one of: missing binary | exit code 1 | empty output | failure signature in output>
   - **Signature matched** (if any): "rate limit"
   - **Stderr tail** (last 5 lines, only if it adds info):
     ```
     ...
     ```
   - **Action**: continued without this reviewer / aborted / user retried

   See plan-gemini.partial.md for partial output (if any).
   ```

3. **Do not paste the raw stderr or partial output into the orchestrator's conversation.** Reference the file path. The point of the failure record is to keep the audit trail in the filesystem, not in chat context.

### Quorum policy

Decide based on how many reviewers produced *valid* output:

| Successful reviewers | Action |
|---|---|
| **≥ 2** | Proceed with synthesis. In `plan-summary.md` / `code-summary.md`, add a `## 결손 리뷰어` section listing who failed and why (one line each). |
| **1** | Stop and ask the user: (a) retry the failed reviewers (often the user just needs to re-auth), (b) swap to a different reviewer (e.g., `gemini` failed → try `claude` as the second voice), or (c) proceed with one reviewer and label the summary as "single-reviewer" — explicitly not multi-LLM. |
| **0** | Stop. Do not synthesize. Surface the failure records to the user and recommend `/octo:doctor`-equivalent CLI checks (auth, quota, network). |

Never silently retry a failed CLI inside the same skill run — the most common cause is auth expiry, and a silent retry will fail the same way. Surface failures to the user and let them fix root cause.

### Common signatures and likely causes

| Signature | Likely cause | Fix the user can take |
|---|---|---|
| `rate limit` / `429` / `quota exceeded` | Free-tier exhausted, or burst limit | Wait, switch model tier, or swap reviewer |
| `unauthorized` / `401` / `not logged in` | Token expired or never set | Re-run the CLI's `login` flow |
| `model not found` / `503` | Model ID drift or provider outage | Check `references/models.md` is current; try again later |
| `enotfound` / `connection reset` | Local network / VPN / proxy | Retry; if persistent, check `curl` to the API endpoint |
| Exit code `124` | Hit the 600s `timeout` cap | Plan/diff was too large; trim scope or raise timeout for this run |
| Empty file, exit 0 | CLI streamed nothing to stdout (often a flag mismatch) | Check the CLI's invocation flags against `references/models.md` |

### Why this policy exists

Multi-LLM review's value is *diversity*. Two voices is enough for diversity; one is not. Aborting the whole workflow because one CLI is rate-limited wastes the other reviewers' work and frustrates the user. But silently downgrading to a single reviewer pretending it was multi-LLM defeats the audit trail. Hence: degrade gracefully to ≥2, escalate to the user at 1, and never paper over a 0.
