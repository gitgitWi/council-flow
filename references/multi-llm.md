# Multi-LLM Invocation Patterns

For model IDs and CLI flags, see `models.md`. This file is about *how* to drive other coding agents from inside a flow skill.

## Core principles

1. **Never paste raw output from another LLM into your conversation.** Read the file once during synthesis; do not stream raw CLI output into the orchestrator's context.
2. **The contributor writes the file directly via its own Write tool.** Do not capture stdout as the artifact. Stdout becomes a diagnostic runlog; the file at the agreed path *is* the review. This plays to agent CLIs' native shape (they are built around tool loops, not stateless completion) and avoids stdout-wrapper drift across CLIs (Gemini wraps in JSON, opencode emits JSONL events, codex prefixes/suffixes).
3. **Every contributor file ends with a sentinel.** Without an explicit completion marker, "file exists and is non-empty" cannot distinguish "still being written" from "wrote half then died." The sentinel is the only reliable signal that the contributor finished.

The sentinel is, for every skill in this plugin:

```
<!-- council-flow:review-complete -->
```

It must appear as the **last line** of the contributor's output file (no trailing whitespace, no blank lines after).

## Dispatch contract

The prompt to every contributor must include, near the top, three explicit instructions:

1. **Use your Write tool to write the review to `<absolute path>`.** Not stdout.
2. **The last line of the file MUST be exactly `<!-- council-flow:review-complete -->`.**
3. **Do not ask clarifying questions; do not print the review to stdout (only a one-line confirmation).**

If a CLI does not expose a Write tool in non-interactive mode (rare today — `gemini --yolo`, `opencode run`, `codex exec`, `claude -p --allowed-tools 'Read,Write'` all do), fall back to stdout-capture and apply a `tee` of the runlog alongside it. Document the fallback in the skill that uses it.

## Calling pattern (Gemini)

```bash
gemini --model gemini-3.1-pro-preview --yolo --skip-trust --prompt "$(cat <<'PROMPT'
You are a non-interactive reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the plan at <abs-path>/plan.md and the task list at <abs-path>/tasks.md.
2. Write your review using the Write tool to: <abs-path>/review/plan-gemini.md
3. The LAST LINE of the file MUST be exactly:
     <!-- council-flow:review-complete -->
4. Print only: "wrote plan-gemini.md"

Review sections (Markdown):
- Strengths
- Risks / gaps
- Concrete suggestions (file:line where applicable)
- Verdict: ship / revise

Focus on correctness and missed edge cases.
PROMPT
)" > .planning/<task>/review/_runlog-gemini.txt \
   2> .planning/<task>/review/_runlog-gemini.stderr
```

Note the `> _runlog-gemini.txt` — that captures stdout as a diagnostic log, **not** as the review. The review file is what Gemini's Write tool produced.

## Calling pattern (OpenCode)

```bash
PROMPT="$(cat <<'PROMPT_BODY'
You are a non-interactive reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the plan at <abs-path>/plan.md.
2. Write your review using the Write tool to: <abs-path>/review/plan-kimi.md
3. The LAST LINE of the file MUST be exactly:
     <!-- council-flow:review-complete -->
4. Print only: "wrote plan-kimi.md"

(... review sections ...)
PROMPT_BODY
)"

printf '%s' "$PROMPT" | \
  opencode run --dangerously-skip-permissions -m opencode-go/kimi-k2.6 \
    > .planning/<task>/review/_runlog-kimi.txt \
    2> .planning/<task>/review/_runlog-kimi.stderr
```

Flag notes (verified 2026-05-12 against `opencode` v1.14.x — re-test on upgrades):

- **`--dangerously-skip-permissions` is mandatory for the file-write contract.** Without it, the agent loop hangs waiting for human approval of the Write tool. Empirically verified: a 540s dispatch produced 0 bytes of stdout/stderr because the LLM session sat blocked on permission approval. With the flag, the same call completes in 2-7 minutes. octo:review does not need this flag because it uses stdout-capture, not file-write.

- **Pipe the prompt via stdin — never as a positional argument.** This is load-bearing.

  ```bash
  printf '%s' "$PROMPT" | opencode run --dangerously-skip-permissions -m <provider/model>   # ✅ correct
  opencode run --dangerously-skip-permissions -m <provider/model> "$PROMPT"                  # ❌ silent hang on review-shape prompts
  ```

  Past a certain prompt size/complexity threshold (empirically: ~2.5KB with markdown and backticks), `opencode run` with a positional-arg prompt bootstraps successfully (config, plugins, file watcher all init) and then **never starts the LLM session** — no `build · model` header, no tool calls, no provider HTTP. The process burns the full timeout producing zero output. octo:review's `spawn.sh` hit the same class of bug (Issue #173 in their tracker, fixed in v9.2.2) for codex/claude and now pipes prompts via stdin for all providers. This pattern is mandatory for us too.

- `-m, --model <provider/model>` — required for non-default routing. Long form `--model` also works.

- **Do not pass `--format json`** unless you specifically want to parse the JSONL event stream. The default formatted output is what runlog capture expects; `json` mode emits raw agent events (start, tool-call, tool-result, end) and shells trying to grep success markers from that stream get false negatives.

**Caveat for `opencode run` — wall-clock cost:** every call loads ~30k tokens of agent context before the model sees the prompt (verified — even a one-word completion costs 30k input tokens). On top of that, `opencode-go/*` models route through a remote provider, so cold-start latency stacks on top of the agent context load. Empirically: a moderate review prompt that Gemini completes in ~2 min takes 5-7 min on `opencode-go/glm-5.1`. **Set `timeout 900` (15 min) for opencode reviewers — 540s is too tight.** For latency- or token-sensitive dispatch, prefer Gemini; reserve OpenCode for review steps where the agent loop is actually wanted (real diff + tool access).

**Agent self-reads context aggressively.** Even when the prompt says "Read only if needed", `opencode-go/glm-5.1` reads every referenced path. To minimize Read-time overhead, either (a) inline the diff in the prompt rather than pointing to a path, or (b) phrase the instruction as a hard constraint: *"DO NOT Read additional files. The provided diff is sufficient."* The soft "optional context" framing is treated as a request to load everything.

## Calling pattern (Codex)

```bash
PROMPT="$(cat <<'PROMPT_BODY'
You are a non-interactive reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the plan at <abs-path>/plan.md and the task list at <abs-path>/tasks.md.
2. Write your review using the Write tool to: <abs-path>/review/plan-codex.md
3. The LAST LINE of the file MUST be exactly:
     <!-- council-flow:review-complete -->
4. Print only: "wrote plan-codex.md"

(... review sections; review, do not implement ...)
PROMPT_BODY
)"

codex exec --skip-git-repo-check \
           --model gpt-5-codex \
           --sandbox workspace-write \
           --cd /abs/path/to/worktree \
           - <<<"$PROMPT" \
    > .planning/<task>/review/_runlog-codex.txt \
    2> .planning/<task>/review/_runlog-codex.stderr
```

Flag notes (verified 2026-05-12 against the installed `codex` CLI):

- **Pipe the prompt via stdin (`-` + here-string or `printf | codex exec ... -`).** Codex's `[PROMPT]` positional accepts the form but a positional review-shape prompt is at risk of the same silent-startup failure mode that bites `opencode run` (root cause is shared in the agent-CLI ecosystem: ARG_MAX or pre-LLM arg parsing). octo:review fixed this in their Issue #173 by switching all providers to stdin pipe. Mirror that here.
- **`--skip-git-repo-check` is required** when dispatching from a path that may not be a git work tree (e.g., dispatching for a `.planning/` artifact when codex's CWD detection is conservative). Without it, codex refuses to run in non-interactive mode.
- **`--sandbox workspace-write` is required for the file-write contract.** The default sandbox blocks the Write tool. Valid values include `read-only`, `workspace-write`, `danger-full-access`. Use `workspace-write` (writes within the CWD only) for reviewers.
- **`--cd <abs-path>` pins the working directory.** Without it codex inherits the orchestrator's CWD, which may be a different worktree.
- **Reviewer-not-implementer prompt framing matters.** Codex defaults to "implement the requested change" framing; explicitly say "review, do not implement" or it may try to *fix* the plan instead of critiquing it.
- For fully unattended dispatch in trusted environments (e.g., the user's own machine) you may use `--dangerously-bypass-approvals-and-sandbox` to skip all confirmations. This is **off by default** — only use when the calling skill explicitly opts in.

## Parallel execution

For Plan Review and Code Review, dispatch all reviewer CLIs in parallel — they are independent. With the file-write contract this is straightforward:

```bash
gemini --model gemini-3.1-pro-preview --yolo --skip-trust --prompt "$PROMPT_GEMINI" \
    > .../_runlog-gemini.txt 2> .../_runlog-gemini.stderr &

# OpenCode reviewers — stdin pipe + --dangerously-skip-permissions mandatory.
# See "Calling pattern (OpenCode)" above for why.
( printf '%s' "$PROMPT_KIMI" | \
  opencode run --dangerously-skip-permissions -m opencode-go/kimi-k2.6 \
    > .../_runlog-kimi.txt 2> .../_runlog-kimi.stderr ) &
( printf '%s' "$PROMPT_DEEPSEEK" | \
  opencode run --dangerously-skip-permissions -m opencode-go/deepseek-v4-pro \
    > .../_runlog-deepseek.txt 2> .../_runlog-deepseek.stderr ) &

codex exec --skip-git-repo-check -m gpt-5-codex -s workspace-write \
    --cd "$WORKTREE" - <<<"$PROMPT_CODEX" \
    > .../_runlog-codex.txt 2> .../_runlog-codex.stderr &
wait
```

The `( ... ) &` subshell wrappers are required for OpenCode because the pipe is what's being backgrounded, not the `opencode run` invocation alone — without the subshell, `&` only backgrounds the `opencode` process after the pipe has fully consumed stdin, defeating parallelism. Codex's `- <<<"$PROMPT"` form pipes stdin via here-string (equivalent to `printf '%s' "$P" | codex exec ... -`), which is shorter than the subshell form and works because `codex exec` reads stdin without a pre-pipe consumer.

If invoking from Claude tool calls instead of a single shell pipeline, issue the Bash calls in the same message so Claude executes them in parallel.

## Heartbeat watcher (mandatory for any dispatch > 60s)

Without a heartbeat, a hung contributor is indistinguishable from a slow one. Dispatch loops that just `wait` for the ceiling burn 10+ minutes of user time on a failure detectable in 60s.

Run this watcher in parallel with the dispatch. Each iteration writes one line; the orchestrator can stream those lines to the user (via Monitor tool or chat output) so progress is visible. Exit on sentinel found, on stale (no size change for N checks), or on max-check timeout:

```bash
watch_review() {
  # Args: <review-file> [<exit-file>] [<max-checks>]
  # exit-file is the `.exit` sidecar written by the dispatch wrapper (see
  # "Wrapping each invocation"). When present, the watcher exits as soon as
  # the CLI process terminates — without it, a CLI that exits immediately
  # (e.g., flag parse error, no provider auth) would still cause the watcher
  # to loop for max_checks × 60s before giving up.
  local file="$1"
  local exit_file="${2:-}"
  local max_checks="${3:-25}"
  local sentinel='<!-- council-flow:review-complete -->'
  local prev_size=-1 stale_count=0 wait_count=0
  local wait_cap=5  # max consecutive "file not yet created" heartbeats before treating as failed
  for i in $(seq 1 "$max_checks"); do
    sleep 60
    local ts=$(date +%H:%M:%S)

    # Early exit: dispatch wrapper already wrote the exit sidecar, so the
    # CLI has terminated. Decide based on whether the review file is complete.
    if [[ -n "$exit_file" && -f "$exit_file" ]]; then
      local rc=$(<"$exit_file")
      if [[ -f "$file" ]] && [[ "$(tail -1 "$file")" == "$sentinel" ]]; then
        echo "$ts [#$i/$max_checks] DONE — CLI exited rc=$rc, sentinel found"
        return 0
      fi
      echo "$ts [#$i/$max_checks] CLI_EXITED — rc=$rc but sentinel missing; treating as failed"
      return 3
    fi

    if [[ ! -f "$file" ]]; then
      wait_count=$((wait_count + 1))
      echo "$ts [#$i/$max_checks] WAITING — $(basename "$file") not yet created (wait_count=$wait_count/$wait_cap)"
      [[ "$wait_count" -ge "$wait_cap" ]] && { echo "$ts NEVER_STARTED — file not created after ${wait_cap}m, treating as failed"; return 4; }
      continue
    fi

    local size=$(wc -c < "$file" | tr -d ' ')
    local last=$(tail -1 "$file")
    if [[ "$last" == "$sentinel" ]]; then
      echo "$ts [#$i/$max_checks] DONE — $(basename "$file") ${size}B, sentinel found"
      return 0
    elif [[ "$size" == "$prev_size" ]]; then
      stale_count=$((stale_count + 1))
      echo "$ts [#$i/$max_checks] STALE — ${size}B unchanged (stale_count=$stale_count)"
      [[ "$stale_count" -ge 3 ]] && { echo "$ts STALL — 3 consecutive stale checks, treating as failed"; return 2; }
    else
      stale_count=0
      echo "$ts [#$i/$max_checks] WRITING — ${size}B (was ${prev_size}B)"
    fi
    prev_size=$size
  done
  echo "$(date +%H:%M:%S) TIMEOUT — $max_checks heartbeats elapsed without sentinel"
  return 1
}

# Usage — pass the exit sidecar from the dispatch wrapper so the watcher
# exits the instant the CLI terminates (instead of looping for 25 min on
# a CLI that died in 5 seconds):
( timeout 600 gemini ... > "$RUNLOG" 2> "$RUNERR"; echo $? > "$EXIT" ) &
watch_review "$REVIEW" "$EXIT" 25 &
wait
```

**Why the exit-sidecar and wait_cap matter (CRITICAL).** The previous version of this watcher would loop for the full `max_checks × 60s` (default 25 minutes) any time the review file was never created, because the `! -f "$file"` branch only printed `WAITING` and `continue`'d without incrementing any failure counter. A CLI that exits immediately with a flag error, an auth failure, or a silent ARG_MAX-style startup hang (see "Calling pattern (OpenCode)") would burn the full timeout before `wait` released the parent shell, effectively making every dispatch a 25-minute floor on failures.

Two-pronged fix:

1. **`wait_count` capped at 5** — if 5 minutes elapse without the file appearing, return failure (`exit 4 — NEVER_STARTED`). Distinct from `stale_count` so that "writing slowly" and "never started" don't share a budget.
2. **`exit_file` (sidecar) short-circuit** — when the dispatch wrapper writes its `.exit` file, the CLI is terminated. The watcher reads the exit code, checks for sentinel, and returns. No reason to keep heartbeating against a dead process.

The exit-sidecar path is preferred; the `wait_count` cap is a fallback for callers that didn't wire the sidecar.

Heartbeat output is a stream of one-line events. It is safe to display directly to the user — unlike contributor file content, it does not interpolate untrusted model output into Claude's context.

## After invocation

1. **Verify each output file ends with the sentinel** (`tail -1 "$file"`). No sentinel = treat as failed regardless of file size; partial writes look identical to complete ones without it.
2. **Verify each output file has structural content** — at minimum one `## ` heading and one `- ` bullet within the first 50 lines. A non-empty file that contains only agent boilerplate ("I'll help you review...") will pass a naive size/signature check; the structural check catches it.
3. **Read each file once** to extract structured findings — strengths, risks, suggestions, verdict. Do not dump all three into context simultaneously.
4. **Verify file:line references** the contributors cite — when synthesizing, grep contributor outputs for path-shaped strings, check against `git ls-files`, and surface unverifiable paths under a "Paths to verify" section. Contributors hallucinate paths regularly; the synthesis should not promote them silently.
5. Synthesize a Korean summary (`plan-summary.md` / `code-summary.md`):
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

Wrap each call so that **the orchestrator never reads raw error output into context**, and so a single failure cannot kill the parent shell. Use `timeout`, capture stdout/stderr to **diagnostic runlog files** (the review itself lands at the agreed path via the CLI's Write tool — see "Dispatch contract" above), and check the exit code explicitly.

**Timeout budget per provider** (verified 2026-05-12):

- Gemini: `timeout 600` (10 min) is comfortable for plan/code review.
- OpenCode: `timeout 900` (15 min). 540s is too tight given the 30k-token cold start + remote provider routing — see "Calling pattern (OpenCode)".
- Codex: `timeout 600` (10 min); raise to 900 if the diff is large.

Recommended pattern — Gemini (prompt as `--prompt` flag is fine, only opencode/codex need stdin pipe):

```bash
# Review file (what the CLI writes via its Write tool):
REVIEW=.planning/<task>/review/plan-gemini.md
# Diagnostic runlog files (stdout/stderr capture; not the review):
RUNLOG=.planning/<task>/review/_runlog-gemini.txt
RUNERR=.planning/<task>/review/_runlog-gemini.stderr
EXIT=.planning/<task>/review/_runlog-gemini.exit

# Run with a hard timeout. Always succeed at the shell level so `wait` doesn't abort.
( timeout 600 gemini --model gemini-3.1-pro-preview --yolo --skip-trust \
    --prompt "$(cat <<PROMPT
... reviewer prompt; MUST tell the CLI to Write its review to $REVIEW and end
with the sentinel <!-- council-flow:review-complete --> ...
PROMPT
)" > "$RUNLOG" 2> "$RUNERR"; \
  echo $? > "$EXIT" ) || true &
```

Same pattern for OpenCode — prompt via stdin pipe, `--dangerously-skip-permissions` mandatory:

```bash
REVIEW=.planning/<task>/review/plan-kimi.md
RUNLOG=.planning/<task>/review/_runlog-kimi.txt
RUNERR=.planning/<task>/review/_runlog-kimi.stderr
EXIT=.planning/<task>/review/_runlog-kimi.exit
PROMPT="$(cat <<PROMPT_BODY
... reviewer prompt; MUST tell the CLI to Write its review to $REVIEW ...
PROMPT_BODY
)"

( printf '%s' "$PROMPT" | \
    timeout 900 opencode run --dangerously-skip-permissions -m opencode-go/kimi-k2.6 \
    > "$RUNLOG" 2> "$RUNERR"
  echo $? > "$EXIT" ) || true &
```

Repeat per reviewer in the same shell pipeline (or in parallel Bash tool calls). Run `watch_review "$REVIEW" "$EXIT"` (see "Heartbeat watcher" above — passing the exit sidecar so the watcher returns the moment the CLI dies, instead of looping for the full max_checks budget) in parallel so progress is visible, then `wait`.

### Post-call verification (mandatory)

After all reviewers return, for each reviewer file run **all five** of these checks before reading the file content:

1. **Exit code** — read `_runlog-*.exit`. `0` = success, `124` = timeout, anything else = CLI error.
2. **Review file exists and is non-empty** — `[[ -s plan-gemini.md ]]`. Empty file = treat as failed.
3. **Sentinel present** — `tail -1 plan-gemini.md` must equal `<!-- council-flow:review-complete -->`. Absent sentinel = treat as failed regardless of size (the CLI died mid-write, or never finished, or hallucinated being done).
4. **Structural content present** — within the first 50 lines the file must contain at least one `## ` heading **and** one `- ` bullet. A non-empty file of agent boilerplate ("I'll help you review...") will pass size and signature checks but fails this.
5. **No known failure signature in the output file** — case-insensitive grep for any of these tokens in the *first 40 lines* (don't scan the whole file — the reviewer's own analysis may legitimately mention these words):

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
2. Write a short failure record at `review/plan-gemini.FAILED.md` (frontmatter schema in `frontmatter.md`):

   ```markdown
   ---
   title: "Plan review FAILED — <task> — gemini-3.1-pro-preview"
   type: review-failed
   task: <kebab task name>
   task_date: <YYYY-MM-DD>
   created: <today>
   last_updated: <today>
   status: failed
   size: <S|M|L>
   parent: ../plan.md
   related:
     - ./plan-summary.md
     - ./plan-gemini.partial.md  # only if partial output preserved
   reviewer: gemini-3.1-pro-preview
   cli: gemini
   detected_by: failure-signature   # missing-binary | nonzero-exit | empty-output | failure-signature
   signature_matched: "rate limit"  # only when detected_by is failure-signature
   exit_code: 0
   when: 2026-05-11T15:42:00+09:00
   partial_output: ./plan-gemini.partial.md  # omit if no partial preserved
   ---

   # plan-gemini — FAILED

   - **Reviewer**: gemini-3.1-pro-preview (CLI: gemini)
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
