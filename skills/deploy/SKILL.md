---
name: deploy
description: Push the task branch and open a Korean pull request, then recommend (do not auto-run) flow:code-review-brief so the user can prepare a review and run their own reviewer agent(s). Use this whenever development for a flow task is done and the branch is ready for review. Even when the user says "just open a PR", finish by pointing them at the review-brief step. Run in its own session from develop; do not bundle.
---

# flow:deploy — Push + open Korean PR

Deploy is the closing skill. It is intentionally separate from develop so the PR reflects a clean, final diff rather than develop's intermediate state.

Deploy's job ends at opening the PR. The review-brief step lives in `flow:code-review-brief` — deploy **recommends** it but does not auto-run it, because multi-LLM review is something the **user** drives (they pick which agents to run). Keeping it separate also makes the review-brief skill reusable for arbitrary existing PRs. Deploy never runs reviewer CLIs.

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

## Step 3 — Recommend the review brief (do not auto-run)

Deploy stops at the open PR. Do **not** invoke `flow:code-review-brief` automatically — multi-LLM review is user-driven. Just point the user at the next step:

> PR #<N> 열림. 코드리뷰를 받으려면 `flow:code-review-brief`로 리뷰 brief를 만든 뒤, 원하는 에이전트(들)를 직접 실행해 PR에 코멘트를 남기세요.

If the user explicitly says "just make the brief too", you may invoke `flow:code-review-brief` for PR #<N> inline — but the default is recommend-only. Either way, the **user** runs the reviewer agent(s) and posts to the PR; the flow agent never does.

## What NOT to do

- **Don't auto-run the review brief.** Recommend `flow:code-review-brief`; run it only if the user asks.
- **Don't run reviewer CLIs or post comments.** That is the user's step.
- **Don't auto-merge.** The user merges after reviewing.
- **Don't bundle deploy with develop in the same session.** The PR should reflect a clean final diff.

## Reference

- Review brief skill: `../code-review-brief/SKILL.md`
- New multi-LLM model (brief → user-run agents): `../../references/multi-llm.md`
- Project defaults (`assignee`/`milestone`/`labels`): `../../references/config.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
