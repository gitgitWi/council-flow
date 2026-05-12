---
name: deploy
description: Push the task branch, open a Korean pull request, then hand off to flow:code-review for the multi-LLM review pipeline. Use this whenever development for a flow task is done and the branch is ready for review. Even when the user says "just open a PR", run the full flow — multi-LLM review is the point of this skill, not optional dressing. Run in its own session from develop; do not bundle.
---

# flow:deploy — Push + open Korean PR + delegate to code-review

Deploy is the closing skill. It is intentionally separate from develop so reviewer LLMs see a clean diff without develop's intermediate state in context.

The review pipeline itself lives in `flow:code-review`, which deploy invokes after opening the PR. Splitting the two means the review skill is reusable for arbitrary existing PRs (not just ones deploy just created).

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
- 리뷰 요약: `.planning/<date>-<task>/code-reviews/code-summary.md` (자동 생성 예정)
```

Create with HEREDOC for correct formatting:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Capture the PR number from the URL `gh pr create` prints.

## Step 3 — Hand off to flow:code-review

Invoke `flow:code-review` with the PR number from Step 2. Because the current branch matches the PR's head and `.planning/<date>-<task>/` exists, code-review will resolve the output directory to `.planning/<date>-<task>/code-reviews/` automatically — same layout as before.

Tell the user:

> PR #<N> opened. Handing off to flow:code-review for the multi-LLM review pipeline.

Then invoke the skill. Code-review handles diff gathering, parallel reviewer dispatch, Korean summary synthesis, inline comment posting, and committing the review artifacts. Deploy's job ends once code-review takes over.

## What NOT to do

- **Don't run the review pipeline inline.** It lives in `flow:code-review` precisely so it can be reused for existing PRs and so the multi-LLM dispatch contract has a single source of truth. Don't paraphrase or re-implement it here.
- **Don't auto-merge.** Code-review stops at "review posted". The user merges.
- **Don't bundle deploy with develop in the same session.** Reviewer LLMs see cleaner diffs without develop's chain-of-thought in context.
- **Don't skip opening the PR even when "just running review" was the user intent.** If the user wants to review an existing PR, they should invoke `flow:code-review` directly — not deploy.

## Reference

- Code review pipeline: `../code-review/SKILL.md`
- Multi-LLM invocation: `../../references/multi-llm.md`
- Inline review posting mechanics: `../../references/inline-review-posting.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Model registry: `../../references/models.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
