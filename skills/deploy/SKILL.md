---
name: deploy
description: Push the task branch, open a Korean pull request, then hand off to flow:code-review to write a review brief the user feeds to their own reviewer agent(s). Use this whenever development for a flow task is done and the branch is ready for review. Even when the user says "just open a PR", run the full flow — producing the review brief is the point of this skill, not optional dressing. Run in its own session from develop; do not bundle.
---

# flow:deploy — Push + open Korean PR + delegate to code-review

Deploy is the closing skill. It is intentionally separate from develop so the PR (and the review brief built from it) reflects a clean, final diff rather than develop's intermediate state.

The review-brief step lives in `flow:code-review`, which deploy invokes after opening the PR. Splitting the two means the review skill is reusable for arbitrary existing PRs (not just ones deploy just created). Deploy does **not** run reviewer CLIs — code-review writes a brief and the user runs their own reviewer agent(s).

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

## 스크린샷 / 영상
(UI 변경이 있는 경우)

## 관련 링크
- 플랜: `.planning/<date>-<task>/plan.md`
- 리뷰 brief: `.planning/<date>-<task>/artifacts/code-review-brief.md` (자동 생성 예정)
```

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

## Step 3 — Hand off to flow:code-review

Invoke `flow:code-review` with the PR number from Step 2. Because the current branch matches the PR's head and `.planning/<date>-<task>/` exists, code-review resolves its output to `.planning/<date>-<task>/artifacts/code-review-brief.md` automatically.

Tell the user:

> PR #<N> opened. Handing off to flow:code-review to write the review brief.

Then invoke the skill. Code-review gathers the diff, summarizes the change against the original intent/plan and the user's requests, and writes the review brief. Deploy's job ends there — the **user** runs their reviewer agent(s) against the brief and posts to the PR.

## What NOT to do

- **Don't run reviewer CLIs or post comments.** Code-review writes a brief; the user runs the agents.
- **Don't auto-merge.** The user merges after reviewing.
- **Don't bundle deploy with develop in the same session.** The PR/brief should reflect a clean final diff.
- **Don't skip opening the PR even when "just running review" was the user intent.** To get a brief for an existing PR, invoke `flow:code-review` directly — not deploy.

## Reference

- Review brief skill: `../code-review/SKILL.md`
- New multi-LLM model (brief → user-run agents): `../../references/multi-llm.md`
- Project defaults (`assignee`/`milestone`/`labels`): `../../references/config.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
