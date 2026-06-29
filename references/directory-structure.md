# `.planning/` Directory Convention

All flow skills read and write to a single per-task directory. Predictable paths matter more than clever organization — any coding agent picking up the work mid-stream must locate the artifacts without guessing.

## Layout

```
<repo-root>/.planning/<yyyy-mm-dd>-<kebab-task-name>/
├── brief.md             # kickoff framing: goal, acceptance + verification, scope, direction diagram
├── prepare.md           # task name, branch, base, size estimate, started-at
├── plan.md              # current canonical plan (English)
├── tasks.md             # behavior checkbox list (1-line + pseudo-code test or Mermaid) — progress source of truth
├── research.md          # optional, written by `flow:research`
├── brainstorm.md        # optional, multi-LLM brainstorming synthesis (size L always,
│                        #   size M when cross-module / security-sensitive / public-surface)
└── artifacts/           # all supporting / derived / historical artifacts, one flat folder
    ├── plan.ko.md                  # Korean reading copy of plan.md, written by `flow:plan`
    ├── tasks.ko.md                 # Korean reading copy of tasks.md
    ├── code-review-brief.md        # PR review brief (user runs their agents on it), `flow:code-review`
    ├── code-review-<agent>.md      # an external agent's returned review, saved by the user
    ├── code-review-summary.md      # Claude's synthesis of returned reviews, Korean
    ├── brainstorm-brief.md         # optional brief for external brainstorm agents
    ├── brainstorm-<agent>.md       # an external agent's returned brainstorm, if any
    ├── research-<agent>.md         # external research subagent output, if any
    ├── plan.v1.md                  # superseded plan version (history)
    ├── plan.v1.ko.md               # its Korean translation
    ├── tasks.v1.md
    └── tasks.v1.ko.md
```

Canonical live documents (`brief.md`, `prepare.md`, `plan.md`, `tasks.md`, `research.md`, `brainstorm.md`) sit at the task-directory root. Everything else — briefs, returned reviews, Korean summaries, translations, superseded versions — is a supporting artifact and lives in the single flat `artifacts/` folder. Flat, not nested: the filename prefix (`code-review-`, `brainstorm-`, `research-`) and suffix (`.ko.md`, `.v<N>.md`) carry the categorization that nested folders used to.

## Naming rules

- **Date prefix**: `yyyy-mm-dd` reflecting when prep ran. Local timezone is fine.
- **Task name**: kebab-case, derived from the task goal. Match the branch's name-portion (e.g. branch `feature/add-google-login` → task name `add-google-login`).
- **Standalone PR review variant**: when `flow:code-review` runs on a PR that was not created through this workflow (no matching task directory), it creates `<repo-root>/.planning/<yyyy-mm-dd>-pr<N>-review/artifacts/code-review-brief.md` instead. The directory name encodes the PR number rather than a kebab task name. No `prepare.md`, `plan.md`, or `tasks.md` is required in this variant.
- **Versioning**: when `plan.md` is substantively revised, move the old plan to `artifacts/plan.v<N>.md` (and its translation to `artifacts/plan.v<N>.ko.md`) before writing the new one. Small in-place edits don't need a version bump.

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

The `.planning/` directory is **not committed** — it is local working memory. The shippable record of non-code documents lives in the **GitHub ecosystem** (Issues / PR bodies / wiki), not in the repo. Add `.planning/` to the project's `.gitignore`; the flow skills create and read these files locally but never commit them.

- Briefs, plans, research, and review summaries are published as **GitHub Issues** (or the PR body) when they need to be shared — that is the durable copy.
- `flow:commit-pr` / `flow:deploy` stage **code changes only**; they never `git add .planning/`.
- Because `.planning/` is throwaway-on-disk, keep the canonical context in the Issue/PR so a fresh session (or a teammate) can reconstruct it.

## Language policy

- `brief.md`, `plan.md`, `tasks.md`, `research.md`, `prepare.md`, `brainstorm.md`: **English** (LLM-facing).
- Briefs published to GitHub (kickoff brief Issue, `artifacts/code-review-brief.md`), `artifacts/code-review-summary.md`: **Korean** (user/team-facing).
- `artifacts/plan.ko.md` and `artifacts/tasks.ko.md`: **Korean** (reading copies for the user).
- External agent output files (`artifacts/code-review-<agent>.md`, `artifacts/brainstorm-<agent>.md`): whatever the agent emits, no translation.
