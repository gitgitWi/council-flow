# Frontmatter Schema for `.planning/` Documents

Every file written by a flow skill into `.planning/<date>-<task>/` carries a YAML frontmatter block. The point is **agentic search** — a future Claude session, a `grep`, or a teammate's tooling can locate documents by `task`, `type`, `status`, or `related` without reading body content. Treat frontmatter as the index, not as decoration.

## Common fields (every document)

```yaml
---
title: <human-readable title>            # "Plan — Add Google login"
type: <doc type>                         # see "Type values" below
task: <kebab task name>                  # matches meta.md task and branch suffix
task_date: <YYYY-MM-DD>                  # the date prefix in the directory name
created: <YYYY-MM-DD>                    # when this file was first written
last_updated: <YYYY-MM-DD>               # bumped on substantive edits
status: <status>                         # see "Status values" below
size: <S|M|L>                            # mirrored from meta.md for single-doc lookup
parent: <relative path>                  # usually ./meta.md or ./plan.md
related:                                 # one bullet per cross-link, with a short reason
  - ./plan.md (current plan)
  - ./tasks.md (GWT checklist)
---
```

`title` and `type` are required. Everything else is required when applicable but may be omitted when truly meaningless for the doc (e.g., `size` on a FAILED.md sidecar). Missing fields are worse than empty fields when later searching, so prefer empty over absent.

## Type values

One of these per document. Search-friendly — keep the spelling stable.

| `type` | File |
|---|---|
| `meta` | `meta.md` |
| `research` | `research.md` |
| `brainstorm` | `brainstorm.md` (multi-LLM brainstorming synthesis) |
| `brainstorm-contribution` | `brainstorms/<role>-<model>.md` (per-model raw output) |
| `plan` | `plan.md` |
| `plan-version` | `plan.v<N>.md` (superseded plan) |
| `tasks` | `tasks.md` |
| `tasks-version` | `tasks.v<N>.md` (superseded tasks) |
| `plan-phase` | `plan-phase-<N>.md` (size-L breakouts) |
| `plan-review` | `review/plan-<reviewer>.md` |
| `plan-summary` | `review/plan-summary.md` |
| `code-review` | `review/code-<reviewer>.md` |
| `code-summary` | `review/code-summary.md` |
| `review-failed` | `review/<reviewer>.FAILED.md` |
| `plan-translation` | `translates/plan.ko.md` |
| `tasks-translation` | `translates/tasks.ko.md` |

## Status values

| `status` | Meaning |
|---|---|
| `draft` | Being authored right now; not stable. |
| `active` | Current canonical document for its type. |
| `done` | Work it described is complete (typical for `meta`/`tasks` after deploy). |
| `superseded` | A newer version exists; see `superseded_by`. Used on `plan.v<N>.md` etc. |
| `failed` | Reviewer CLI failed to produce valid output. Used only on `review-failed`. |

## Per-type fields (in addition to common)

### `meta` (written by `flow:prep`)

```yaml
branch: feature/add-google-login
worktree: /Users/.../<repo>.worktrees/add-google-login
base: main
started: 2026-05-11
goal: |
  Allow users to sign in with Google in addition to email/password.
```

### `plan` and `plan-version`

```yaml
version: 1                               # 1 for the first plan; bumps on plan-review revisions
supersedes: ./versions/plan.v1.md        # only on plan.md when a previous version exists
superseded_by: ./plan.md                 # only on versions/plan.v<N>.md
plan_review_run: true                    # set true after flow:plan-review touched it
```

A new `plan.md` after `plan-review` produces substantive changes carries `version: <N+1>` and `supersedes: ./versions/plan.v<N>.md`. The previous file is moved to `versions/plan.v<N>.md` with `status: superseded` and `superseded_by: ./plan.md`. Its Korean translation moves to `versions/plan.ko.v<N>.md`.

### `tasks` and `tasks-version`

```yaml
version: 1
supersedes: ./versions/tasks.v1.md
superseded_by: ./tasks.md
total_tasks: 12                          # optional — set at authoring time, do not maintain
```

Do not try to maintain a "completed" count — the checkbox state in the body is the source of truth. `total_tasks` is fine as an authoring-time hint.

### `plan-phase`

```yaml
phase: 1                                 # the phase number this file owns
parent: ./plan.md                        # plan.md is the index when phases exist
```

### `research`

```yaml
time_box: 10m                            # nominal time-box used (5m | 10m | 20m | 60m)
used_external_llm: true                  # set when Gemini/OpenCode produced raw output under review/
external_llm_outputs:                    # only when used_external_llm is true
  - ./review/research-gemini.md
```

### `brainstorm` (multi-LLM brainstorming synthesis, authored by `flow:plan`)

```yaml
contributors:                            # models whose raw output is folded in
  - gemini-3.1-pro
  - opencode-go/kimi-k2.6
missing_contributors: []                 # models that failed (mirrors plan-summary pattern)
```

### `brainstorm-contribution` (per-model raw output under `brainstorms/`)

```yaml
contributor: gemini-3.1-pro              # CLI-facing model id
cli: gemini                              # which CLI binary produced this
lens: architecture                       # architecture | risk | security — the assigned role
prompted_against:                        # absolute paths the contributor was told to read
  - /abs/.../meta.md
  - /abs/.../research.md
```

### `plan-review` and `code-review` (per-reviewer files)

```yaml
reviewer: gemini-3.1-pro                 # CLI-facing model id
cli: gemini                              # which CLI binary produced this
verdict: ship-as-is                      # ship-as-is | ship-after-minor-edits | rework-needed
                                         # for code-review: merge-as-is | merge-after-minor-edits | request-changes
prompted_against:                        # the absolute paths the reviewer was told to read
  - /abs/.../plan.md
  - /abs/.../tasks.md
```

### `plan-summary` and `code-summary`

```yaml
reviewers:                               # list of reviewers whose output is included
  - gemini-3.1-pro
  - opencode-go/kimi-k2.6
  - opencode-go/deepseek-v4-pro
missing_reviewers: []                    # list of reviewers that failed; empty when complete
pr: 1234                                 # only on code-summary, after the PR is opened
```

### `review-failed`

```yaml
reviewer: gemini-3.1-pro
cli: gemini
detected_by: failure-signature           # missing-binary | nonzero-exit | empty-output | failure-signature
signature_matched: rate limit            # the matched token if detected_by is failure-signature
exit_code: 0                             # the captured exit code (0 if signature in stdout)
when: 2026-05-11T15:42:00+09:00          # ISO timestamp of detection
partial_output: ./plan-gemini.partial.md # only when partial output was preserved
```

### `plan-translation` and `tasks-translation`

```yaml
source: ../plan.md                       # or ../tasks.md — the English file this translates
language: ko
translator: sonnet                       # or glm-5.1
```

## Conventions

- **Dates in `YYYY-MM-DD`** for `created`, `last_updated`, `task_date`, `started`. Use full ISO 8601 (with time and tz) only for `when` on FAILED records.
- **Relative paths** for everything inside the same `.planning/<date>-<task>/` directory (`./plan.md`, `./review/...`). Use absolute paths only for `worktree` (in meta) and `prompted_against` (in reviewer files), where absoluteness is the point.
- **Mirror, don't compute.** `task`, `task_date`, `size` are mirrored from `meta.md` at authoring time. Do not invent a process to keep them in sync; if `meta.md` changes, fix the others by hand or accept the drift.
- **`related` is for navigation, not provenance.** Each entry is `<path> (<one-line reason>)`. If a doc is the canonical anchor (parent), put it in `parent`, not `related`.

## Why

Three reasons this exists:

1. **Agentic search.** A `grep -l 'type: plan' .planning/` returns every plan across every task without reading bodies. Same for `task:`, `status: superseded`, `verdict: rework-needed`, `missing_reviewers: \[].*opencode`.
2. **Cross-doc traceability.** `parent` and `related` form a navigable graph. Future Claude sessions can walk from a `plan-summary.md` back to the exact `plan.v2.md` that was reviewed.
3. **Auditability.** `created` / `last_updated` / `status` capture the artifact lifecycle without git archaeology.

## What NOT to add

- **Counts that drift** (e.g., "open questions: 3") — the body has it; the frontmatter shouldn't lie.
- **Free-form tags / categories** — keep the schema closed. New fields require updating this reference.
- **PII / secrets** — frontmatter is committed and broadly scanned; treat it as public.
