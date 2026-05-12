---
title: "Code review — commit 2684d98 — opencode-go/glm-5.1"
type: code-review
task: commit-2684d98-review
task_date: 2026-05-12
created: 2026-05-12
last_updated: 2026-05-12
status: active
size: M
related:
  - ./code-summary.md
  - ./code-gemini.md
reviewer: opencode-go/glm-5.1
cli: opencode
verdict: request-changes
commit: 2684d98fc74dce924c4d58c8baf775a5b2295a17
dispatch_method: stdin-pipe
flags: ["--dangerously-skip-permissions"]
prompted_against:
  - ../_commit-2684d98.patch
  - ../_commit-files.txt
---

## Top-level summary

The file-write dispatch contract is well-designed — sentinel-based completion, heartbeat watcher, structural verification, and quorum policy compose into a working pipeline. However, three cross-reference inconsistencies undermine it in practice: stale/contradictory Gemini model IDs across files, `--format json` in the OpenCode calling pattern that conflicts with the runlog-as-diagnostic contract, and a heredoc quoting mismatch that makes copy-paste hazardous. The `watch_review` function has a liveliness gap when the file is never created (25-min timeout instead of 3-min stale detection).

## Inline findings

### skills/plan/SKILL.md:72
**Severity:** CRITICAL
**Headline:** Stale Gemini model ID contradicts the authoritative registry

The provider-roles section uses `gemini-3.1-pro`, but this commit updates `references/models.md` to `gemini-3-pro-preview`. The same file's dispatch example (L105) uses yet a third variant, `gemini-3.1-pro-preview`. The note on L76 ("Model IDs come from `references/models.md` — if they move, edit there, not here") is contradicted by the very section that contains it. Three different Gemini IDs appear in this commit alone. Replace with the canonical ID from `models.md` and keep only one source of truth.

### skills/plan/SKILL.md:165
**Severity:** CRITICAL
**Headline:** Stale model ID in brainstorm frontmatter template

The `contributors:` list in the `brainstorm.md` template reads `gemini-3.1-pro` — the old ID. Same inconsistency as L72. Must match `references/models.md`.

### references/multi-llm.md:200 (OpenCode calling pattern)
**Severity:** MAJOR
**Headline:** `--format json` flag conflicts with runlog-as-diagnostic contract

The commit introduces `opencode run --model ... --format json` in the OpenCode calling pattern, with stderr redirected to `.jsonl`. With `--format json`, stdout is a JSONL event stream (start, tool-call, tool-result, end) — not human-readable diagnostic output. This directly contradicts the file-write contract's statement that "stdout becomes a diagnostic runlog." The parallel-execution example and models.md later explicitly say **not** to pass `--format json`. Remove it from this pattern; use the default formatted output for runlogs.

### references/multi-llm.md:140-167 (`watch_review` function)
**Severity:** MAJOR
**Headline:** File-never-created path bypasses stale detection, 25-min false wait

When the review file is never created (`! -f "$file"`), the `continue` branch neither increments `stale_count` nor updates `prev_size`. A CLI that crashes immediately (exit 1, no file created) causes `watch_review` to loop through all `max_checks` iterations (25 × 60s = 25 minutes) printing WAITING without ever triggering the stall threshold. The process could be dead within seconds, but the watcher won't detect it. Fix: either (a) track a `wait_count` separate from `stale_count` and cap it (e.g., 5 minutes of WAITING → treat as failed), or (b) have the outer wrapper check the background PID with `kill -0` before waiting for the sentinel.

### references/multi-llm.md:32 vs L234 / skills/plan/SKILL.md:106
**Severity:** MAJOR
**Headline:** Heredoc quoting mismatch creates copy-paste trap

The Gemini calling pattern (multi-llm.md L32) uses `<<'PROMPT'` (single-quoted delimiter, no shell expansion). The wrapping section (multi-llm.md L234) and brainstorm dispatch (plan/SKILL.md L106) use `<<PROMPT` (unquoted, shell expansion active). The switch is necessary for `$REVIEW` / `$REVIEW_ARCH` expansion but is not documented. Anyone copying the `<<'PROMPT'` pattern from L32 and adding `$REVIEW` will get a literal `$REVIEW` string in the prompt. Add a comment at the unquoted heredocs explaining why, or restructure prompts to pass the path as an environment variable so the quoted form can be used everywhere (`REVIEW="$REVIEW" bash -c 'gemini ... <<PROMPT ... PROMPT'`).

### skills/plan/SKILL.md:102-111
**Severity:** MINOR
**Headline:** Relative path in prompt contradicts "absolute path" dispatch contract

The Dispatch contract (multi-llm.md L23) and prompt-construction tips (multi-llm.md L191) both say "always give the reviewer an absolute file path." The brainstorm dispatch example sets `REVIEW_ARCH=.planning/<date>-<task>/brainstorms/architecture-gemini.md` (relative) and embeds `$REVIEW_ARCH` in the prompt. While the variable expands to an absolute path when the variable itself is absolute, the example as written uses a relative path. The placeholder `<date>-<task>` also won't expand in the prompt — it reads like a template instruction rather than a shell-expandable value. Either make the example use `"$PWD/.planning/..."` or add a comment that the variable must be resolved to an absolute path before the heredoc is evaluated.

### references/multi-llm.md:17
**Severity:** MINOR
**Headline:** Sentinel trailing-newline edge case lacks mitigation guidance

The spec requires "no blank lines after" the sentinel, and the check (`tail -1`) correctly rejects an empty trailing line. But some LLM Write tools always append a final `\n`, and others may add `\n\n` (blank line after the sentinel). The former case works (`tail -1` returns the sentinel text), but the latter silently fails verification. Add a sanitization note: "If a contributor file fails the sentinel check, try `sed -i '' -e :a -e '/^\n*$/{$d;N;ba}' file` (strip trailing blank lines) before re-checking." Or define the verification as `tail -1 file | tr -d ' '` equals the sentinel — no, that's too lenient. The best fix is to document that orchestrators should strip trailing whitespace/newlines before the sentinel check.

### skills/plan/SKILL.md:99-141 vs references/multi-llm.md:225-239
**Severity:** NIT
**Headline:** Runlog variable naming diverges from multi-llm.md convention

The multi-llm.md wrapping section defines explicit `RUNLOG`, `RUNERR`, `EXIT` variables. The plan/SKILL.md brainstorm dispatch uses `$RUNLOG_ARCH.stderr` and `$RUNLOG_ARCH.exit` as derived names without defining separate variables. Not a bug, but the inconsistency will confuse anyone switching between the two patterns. Align on one style.

### references/multi-llm.md:27
**Severity:** QUESTION
**Headline:** Write-tool availability claim for CLI non-interactive modes

The contract states that `gemini --yolo`, `opencode run`, `codex exec`, and `claude -p --allowed-tools 'Read,Write'` all expose a Write tool in non-interactive mode. Has this been verified for each CLI version? In particular, `opencode run` in non-interactive mode (`opencode run -m ... "prompt"`) — does it grant Write access by default, or does it require a flag analogous to `--allowed-tools`? If any CLI restricts Write by default in non-interactive mode, the fallback path (stdout-capture + `tee`) needs to be documented per the contract's own admonition.

### skills/plan/SKILL.md:56-67
**Severity:** QUESTION
**Headline:** Default-yes brainstorming for M-size doesn't surface the 30k-token cost

The orchestrate table (skills/orchestrate/SKILL.md) says M-size brainstorming defaults to "yes if cross-module / security / public-surface." But models.md warns that every `opencode run` call costs ~30k input tokens before the model even starts. For M-size with 2 providers (one of which is opencode), that's a significant hidden cost. The "When to run" decision framework for M-size tasks doesn't mention token cost. Consider adding a cost callout: "M-size brainstorming with kimi costs ~30k tokens of agent overhead per call; if the task is small, prefer gemini-only (single-lens) and skip the opencode provider."

## Verdict
request changes

<!-- council-flow:review-complete -->