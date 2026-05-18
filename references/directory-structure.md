# `.planning/` Directory Convention

All flow skills read and write to a single per-task directory. Predictable paths matter more than clever organization — any coding agent picking up the work mid-stream must locate the artifacts without guessing.

## Layout

```
<repo-root>/.planning/<yyyy-mm-dd>-<kebab-task-name>/
├── meta.md              # task name, branch, worktree, size estimate, started-at
├── plan.md              # current canonical plan (English)
├── tasks.md             # GWT checkbox list — single source of truth for progress
├── research.md          # optional, written by `flow:research`
├── brainstorm.md        # optional, multi-LLM brainstorming synthesis (size L always,
│                        #   size M when cross-module / security-sensitive / public-surface)
├── brainstorms/         # raw per-model brainstorming outputs, written by `flow:plan`
│   ├── architecture-gemini.md
│   ├── risk-kimi.md
│   └── security-deepseek.md  # size L only by default
├── review/              # written by `flow:plan-review` and `flow:code-review`
│   ├── plan-gemini.md
│   ├── plan-kimi.md
│   ├── plan-summary.md       # Claude's aggregated take, Korean
│   ├── code-gemini.md
│   ├── code-kimi.md
│   ├── code-deepseek.md
│   └── code-summary.md       # Claude's aggregated take, Korean
├── translates/          # Korean translations of plan.md and tasks.md
│   ├── plan.ko.md
│   └── tasks.ko.md
└── versions/            # superseded plan/tasks versions and their translations
    ├── plan.v1.md
    ├── plan.ko.v1.md
    ├── tasks.v1.md
    └── tasks.ko.v1.md
```

## Naming rules

- **Date prefix**: `yyyy-mm-dd` reflecting when prep ran. Local timezone is fine.
- **Task name**: kebab-case, derived from the task goal. Match the branch's name-portion (e.g. branch `feature/add-google-login` → task name `add-google-login`).
- **Standalone PR review variant**: when `flow:code-review` runs on a PR that was not created through this workflow (no matching task directory), it creates `<repo-root>/.planning/<yyyy-mm-dd>-pr<N>-review/review/` instead. Same internal layout (reviewer files + `code-summary.md`); the directory name encodes the PR number rather than a kebab task name. No `meta.md`, `plan.md`, or `tasks.md` is required in this variant.
- **Versioning**: `plan-review` moves the old plan to `versions/plan.v<N>.md` (and its translation to `versions/plan.ko.v<N>.md`) only when substantive changes apply. If it just confirms the plan, no version bump.

## Frontmatter

Every document in `.planning/<date>-<task>/` carries a YAML frontmatter block — `title`, `type`, `task`, `task_date`, `created`, `last_updated`, `status`, `size`, `parent`, `related`, plus per-type fields (versioning for `plan`/`tasks`, reviewer/verdict for `review/*`, etc.). The schema is the single source of truth for agentic search across tasks; see `frontmatter.md` for the full field list and per-type extensions.

## meta.md format

```markdown
---
title: "Meta — Add Google login"
type: meta
task: add-google-login
task_date: 2026-05-11
created: 2026-05-11
last_updated: 2026-05-11
status: active
size: M
parent: ../../  # the repo root (no further parent)
related: []
branch: feature/add-google-login
worktree: /Users/.../est-works.worktrees/add-google-login
base: main
started: 2026-05-11
goal: |
  Allow users to sign in with Google in addition to email/password.
---

## Notes

(Free-form. Optional.)
```

`size`: one of `S`, `M`, `L` (see prep skill for criteria). Other per-type fields are documented in `frontmatter.md`.

## Git policy

The `.planning/` directory **is committed**. It is part of the project's audit trail and lets teammates and future-Claude pick up where work left off. Keep individual files reasonable in size — split phase plans into separate files (`plan-phase-1.md`, `plan-phase-2.md`) when a single document approaches ~500 lines.

If a particular project does not want planning artifacts committed, add `.planning/` to `.gitignore` at the project level — the flow skills do not depend on commit status.

## Language policy

- `plan.md`, `tasks.md`, `research.md`, `meta.md`, `brainstorm.md`: **English** (LLM-facing).
- `review/plan-summary.md` and `review/code-summary.md`: **Korean** (user-facing — these are read by the human alongside Claude).
- `translates/plan.ko.md` and `translates/tasks.ko.md`: **Korean** (translated copies of plan.md and tasks.md for user scanning).
- Individual model output files (`review/*-gemini.md`, `brainstorms/*-gemini.md`, etc.): whatever the model emits, no translation.
