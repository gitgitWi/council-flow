---
name: cleanup
description: Tear down a finished task's transient resources — kill the dev server / e2e / Playwright processes it started, remove the git worktree, prune stale preview deployments (keeping the last N), and note the cleanup on the parent issue. Use once a task's PR is merged (or abandoned) and you want the workspace and running resources reclaimed. Recommend-only — never auto-invoked by another skill; the user starts it. Triggers on "정리해줘", "리소스 정리", "worktree 제거", "cleanup", "teardown", "clean up the task", "e2e 종료".
---

# flow:cleanup — Post-task teardown

The end of a flow task leaves transient state behind: a dev server or e2e run still holding a port, a Playwright/agent-browser process, an isolated worktree, and (for deployable projects) preview deployments piling up per branch. Cleanup reclaims all of it in one deliberate pass.

**Recommend-only.** No skill auto-invokes cleanup — `flow:deploy` and `flow:orchestrate` *mention* it as the next step, but the user starts it. It is destructive (removes a worktree, kills processes), so it always runs by explicit intent, usually in its own session after the PR is merged.

## When to run

- The task's **PR is merged** (or explicitly abandoned) — the branch's work is durable in `main`, or intentionally dropped.
- You have background resources from the task still running (dev server, e2e watcher, browser automation).
- Worktrees / preview deployments from finished phases are accumulating.

Do **not** run cleanup on a task still in progress, or on a PR awaiting review whose worktree you still need.

## Preconditions (check first)

1. **Confirm the work is durable.** The PR is merged, or the user confirms the branch is being abandoned. If unmerged commits exist that aren't on any remote, **stop and surface them** — do not remove a worktree that would lose work.
2. **Confirm the worktree is clean** (`git -C <worktree> status --porcelain`). Uncommitted changes → show them and ask before removing. **Note:** `.flow/tasks/` is gitignored, so its contents do **not** appear in porcelain — a "clean" result does not mean the worktree holds nothing you care about. Explicitly check `.flow/tasks/<date>-<task>/artifacts/` for anything unpublished (secrets, reusable e2e scripts a browser-tester left, Korean summaries) before Step 2 deletes it with the worktree.
3. **Identify what the task started.** Look for the dev server / e2e / Playwright processes and preview deployments tied to this task before killing anything broad.

## Steps

### 1 — Stop running processes

Kill only what this task started; don't sweep unrelated processes.

- Dev servers / watchers (the task's port) and e2e/Playwright/agent-browser runners.
- Prefer the tool's own stop path (e.g. stop a `run_in_background` task) over a blind `pkill`. If you must match by pattern, scope it tightly (port, project path) and show what will be killed first.

### 2 — Salvage, then remove the worktree

`.flow/tasks/<date>-<task>/` lives **inside** the worktree, so `git worktree remove` deletes it — including gitignored artifacts. **Salvage first:** if `artifacts/` holds anything worth keeping (a reusable e2e script, a review summary), copy it out or post it to the PR/issue before removing. The durable record of non-code docs is meant to be on GitHub, not the worktree.

```bash
# from the canonical repo (not inside the worktree being removed)
git worktree remove <repo-parent>/<repo>.worktrees/<task>   # add --force only with explicit consent for a dirty tree
git worktree prune
git branch -d <branch>     # merge-detected branches only
```

Branch deletion: `git branch -d` only succeeds when git can see the branch was merged. A **squash-merged** branch looks unmerged to git, so `-d` fails — after confirming the PR is actually merged, use `git branch -D <branch>` with the user's consent. Never remove a worktree you are currently `cd`'d into — move to the canonical repo first (`git rev-parse --show-toplevel` from a normal checkout).

### 3 — Prune preview deployments (deployable projects only)

If the project auto-deploys previews per branch/PR (Cloudflare Worker, ACA, Vercel, an image registry), the merged branch's previews are now stale. **Retain the last N** (per project policy, default keep-10) and prune older ones rather than deleting on every merge. Skip this step entirely for non-deployable repos.

### 4 — Record the teardown

If the task tracked work under a parent GitHub Issue, add a short Korean comment noting what was cleaned (worktree removed, resources stopped, previews pruned) so the issue reflects the closed-out state. Note that removing the worktree in Step 2 already deleted `.flow/tasks/<date>-<task>/` along with it — that is expected (it was gitignored local scratch, and the durable copy lives in the PR/issue). If the task worked **in-place** (no worktree), `.flow/tasks/` is still on disk — remove it only if the user asks.

## What NOT to do

- **Don't run automatically.** Cleanup is destructive; always by explicit user intent.
- **Don't remove a worktree with unmerged/uncommitted work** without showing it and getting consent.
- **Don't blanket-kill processes.** Scope to what the task started.
- **Don't delete all preview deployments** — retain the last N.

## Reference

- Worktree layout & git policy: `../../references/directory-structure.md`
- Project defaults (worktree root, retention N): `../../references/config.md`
- Deploy (mentions cleanup as the next step): `../deploy/SKILL.md`
