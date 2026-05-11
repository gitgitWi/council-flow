---
name: deploy
description: Push the task branch, open a Korean pull request, run a multi-LLM code review, save each reviewer's output as a file, post a synthesized review to the PR with inline comments tagged by severity and model signature. Use this whenever development for a flow task is done and the branch is ready for review. Even when the user says "just open a PR", run the full flow — multi-LLM review is the point of this skill, not optional dressing. Run in its own session from develop; do not bundle.
---

# flow:deploy — PR + multi-LLM review

Deploy is the closing skill. It is intentionally separate from develop so the reviewer LLMs see a clean diff without develop's intermediate state in context.

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

## Step 3 — Gather the diff

```bash
git diff origin/main...HEAD > /tmp/flow-pr-diff.patch
gh pr view <PR> --json files --jq '.files[].path' > /tmp/flow-pr-files.txt
```

These two artifacts feed every reviewer prompt.

## Step 4 — Run multi-LLM code review in parallel

Three reviewers by default. Write their outputs to `<worktree>/.planning/<date>-<task>/code-reviews/`:

| File | Model |
|---|---|
| `code-gemini.md` | `gemini-3.1-pro` |
| `code-kimi.md` | `opencode-go/kimi-k2.6` |
| `code-deepseek.md` | `opencode-go/deepseek-v4-pro` |

Reuse the prompt below across reviewers; only the output file changes. Issue all three Bash calls in the same message to run in parallel.

```
You are reviewing a pull request. Focus on correctness, security, missed edge
cases, test coverage, and maintainability.

Diff: /tmp/flow-pr-diff.patch
Files changed: /tmp/flow-pr-files.txt
Plan context: <abs-path>/.planning/<date>-<task>/plan.md

Output format — Markdown with these sections:

## Top-level summary
2-3 sentences. Overall quality, any release-blocker concerns.

## Inline findings
For each issue, exactly this format:

### <file path>:<line number>
**Severity:** CRITICAL | MAJOR | MINOR | NIT | QUESTION
**Headline:** <one line>

<body — what is wrong, why, and what to change>

Use line numbers from the head (new) version. If a finding spans a range,
note it as "L<start>-L<end>" and use the starting line.

## Verdict
"merge as-is" | "merge after minor edits" | "request changes".
```

After the calls return, **verify each file exists and has content.** A silent CLI failure must not slip through. The full verification + fallback policy (pre-flight, exit code, empty output, failure-signature grep, quorum policy, FAILED.md record format) lives in `../../references/multi-llm.md` — apply it here verbatim.

Quick recap for code review specifically:

- Pre-flight (`command -v gemini` / `command -v opencode`); skip a missing CLI without aborting.
- Wrap each call with `timeout 600`, capture exit code; never let one failure kill the parallel batch.
- Verify each output: exit code 0, file non-empty, no `rate limit / unauthorized / model not found / ...` signature in the first 40 lines. Failures get a `code-<reviewer>.FAILED.md`.
- **≥ 2 valid reviews** → synthesize as normal; list the missing reviewer under `## 결손 리뷰어` in `code-summary.md`, and inline comments only attribute models that actually produced output.
- **1 valid review** → stop and ask the user (retry / swap reviewer / proceed as single-reviewer with explicit labelling). Do **not** post a single-reviewer code-review pretending it was multi-LLM.
- **0 valid reviews** → stop. Do not post any review. Surface failure records.

Posting a review with fewer than the original reviewer count is allowed; pretending the missing reviewer agreed is not. The model-signature footer on inline comments must list only the models that actually produced that finding.

## Step 5 — Synthesize code-summary.md (Korean)

Read each reviewer file once, extract findings, and write `code-reviews/code-summary.md` in Korean:

```markdown
# 코드 리뷰 요약 — <task>

## 전체 평가
<verdict 종합>

## 합의된 주요 이슈
- [CRITICAL] ... — Gemini, Kimi
- [MAJOR] ... — Kimi, DeepSeek
- ...

## 모델 간 의견이 갈리는 지점
이 부분이 가장 중요. 사용자가 판단해야 할 것.

## 인라인 코멘트 개수
- CRITICAL: N개
- MAJOR: N개
- MINOR: N개
- NIT: N개
- QUESTION: N개

## 머지 권장
- [ ] 권장 / 조건부 권장 / 비권장 + 이유

## 결손 리뷰어
(있을 때만 추가. 없으면 이 섹션 생략.)
- gemini-3.1-pro: rate limit (자세한 내용은 `code-gemini.FAILED.md`)

## 모델별 리뷰 원본
- [Gemini 3.1 Pro](./code-gemini.md)
- [Kimi K2.6](./code-kimi.md)
- [DeepSeek v4 Pro](./code-deepseek.md)
```

## Step 6 — Build the GitHub review payload

Aggregate inline findings across all three reviewers:

- **Dedupe** when multiple reviewers flagged the same file:line with the same concern. Sign the merged comment with all contributing models (`— signed: gemini-3.1-pro, kimi-k2.6`).
- **Keep separate** when reviewers flagged the same line but with different concerns. Two distinct comments are fine.
- **Filter** NIT comments if the count is overwhelming (>10). Keep them in the per-model files; only post the most important ones inline.

Each inline comment body **must** follow the format from `../../references/inline-review-posting.md`:

```
**[<SEVERITY>]** <headline>

<body in Korean>

— signed: <model-id>[, <model-id>]
```

Top-level review body is the contents of `code-summary.md`.

## Step 7 — Post the review

Use the `gh api` POST to `/repos/<owner>/<repo>/pulls/<PR>/reviews` with `event: "COMMENT"` and the inline comments array. Full payload shape and the line-number gotchas are in `../../references/inline-review-posting.md`.

After posting, verify:

```bash
gh pr view <PR> --json reviews --jq '.reviews[-1] | {state, comments: .comments | length}'
```

If the comment count is off (e.g., GitHub silently dropped some because of line-number mismatches), reconcile by re-running the lines that were dropped or posting them as a follow-up review.

## Step 8 — Commit the review artifacts

The `code-reviews/` files are part of the audit trail. Commit them on the branch:

```bash
git add .planning/<date>-<task>/code-reviews/
git commit -m "docs(review): add multi-LLM PR review artifacts"
git push
```

## What NOT to do

- **Don't auto-merge.** Deploy stops at "review posted". The user merges.
- **Don't post raw model output as the PR review.** Always go through `code-summary.md` synthesis.
- **Don't skip the Korean summary.** Even if all three reviewers said "merge as-is", write a one-line summary in Korean. Audit trail.
- **Don't post inline comments without the severity tag and model signature.** Downstream filtering depends on the fixed format.

## Reference

- Inline review posting mechanics: `../../references/inline-review-posting.md`
- Multi-LLM invocation: `../../references/multi-llm.md`
- Model registry: `../../references/models.md`
