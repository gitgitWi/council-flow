# `.flow/tasks/` Directory Convention

All flow skills read and write to a single per-task directory. Predictable paths matter more than clever organization — any coding agent picking up the work mid-stream must locate the artifacts without guessing.

It holds more than plans: the plan and checklist, yes, but also research digests, returned agent output, review summaries, reusable e2e scripts, secrets, and logs. Read "task working memory", not "planning".

## Layout

The `.flow/` root is shared with the committed project config (`config.yaml`); only the `tasks/` subtree is throwaway local memory.

```
<repo-root>/.flow/
├── config.yaml          # per-project defaults — COMMITTED (see config.md)
└── tasks/               # gitignored: local working memory, one folder per task
    └── <yyyy-mm-dd>-<kebab-task-name>/
        ├── .gitignore   # `*` — self-ignoring, so nothing here can be staged
        └── …            # the per-task documents below
```

Inside one task folder:

```
<repo-root>/.flow/tasks/<yyyy-mm-dd>-<kebab-task-name>/
├── .gitignore           # `*` — written by kickoff setup; never delete it
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
    ├── code-review-brief.md        # PR review brief (user runs their agents on it), `flow:code-review-brief`
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

**Secrets** a task needs (tokens for a logged-in browser session, etc.) go in `artifacts/secret.*` and are referenced **by path** — never pasted into chat or committed. This is safe because the folder is ignored twice over (see Git policy); kickoff setup establishes both guards, so on an in-place task verify them before writing a secret.

## Naming rules

- **Date prefix**: `yyyy-mm-dd` reflecting when prep ran. Local timezone is fine.
- **Task name**: kebab-case, derived from the task goal. Match the branch's name-portion (e.g. branch `feature/add-google-login` → task name `add-google-login`).
- **Standalone PR review variant**: when `flow:code-review-brief` runs on a PR that was not created through this workflow (no matching task directory), it creates `<repo-root>/.flow/tasks/<yyyy-mm-dd>-pr<N>-review/artifacts/code-review-brief.md` instead. The directory name encodes the PR number rather than a kebab task name. No `prepare.md`, `plan.md`, or `tasks.md` is required in this variant.
- **Versioning**: when `plan.md` is substantively revised, move the old plan to `artifacts/plan.v<N>.md` (and its translation to `artifacts/plan.v<N>.ko.md`) before writing the new one. Small in-place edits don't need a version bump.

## Frontmatter

Every document in `.flow/tasks/<date>-<task>/` carries a YAML frontmatter block — `title`, `type`, `task`, `task_date`, `created`, `last_updated`, `status`, `size`, `parent`, `related`, plus per-type fields (versioning for `plan`/`tasks`, reviewer/verdict for `artifacts/*-review-*`, etc.). The schema is the single source of truth for agentic search across tasks; see `frontmatter.md` for the full field list and per-type extensions.

## prepare.md format

```markdown
---
title: "Prepare — Add Google login"
type: prepare
task: add-google-login
last_updated: 2026-05-11
status: active
size: M
parent: ../../../  # the repo root (no further parent)
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

The `.flow/tasks/` directory is **not committed** — it is local working memory holding plans, artifacts, logs, and sometimes secrets. The shippable record of non-code documents lives in the **GitHub ecosystem** (Issues / PR bodies / wiki), not in the repo.

**Two guards, both established by kickoff setup (`prep.sh`):**

1. **Root `.gitignore` entry** — `.flow/tasks/` in the project's `.gitignore`. Note the entry is `.flow/tasks/`, **not** `.flow/`: `.flow/config.yaml` is per-project config and is meant to stay committed. `prep.sh` decides whether to append by asking `git check-ignore`, not by grepping the file, so a broader existing rule (a global excludesfile, a parent `.gitignore`) is honored instead of duplicated.
2. **A self-ignoring `.gitignore` inside each task folder** — one line, `*`. This makes the folder unstageable regardless of what happens to the root entry (a bad merge, a re-`init`, a teammate's cleanup). Secrets under `artifacts/secret.*` depend on this; never delete it.

Consequences:

- Briefs, plans, research, and review summaries are published as **GitHub Issues** (or the PR body) when they need to be shared — that is the durable copy.
- `flow:commit-pr` / `flow:deploy` stage **code changes only**; they never `git add .flow/tasks/`.
- Because `.flow/tasks/` is throwaway-on-disk, keep the canonical context in the Issue/PR so a fresh session (or a teammate) can reconstruct it. **Never link a `.flow/tasks/...` path from a PR or Issue body** — no reviewer can open it.
- On an **in-place** task (setup skipped, no worktree), `prep.sh` did not run: verify both guards by hand before writing anything sensitive.

Verify at any time:

```bash
git check-ignore -v .flow/tasks/     # should print the matching rule
git status --porcelain | grep '\.flow/tasks' || echo "clean: nothing staged from .flow/tasks/"
```

## Language policy

- `brief.md`, `plan.md`, `tasks.md`, `research.md`, `prepare.md`, `brainstorm.md`: **English** (LLM-facing).
- Briefs published to GitHub (kickoff brief Issue, `artifacts/code-review-brief.md`), `artifacts/code-review-summary.md`: **Korean** (user/team-facing).
- `artifacts/plan.ko.md` and `artifacts/tasks.ko.md`: **Korean** (reading copies for the user).
- External agent output files (`artifacts/code-review-<agent>.md`, `artifacts/brainstorm-<agent>.md`): whatever the agent emits, no translation.
