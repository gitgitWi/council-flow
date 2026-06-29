# Frontmatter Schema for `.planning/` Documents

Every file written by a flow skill into `.planning/<date>-<task>/` carries a YAML frontmatter block. The point is **agentic search** — a future Claude session, a `grep`, or a teammate's tooling can locate documents by `task`, `type`, `status`, or `related` without reading body content. Treat frontmatter as the index, not as decoration.

## Common fields (every document)

```yaml
---
title: <human-readable title>            # "Plan — Add Google login"
type: <doc type>                         # see "Type values" below
task: <kebab task name>                  # matches prepare.md task and branch suffix
task_date: <YYYY-MM-DD>                  # the date prefix in the directory name
created: <YYYY-MM-DD>                    # when this file was first written
last_updated: <YYYY-MM-DD>               # bumped on substantive edits
status: <status>                         # see "Status values" below
size: <S|M|L>                            # mirrored from prepare.md for single-doc lookup
parent: <relative path>                  # usually ./prepare.md or ./plan.md
related:                                 # one bullet per cross-link, with a short reason
  - ./plan.md (current plan)
  - ./tasks.md (behavior checklist)
---
```

`title` and `type` are required. Everything else is required when applicable but may be omitted when truly meaningless for the doc (e.g., `size` on a FAILED.md sidecar). Missing fields are worse than empty fields when later searching, so prefer empty over absent.

## Type values

One of these per document. Search-friendly — keep the spelling stable.

| `type` | File |
|---|---|
| `brief` | `brief.md` (kickoff task framing — goal, acceptance, scope, direction diagram) |
| `prepare` | `prepare.md` |
| `research` | `research.md` |
| `brainstorm` | `brainstorm.md` (brainstorming synthesis) |
| `brainstorm-brief` | `artifacts/brainstorm-brief.md` (brief for external agents) |
| `plan` | `plan.md` |
| `plan-version` | `artifacts/plan.v<N>.md` (superseded plan) |
| `tasks` | `tasks.md` |
| `tasks-version` | `artifacts/tasks.v<N>.md` (superseded tasks) |
| `plan-phase` | `plan-phase-<N>.md` (size-L breakouts) |
| `code-review-brief` | `artifacts/code-review-brief.md` (PR review brief for user-run agents) |
| `code-review` | `artifacts/code-review-<agent>.md` (an agent's returned review) |
| `code-summary` | `artifacts/code-review-summary.md` (synthesis of returned reviews) |
| `plan-translation` | `artifacts/plan.ko.md` |
| `tasks-translation` | `artifacts/tasks.ko.md` |

## Status values

| `status` | Meaning |
|---|---|
| `draft` | Being authored right now; not stable. |
| `active` | Current canonical document for its type. |
| `done` | Work it described is complete (typical for `prepare`/`tasks` after deploy). |
| `superseded` | A newer version exists; see `superseded_by`. Used on `plan.v<N>.md` etc. |

## Per-type fields (in addition to common)

### `prepare` (written by `flow:prep`)

```yaml
branch: feature/add-google-login
base: main
started: 2026-05-11
goal: |
  Allow users to sign in with Google in addition to email/password.
```

`prepare.md` is the one exception to the common-fields block: it **omits `task_date` and `created`**. Both would be identical to `started` (prep writes all three on the same day), and the directory name already carries the date — `started` is the single date that matters for the task. It also has no `worktree` field: the worktree path is an absolute, machine-specific value. Find the worktree with `git rev-parse --show-toplevel` from inside it instead.

### `plan` and `plan-version`

```yaml
version: 1                               # 1 for the first plan; bumps on substantive revisions
supersedes: ./artifacts/plan.v1.md       # only on plan.md when a previous version exists
superseded_by: ../plan.md                # only on artifacts/plan.v<N>.md
```

A `plan.md` substantively revised after the user has seen it carries `version: <N+1>` and `supersedes: ./artifacts/plan.v<N>.md`. The previous file is moved to `artifacts/plan.v<N>.md` with `status: superseded` and `superseded_by: ../plan.md`. Its Korean translation moves to `artifacts/plan.v<N>.ko.md`.

### `tasks` and `tasks-version`

```yaml
version: 1
supersedes: ./artifacts/tasks.v1.md
superseded_by: ../tasks.md
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
used_external_llm: true                  # set when Gemini/OpenCode produced raw output under artifacts/
external_llm_outputs:                    # only when used_external_llm is true
  - ./artifacts/research-gemini.md
```

### `brainstorm` (brainstorming synthesis, authored by `flow:plan`)

```yaml
contributors:                            # flow-agent, plus any external agent the user ran
  - flow-agent
  - antigravity                          # optional, if the user ran an external agent
```

### `brief` and `code-review-brief` and `brainstorm-brief`

```yaml
# brief.md (kickoff)
category: Debug & Fix                     # Feature | Fix | Debug & Fix | Refactor | Chore | Research | UI Fix | Question

# code-review-brief.md
pr: 1234
```

The brief body holds only review material (files, change summary, intent, lenses). Agent→lens suggestions are output to chat, not stored in the doc — so there is no `review_agents` field.

### `code-review` (an external agent's returned review, saved by the user)

```yaml
agent: antigravity                        # which agent produced this
verdict: merge-after-minor-edits          # merge-as-is | merge-after-minor-edits | request-changes
pr: 1234
```

### `code-summary` (synthesis of returned reviews)

```yaml
agents:                                   # agents whose returned output is included
  - claude-code
  - antigravity
pr: 1234
```

### `plan-translation` and `tasks-translation`

```yaml
source: ../plan.md                       # or ../tasks.md — the English file this translates
language: ko
translator: sonnet                       # or glm-5.1
```

## Conventions

- **Dates in `YYYY-MM-DD`** for `created`, `last_updated`, `task_date`, `started`. Use full ISO 8601 (with time and tz) only for `when` on FAILED records.
- **Relative paths** for everything inside the same `.planning/<date>-<task>/` directory (`./plan.md`, `./artifacts/...`; from a file already inside `artifacts/`, use `../plan.md` for root docs and `./` for siblings). Use absolute paths only for `prompted_against` (in reviewer files), where absoluteness is the point.
- **Mirror, don't compute.** `task` and `size` are mirrored from `prepare.md`, and `task_date` from the directory name's date prefix, at authoring time. Do not invent a process to keep them in sync; if `prepare.md` changes, fix the others by hand or accept the drift.
- **`related` is for navigation, not provenance.** Each entry is `<path> (<one-line reason>)`. If a doc is the canonical anchor (parent), put it in `parent`, not `related`.

## Why

Three reasons this exists:

1. **Agentic search.** A `grep -l 'type: plan' .planning/` returns every plan across every task without reading bodies. Same for `task:`, `status: superseded`, `verdict: request-changes`.
2. **Cross-doc traceability.** `parent` and `related` form a navigable graph. A fresh session can walk from a `code-review-summary.md` back to the `brief.md` and `plan.md` it relates to.
3. **Auditability.** `created` / `last_updated` / `status` capture the artifact lifecycle without git archaeology.

## What NOT to add

- **Counts that drift** (e.g., "open questions: 3") — the body has it; the frontmatter shouldn't lie.
- **Free-form tags / categories** — keep the schema closed. New fields require updating this reference.
- **PII / secrets** — briefs are published to GitHub Issues/PRs and broadly scanned; treat frontmatter as public.
