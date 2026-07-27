---
name: deploy
description: Push the task branch and open a Korean pull request, then ask the user whether to run flow:code-review-brief and, on confirm, run it inline for the new PR. Use this whenever development for a flow task is done and the branch is ready for review. Even when the user says "just open a PR", finish by offering the review-brief step. Run in its own session from develop; do not bundle.
---

# flow:deploy — Push + open Korean PR + offer the review brief

Deploy is the closing skill. It is intentionally separate from develop so the PR reflects a clean, final diff rather than develop's intermediate state.

After opening the PR, deploy **asks** whether to write the code-review brief now and, on confirm, runs `flow:code-review-brief` inline for the new PR. Most of the time the next step after opening a PR is requesting a review on it, so proceeding right away (with a confirm) is the common path. The review-brief skill stays a separate skill so it is also reusable for arbitrary existing PRs. Deploy never runs reviewer CLIs or posts comments — the **user** runs their reviewer agent(s) against the brief.

## Preconditions

- All items in `tasks.md` are checked.
- Working tree is clean (no uncommitted changes).
- Branch is the task branch (not main).
- Tests pass locally. Run the project's test command and confirm green before pushing.

If any precondition fails, stop and tell the user. Do not "fix it up" silently.

## Step 1 — Push

```bash
git push -u origin "$(git branch --show-current)"
```

If the push fails because of upstream changes, do not force-push. Inform the user and ask whether to rebase.

## Step 2 — Open the PR (Korean body)

PR title: short, ≤ 70 chars, conventional-commit-flavored (`feat(auth): Google 로그인 지원 추가`).

PR body in Korean, using this template:

```markdown
## 개요
<1-3 줄 요약 — 무엇이 왜 바뀌었는지>

## 변경 사항
- ...
- ...

## 테스트
- [ ] Vitest 유닛/통합 테스트
- [ ] Playwright E2E (해당 시)
- [ ] 수동 확인: <어떤 시나리오를 어떻게 확인했는지>

## 관련 링크
- 작업 Issue: Closes #<N>
```

### 관련 링크 — resolve the Issue, never link a local path

The plan and brief are **not** shareable as files: `.flow/tasks/` is gitignored local working memory, so a reviewer clicking `.flow/tasks/<date>-<task>/plan.md` gets nothing. The GitHub **Issue** that `flow:kickoff` posted is the durable, linkable copy of the framing and plan — link that.

Resolve it in this order:

1. **`issue:` in `brief.md` frontmatter** of the task folder — kickoff Step 5 writes the full URL there. This is the normal path.
2. **Search GitHub** if the field is missing: `gh issue list --search "<task-name>" --state all --limit 5` and confirm the match with the user before using it.
3. **Ask the user** for the Issue number if neither resolves. If the task genuinely has no Issue (a `flow:quick` fast-lane fix, a standalone PR), **drop the `## 관련 링크` section entirely** rather than shipping a dead or empty link.

Write the reference according to `issue_role` in the same frontmatter:

- **`leaf`** (the common case — the Issue is this task) → `Closes #<N>`, so merging closes it.
- **`parent`** (an umbrella Issue from a kickoff split) → a bare `#<N>` reference and a line naming which sub-issue this PR covers. **Never `Closes` a parent** — it would close the umbrella while sibling sub-issues are still open.

Add other links only when they exist and are on GitHub: the base PR for a stacked PR, a preview-deployment URL, a related Issue. Rules that apply to every entry:

- **GitHub/HTTP URLs and `#N` references only.** No `.flow/tasks/...`, no absolute local paths, no worktree paths.
- `gh` cannot attach images or files to a PR — there is no screenshots/video section. If a UI change needs visual evidence, the user drags the image into the PR on the web UI themselves, or the `flow:browser-tester` findings go in as a comment. Do not add a placeholder section for something this skill cannot fill.

Apply PR metadata from `.flow/config.yaml` (`github.assignee`, `github.milestone`, `github.labels` — reuse existing repo labels, create only if needed). Create with HEREDOC for correct formatting:

```bash
gh pr create --title "<title>" \
  --assignee "<config assignee>" \
  --milestone "<config milestone>" \
  --label "<config label>" \
  --body "$(cat <<'EOF'
<body>
EOF
)"
```

Omit any flag with no configured value. Capture the PR number from the URL `gh pr create` prints.

## Step 3 — Ask, then run the review brief on confirm

After the PR is open, ask the user (one `AskUserQuestion`, default = yes):

> PR #<N> 열림. 이어서 `flow:code-review-brief`로 리뷰 brief를 만들까요?

- **Yes (default)** → invoke `flow:code-review-brief` for PR #<N> inline. The current branch matches the PR head and `.flow/tasks/<date>-<task>/` exists, so it resolves its output automatically. After it writes the brief, deploy is done.
- **No** → stop at the open PR and tell the user they can run `flow:code-review-brief` later.

Either way, deploy never runs reviewer CLIs or posts comments — once the brief exists, the **user** runs their reviewer agent(s) against it and posts to the PR.

## Step 4 — Dispatch the in-harness review lane (in parallel)

Deploy runs in the session where the PR now exists, so it — not `flow:orchestrate` (which has already ended by this point) — is what actually **dispatches the bundled in-harness review lane**. This is an *additive* fast pass that complements the user-run external review the brief sets up; it does not post anything.

Run these bundled tiers **concurrently** (a lane, not a sequence) against the PR diff:

- **`flow:reviewer`** (Fable) — general fresh-eyes review. Always applicable.
- **`flow:browser-tester`** (Sonnet) — real-browser QA. **Frontend changes only** — it no-ops otherwise.
- **`flow:react-reviewer`** (Fable/Opus) — composition/reuse audit. **React changes only** — it no-ops otherwise.

Each returns findings (it does **not** post). Collect them, and per the supervision model (`flow:orchestrate`) route small issues to an in-place fix and large ones to a follow-up. Skip the whole lane if the user only wanted the brief, or for a trivial diff. The frontend tiers self-gate, so dispatching all three on a non-frontend PR is harmless — the two frontend ones report "nothing to do."

## What NOT to do

- **Don't run the review brief without asking.** Ask once (default yes), then run on confirm.
- **Don't run reviewer CLIs or post comments.** That is the user's step, even after the brief is written.
- **Don't auto-merge.** The user merges after reviewing.
- **Don't bundle deploy with develop in the same session.** The PR should reflect a clean final diff.
- **Don't link `.flow/tasks/` paths from the PR body.** It is gitignored local memory — the link is dead for every reviewer. Link the GitHub Issue instead.
- **Don't add a screenshots/video section.** `gh` cannot attach images or files to a PR, so the section can only ever ship empty. The user adds visuals via the web UI if they want them.
- **Don't `Closes` a parent/umbrella Issue.** Check `issue_role` first; closing a parent orphans its open sub-issues.

## After merge — mention cleanup (don't run it)

Once the PR is merged, the task's worktree and any dev-server / e2e / preview-deployment resources are still around. Tell the user they can run `flow:cleanup` (in its own session) to tear them down — kill the processes, remove the worktree, prune stale previews. Like `flow:review-triage`, cleanup is **recommend-only**: mention it, never auto-invoke it.

## Reference

- Review brief skill: `../code-review-brief/SKILL.md`
- Post-task teardown: `../cleanup/SKILL.md`
- New multi-LLM model (brief → user-run agents): `../../references/multi-llm.md`
- Project defaults (`assignee`/`milestone`/`labels`): `../../references/config.md`
- Frontmatter schema (`issue` / `issue_role` on `brief.md`): `../../references/frontmatter.md`
- Why `.flow/tasks/` is never linked from GitHub: `../../references/directory-structure.md` (Git policy)
- Doc style (prefer lists over tables): `../../references/doc-style.md`
