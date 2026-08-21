---
name: commit-pr
description: The fast commit → push → open-or-update-PR loop, with the standard rules baked in so they never need retyping. Use whenever the user says "commit", "commit and push", "push", "PR 올려", "PR 갱신", "update the PR", or wants the current changes shipped to a pull request. Splits work into atomic Conventional Commits, pushes the branch, and opens a Korean PR (or updates the existing one) with the project's assignee/labels/milestone. This is the everyday "ship what I have" command — distinct from flow:deploy, which opens the PR and then offers the code-review brief step.
---

# flow:commit-pr — Commit, push, open/update PR

The everyday shipping loop. Codifies the rules the user repeats every session so a bare "commit and push" does the right thing without re-stating conventions.

For the full close-out (open the PR, then write a code-review brief for the user's reviewer agents), use `flow:deploy` instead. This skill is the lighter "just get my changes onto the PR" path.

## 1. Commit — atomic + Conventional

- **Split by logical unit.** Never bundle unrelated concerns, even small ones. One concern → one commit. If the diff spans several concerns, make several commits.
- **Conventional Commits**: `<type>(<scope>): <subject>`. Types/scopes per `../../references/commit-conventions.md`.
- **Body 1–3 lines, max 5.** Do not write essays. Match recent history's style (`git log --oneline -10`).
- TDD pairs where they apply (`test(...)` then `feat(...)`) — see `../../references/tdd-policy.md`.
- Stage deliberately (`git add <paths>`), not `git add -A`, so each commit stays scoped.
- Every commit message ends with the session's required trailers (Co-Authored-By + Claude-Session).

## 2. Push

- Push the current task branch to `origin`. If it has no upstream, set it (`git push -u origin <branch>`).
- Never push to the default branch directly — if somehow on `main`, stop and branch first.

## 3. Open or update the PR

Check first whether a PR already exists for the branch (`gh pr view --json number,url,state` or `gh pr list --head <branch>`).

**If none exists — open one:**
- Title + body in **Korean** (user/team-facing).
- Body: short summary of what changed and why, plan-vs-implementation deltas if any, verification done. Lists over prose.
- assignee + labels (reuse existing, create only if needed) + milestone per the project's rules (from `.flow/config.yaml` or the brief's working rules).
- Use the `gh` CLI directly (not MCP).
- **Link the task's GitHub Issue, not local docs.** Read `issue:` / `issue_role:` from the task's `brief.md` frontmatter and write `Closes #<N>` (leaf) or a bare `#<N>` (parent/umbrella). Never link a `.flow/tasks/...` path — it is gitignored and dead for reviewers. No screenshots section: `gh` cannot attach images. Same rules as `flow:deploy` Step 2.
- End the PR body with the Claude Code footer.

**If one exists — update it:**
- Push the new commits (already done in step 2 — the PR updates automatically).
- If the scope/summary changed materially, update the PR body (`gh pr edit --body-file`) — append a short "추가 반영" section rather than rewriting history.

## 4. Report

Tell the user: the commits made (one line each), the branch, and the PR URL. If the user will want the multi-LLM review, point them at `flow:deploy` (run in a fresh session).

## Guardrails

- Confirm the active `gh` account is correct for the target repo before any `gh` write.
- Do not force-push unless the user explicitly asks.
- Do not open a PR from a dirty index — commit or stash first; surface anything uncommitted.

## Reference

- Commit conventions: `../../references/commit-conventions.md`
- TDD policy: `../../references/tdd-policy.md`
- Doc style (Simplified Technical English, lists over tables): `../../references/doc-style.md`
- Full close-out (PR + review brief): `flow:deploy` + `flow:code-review-brief`
