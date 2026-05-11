# `.planning/` Directory Convention

All flow skills read and write to a single per-task directory. Predictable paths matter more than clever organization — any coding agent picking up the work mid-stream must locate the artifacts without guessing.

## Layout

```
<repo-root>/.planning/<yyyy-mm-dd>-<kebab-task-name>/
├── meta.md              # task name, branch, worktree, size estimate, started-at
├── plan.md              # current canonical plan (English, with optional Korean summary)
├── plan.v1.md           # previous plan version, kept only if plan-review supersedes
├── tasks.md             # GWT checklist — single source of truth for progress
├── research.md          # optional, written by `flow:research`
└── code-reviews/        # written by `flow:plan-review` and `flow:deploy`
    ├── plan-gemini.md
    ├── plan-kimi.md
    ├── plan-summary.md       # Claude's aggregated take, Korean
    ├── code-gemini.md
    ├── code-kimi.md
    ├── code-deepseek.md
    └── code-summary.md       # Claude's aggregated take, Korean
```

## Naming rules

- **Date prefix**: `yyyy-mm-dd` reflecting when prep ran. Local timezone is fine.
- **Task name**: kebab-case, derived from the task goal. Match the branch's name-portion (e.g. branch `feature/add-google-login` → task name `add-google-login`).
- **Versioning**: `plan-review` only renames the old plan to `plan.v1.md` when it makes substantive changes. If it just confirms the plan, no version bump.

## meta.md format

```markdown
---
task: add-google-login
branch: feature/add-google-login
worktree: /Users/.../est-works.worktrees/add-google-login
size: M
started: 2026-05-11
goal: |
  Allow users to sign in with Google in addition to email/password.
---

## Notes

(Free-form. Optional.)
```

`size`: one of `S`, `M`, `L` (see prep skill for criteria).

## Git policy

The `.planning/` directory **is committed**. It is part of the project's audit trail and lets teammates and future-Claude pick up where work left off. Keep individual files reasonable in size — split phase plans into separate files (`plan-phase-1.md`, `plan-phase-2.md`) when a single document approaches ~500 lines.

If a particular project does not want planning artifacts committed, add `.planning/` to `.gitignore` at the project level — the flow skills do not depend on commit status.

## Language policy

- `plan.md`, `tasks.md`, `research.md`, `meta.md`: **English** (LLM-facing). Optionally include a short Korean summary at the bottom if the user wants quick scanning.
- `code-reviews/plan-summary.md` and `code-reviews/code-summary.md`: **Korean** (user-facing — these are read by the human alongside Claude).
- Individual model review files (`*-gemini.md`, etc.): whatever the model emits, no translation.
