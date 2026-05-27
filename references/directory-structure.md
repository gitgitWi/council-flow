# `.planning/` Directory Convention

All flow skills read and write to a single per-task directory. Predictable paths matter more than clever organization — any coding agent picking up the work mid-stream must locate the artifacts without guessing.

## Layout

```
<repo-root>/.planning/<yyyy-mm-dd>-<kebab-task-name>/
├── prepare.md           # task name, branch, base, size estimate, started-at
├── plan.md              # current canonical plan (English)
├── tasks.md             # GWT checkbox list — single source of truth for progress
├── research.md          # optional, written by `flow:research`
├── brainstorm.md        # optional, multi-LLM brainstorming synthesis (size L always,
│                        #   size M when cross-module / security-sensitive / public-surface)
└── artifacts/           # all supporting / derived / historical artifacts, one flat folder
    ├── plan.ko.md                  # Korean reading copy of plan.md, written by `flow:plan`
    ├── tasks.ko.md                 # Korean reading copy of tasks.md
    ├── plan-review-summary.md      # Claude's aggregated plan-review take, Korean
    ├── plan-review-gemini.md       # per-reviewer plan-review output
    ├── plan-review-kimi.md
    ├── code-review-summary.md      # Claude's aggregated code-review take, Korean
    ├── code-review-gemini.md       # per-reviewer code-review output
    ├── code-review-kimi.md
    ├── code-review-deepseek.md
    ├── brainstorm-architecture-gemini.md  # raw per-model brainstorming output, `flow:plan`
    ├── brainstorm-risk-kimi.md
    ├── brainstorm-security-deepseek.md     # size L only by default
    ├── research-gemini.md          # external-LLM research output, if any
    ├── plan.v1.md                  # superseded plan version (history)
    ├── plan.v1.ko.md               # its Korean translation
    ├── tasks.v1.md
    └── tasks.v1.ko.md
```

Canonical live documents (`prepare.md`, `plan.md`, `tasks.md`, `research.md`, `brainstorm.md`) sit at the task-directory root. Everything else — per-reviewer outputs, Korean summaries, translations, superseded versions, raw per-model brainstorming dumps, run logs — is a supporting artifact and lives in the single flat `artifacts/` folder. Flat, not nested: the filename prefix (`plan-review-`, `code-review-`, `brainstorm-`, `research-`) and suffix (`.ko.md`, `.v<N>.md`) carry the categorization that nested folders used to.

## Naming rules

- **Date prefix**: `yyyy-mm-dd` reflecting when prep ran. Local timezone is fine.
- **Task name**: kebab-case, derived from the task goal. Match the branch's name-portion (e.g. branch `feature/add-google-login` → task name `add-google-login`).
- **Standalone PR review variant**: when `flow:code-review` runs on a PR that was not created through this workflow (no matching task directory), it creates `<repo-root>/.planning/<yyyy-mm-dd>-pr<N>-review/artifacts/` instead. Same internal layout (reviewer files + `code-review-summary.md`); the directory name encodes the PR number rather than a kebab task name. No `prepare.md`, `plan.md`, or `tasks.md` is required in this variant.
- **Versioning**: `plan-review` moves the old plan to `artifacts/plan.v<N>.md` (and its translation to `artifacts/plan.v<N>.ko.md`) only when substantive changes apply. If it just confirms the plan, no version bump.

## Frontmatter

Every document in `.planning/<date>-<task>/` carries a YAML frontmatter block — `title`, `type`, `task`, `task_date`, `created`, `last_updated`, `status`, `size`, `parent`, `related`, plus per-type fields (versioning for `plan`/`tasks`, reviewer/verdict for `artifacts/*-review-*`, etc.). The schema is the single source of truth for agentic search across tasks; see `frontmatter.md` for the full field list and per-type extensions.

## prepare.md format

```markdown
---
title: "Prepare — Add Google login"
type: prepare
task: add-google-login
last_updated: 2026-05-11
status: active
size: M
parent: ../../  # the repo root (no further parent)
related: []
branch: feature/add-google-login
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

- `plan.md`, `tasks.md`, `research.md`, `prepare.md`, `brainstorm.md`: **English** (LLM-facing).
- `artifacts/plan-review-summary.md` and `artifacts/code-review-summary.md`: **Korean** (user-facing — these are read by the human alongside Claude).
- `artifacts/plan.ko.md` and `artifacts/tasks.ko.md`: **Korean** (translated copies of plan.md and tasks.md for user scanning).
- Individual model output files (`artifacts/plan-review-gemini.md`, `artifacts/brainstorm-*-gemini.md`, etc.): whatever the model emits, no translation.
