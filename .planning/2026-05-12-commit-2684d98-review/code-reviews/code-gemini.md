---
title: "Code review — commit 2684d98 — gemini-3.1-pro-preview"
type: code-review
task: commit-2684d98-review
task_date: 2026-05-12
created: 2026-05-12
last_updated: 2026-05-12
status: active
size: M
related:
  - ./code-summary.md
  - ./code-glm.md
reviewer: gemini-3.1-pro-preview
cli: gemini
verdict: request-changes
commit: 2684d98fc74dce924c4d58c8baf775a5b2295a17
prompted_against:
  - ../_commit-2684d98.patch
  - ../_commit-files.txt
---

## Top-level summary
The file-write dispatch contract is a massive improvement over stdout capturing, aligning perfectly with how agent CLIs natively operate. The post-call verification checklist is thorough and catches the most common failure modes. However, there is a critical process-lifecycle bug where the heartbeat watcher will cause the orchestrator to hang for 25 minutes if a contributor times out or fails to create the file, completely defeating the 10-minute timeout policy.

## Inline findings

### references/multi-llm.md:105
**Severity:** CRITICAL
**Headline:** `watch_review` loops for 25 minutes and blocks `wait` even if the CLI times out.

The `watch_review` loop sleeps for 60s up to `max_checks` (default 25). If the CLI fails immediately or is killed by `timeout 600` (10 minutes) without ever creating the file, `watch_review` continues to loop and sleep because `[[ ! -f "$file" ]]` triggers `continue`. Since the orchestrator calls `wait` at the end of the script, the shell will block until `watch_review` finishes, effectively making the timeout 25 minutes instead of 10.
**Fix:** Pass the CLI's `.exit` sidecar file path to `watch_review` and have it check `[[ -f "$exit_file" ]]` to break out of the loop early if the CLI process has terminated.

### references/multi-llm.md:55
**Severity:** MAJOR
**Headline:** `opencode --format json` breaks runlog readability and error grepping.

The patch updates the OpenCode example to include `--format json`. This tells OpenCode to emit raw JSONL agent events rather than a formatted text stream. If the orchestrator or a human needs to read the runlog, it will be raw JSON, and naive grep signature checks for errors might fail if the error is nested in a JSON payload or structured differently.
**Fix:** Remove `--format json` unless the orchestrator is specifically parsing the event stream. Standard stdout is better for diagnostic runlogs.

### skills/plan/SKILL.md:65
**Severity:** MINOR
**Headline:** Stale `gemini-3.1-pro` model ID contradicts `models.md`.

The patch updates `models.md` to use `gemini-3-pro-preview` and explicitly notes it in the commit message. However, `SKILL.md` still references `gemini-3.1-pro` in the YAML frontmatter examples, the prose for the architecture lens, and the `contributors` list.
**Fix:** Standardize on `gemini-3-pro-preview` across all files to match `models.md`.

### references/multi-llm.md:145
**Severity:** NIT
**Headline:** `tail -1` for sentinel check is brittle against LLM trailing newlines.

The documentation states "no trailing whitespace, no blank lines after". While correct in theory, LLMs frequently append an extra trailing newline (or two) to files regardless of prompt instructions. If there is a blank line at the very end of the file, `tail -1 "$file"` will return empty, and the valid review will be marked as failed.
**Fix:** Change the sentinel check to allow trailing blank lines, e.g., `tail -n 2 "$file" | grep -q "$sentinel"`, or use `grep` to strip empty lines before checking the tail: `grep -v '^[[:space:]]*$' "$file" | tail -1`.

### references/multi-llm.md:21
**Severity:** QUESTION
**Headline:** Do all CLIs write without hanging for user approval?

The spec claims `opencode run` and others expose Write tools in non-interactive mode. However, many agent CLIs require interactive confirmation before writing to the filesystem unless a specific "yolo" flag is passed. Gemini uses `--yolo`, but the `opencode` example lacks an explicit bypass flag. If `opencode` prompts for confirmation to write the file, it will hang until the 10-minute timeout.
**Fix:** Ensure and document that `opencode run` defaults to auto-approving file writes in the current workspace, or add the necessary flag to the example.

## Verdict
request changes
<!-- council-flow:review-complete -->