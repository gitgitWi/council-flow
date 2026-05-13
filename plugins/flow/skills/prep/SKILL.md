---
name: prep
description: Set up an isolated worktree, branch, and `.planning/<date>-<task>/` directory for a new development task before any planning or coding starts. Use this whenever the user kicks off non-trivial work — a feature, a fix, a refactor, anything that warrants its own branch. Even if the user does not explicitly say "create a worktree", invoke this when they describe a new task that will involve multiple changes; it is the standard entry point for the flow workflow.
---

# flow:prep — Task setup

You are setting up the workspace for a new task in the `flow` workflow. The goal is to land the user in an isolated worktree on a new branch, with the `.planning/` directory ready for the planner.

## Inputs to elicit (or infer)

Ask the user for these if they are not obvious from the conversation. If the conversation already contains the answer, do not ask again.

| Input | Required | Default |
|---|---|---|
| Task goal (one or two sentences in user's words) | yes | — |
| Task name (kebab-case, will become the branch name suffix) | yes | derive from goal |
| Type: `feature` \| `fix` \| `chore` \| `refactor` \| `docs` | yes | infer from goal |
| Base branch | no | `main` |
| Size estimate: `S` \| `M` \| `L` | no | infer (see below) |

### Size estimate heuristics

Ask one question if you cannot infer; otherwise just decide:

- **S** — single file edit, single component tweak, isolated bug fix, dependency bump. Usually no research needed.
- **M** — touches one module / a few files (≤ ~5), may add a small new surface area, no schema changes. Default for most feature work.
- **L** — crosses modules, introduces new domain concepts, database schema changes, public API changes, or replaces existing subsystems. Plan-review is strongly recommended at this size.

Record the size in `meta.md` (the prep script handles this). The plan and develop skills will look at `size` to decide whether to add research / plan-review steps.

## Run the prep script

The script handles worktree creation, branch creation, and `.planning/<date>-<task>/` scaffolding idempotently.

```bash
bash <plugin-dir>/scripts/prep.sh \
  --task <kebab-name> \
  --type <feature|fix|chore|refactor|docs> \
  --base <main-or-other> \
  --size <S|M|L> \
  --goal "<one-line goal>"
```

The script prints the worktree path on stdout. Capture it — every subsequent skill operates inside that path.

## After the script runs

1. **`cd` into the worktree.** Confirm with `git rev-parse --show-toplevel` that you are in the new worktree before doing anything else. The rest of the workflow assumes the working directory is the worktree.
2. **Verify** `.planning/<date>-<task>/meta.md` exists and contains the size/goal. If the user's goal needs more detail than fit on one line, append to the Notes section of meta.md.
3. **Report back to the user** with the worktree path, branch name, and size estimate, and ask whether to proceed to planning (`flow:plan`) or jump straight to develop (`flow:develop` — only sensible for size S).

## Reference

For `.planning/` directory conventions, see `../../references/directory-structure.md`. Do not invent alternate paths — predictable layout matters more than clever organization.

## Common pitfalls

- **Naming collision with an existing branch.** The script errors unless `--force` is set. Do not pass `--force` without asking the user; an existing branch usually means the task is already in progress and you should ask what to do (resume? rename?).
- **Running prep from inside another worktree.** That is fine — the script uses `git rev-parse --show-toplevel` to find the canonical repo location and creates the new worktree as a sibling.
- **Forgetting to cd.** If you stay in the original repo dir, every subsequent file change lands on the wrong branch. Always cd into the worktree before continuing.

## When to skip prep

The user may explicitly say "do this on the current branch". In that case skip the worktree but still create `.planning/<date>-<task>/` and `meta.md` so downstream skills have somewhere to write. Mention to the user that you are not creating an isolated worktree.
