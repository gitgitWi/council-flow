---
name: review-triage
description: Triage and address code-review feedback on a pull request. Fetches ALL feedback types — review summaries, inline review comments, review threads/discussions, and general PR conversation comments — then assesses each for validity and priority, writes a fix plan, and (after the user approves) applies the fixes as atomic commits. This is the counterpart to flow:code-review-brief — that skill prepares a review; this one processes the feedback that came back. Usually run in its own session, separate from the review. Recommend-only — never auto-invoked by another skill; the user starts it. Triggers on "리뷰 반영", "PR 코멘트 검토/정리", "리뷰 피드백 반영해줘", "address review comments", "PR #N 리뷰 반영".
---

# flow:review-triage — Triage and address PR review feedback

The closing-loop skill: take the comments a PR has accumulated, decide which are valid and how urgent, plan the fixes, and (after the user signs off) apply them. It is the counterpart to `flow:code-review-brief` (which *prepares* a review). This one *processes the feedback that came back*.

> **Recommend-only.** No skill auto-invokes this — the user starts it, usually in its own session after reviewers have left feedback. Keeping it independent means the triage sees the full, settled set of comments rather than a half-finished review.

## Inputs

1. **PR number** — auto-detect from the current branch (`gh pr view --json number --jq .number`); ask if there is none.
2. **`.flow/config.yaml`** — read defaults (assignee, etc.) if fixes will lead to a PR update.

## Preconditions

- `gh` authenticated against the PR's repo; confirm the active account.
- PR exists. If applying fixes, you should be on (or able to check out) the PR's head branch — confirm before editing.

## Step 1 — Gather ALL feedback (every type)

GitHub scatters PR feedback across several endpoints. Collect all of them; missing one drops real comments.

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)   # owner/name
PR=<number>
mkdir -p "$OUT_DIR"

# a) Review summaries + states (APPROVED / CHANGES_REQUESTED / COMMENTED)
gh pr view "$PR" --json reviews > "$OUT_DIR/_reviews.json"

# b) Inline review comments (anchored to a file:line, incl. replies)
gh api --paginate "repos/$REPO/pulls/$PR/comments" > "$OUT_DIR/_review-comments.json"

# c) General PR conversation comments (issue-style, not diff-anchored)
gh api --paginate "repos/$REPO/issues/$PR/comments" > "$OUT_DIR/_issue-comments.json"

# d) Review threads with resolution + outdated status (richest grouping)
gh api graphql -F owner="${REPO%/*}" -F name="${REPO#*/}" -F num="$PR" -f query='
  query($owner:String!,$name:String!,$num:Int!){
    repository(owner:$owner,name:$name){
      pullRequest(number:$num){
        reviewThreads(first:100){ nodes{
          isResolved isOutdated path line
          comments(first:50){ nodes{ author{login} body createdAt } } } } } } }' \
  > "$OUT_DIR/_review-threads.json"
```

Read these (or hand a large set to a Sonnet subagent for a digest). **Skip already-resolved threads** unless the user asks to revisit them. Dedupe comments that appear in more than one endpoint (a review thread's comments also show up in `pulls/.../comments`).

## Step 2 — Triage each item

For every distinct piece of feedback, judge two axes — **don't take comments at face value, verify against the actual code**:

- **Validity**: `valid` · `partially-valid` · `invalid (with reason)` · `needs-user-decision` (subjective / conflicts with intent / reviewers disagree).
- **Priority**: `P0` release-blocker (correctness, security, broken behavior) · `P1` should-fix (clear quality/robustness) · `P2` nice-to-have · `P3` skip (nit / out of scope / stylistic preference).

Cross-check each claim: open the cited `file:line`, confirm the issue is real and the suggested fix is correct. Flag reviewer-hallucinated paths or out-of-date (outdated thread) comments. Note where two comments conflict — that is a `needs-user-decision`.

## Step 3 — Write the triage + fix plan (Korean)

Write `artifacts/review-triage.md` (Korean — user-facing). Keep it scannable.

```markdown
# 리뷰 반영 검토 — PR #<N>

## 요약
- 총 코멘트 <n>건 → 반영 <a> · 보류/스킵 <b> · 사용자 판단 필요 <c>

## 반영 대상 (우선순위순)
- [P0] `file:line` — <지적 요지> → <수정 방향>. (출처: @reviewer, thread)
- [P1] `file:line` — <…> → <…>
- [P2] `file:line` — <…> → <…>

## 보류 / 스킵 (이유 포함)
- `file:line` — <지적> → 스킵: <근거 (무효/범위 밖/outdated 등)>

## 사용자 판단 필요
- <충돌하거나 주관적인 항목 — 어떤 선택지가 있고 무엇을 추천하는지>

## 수정 플랜
- <반영 대상들을 atomic 단위로 묶은 작업 순서. 각 단위 = 한 커밋.>
```

`.flow/tasks/` is gitignored — **do not commit this file**. It is local working memory.

## Step 4 — User checkpoint

Show the triage summary and the fix plan. **Wait for the user to confirm** what to apply, skip, and how to resolve `needs-user-decision` items. Do not start editing before sign-off — the whole point is the user steers which feedback is acted on.

## Step 5 — Apply the approved fixes

After approval, implement per the fix plan with `flow:develop` discipline:

- One logical unit per commit; Conventional Commits; body 1–3 lines (max 5). See `../../references/commit-conventions.md` and `../../references/tdd-policy.md`.
- Where a fix has a testable behavior, add/adjust the test first.
- Reference the addressed comment in the commit body when it clarifies intent (e.g. `addresses review: target=_blank handling`).
- Push with `flow:commit-pr` (the PR updates automatically).
- Optionally reply to / resolve the threads you addressed — but only the ones the user approved. Leaving resolution to the user is also fine; say which you touched.

For invalid / skipped comments, a short reply on the thread explaining why is courteous — offer to post it, don't do it silently.

## What NOT to do

- **Don't blindly apply every comment.** Triage validity first; reviewers are sometimes wrong or out of date.
- **Don't apply before the user checkpoint.** Plan → approve → fix.
- **Don't resolve threads the user hasn't approved**, and don't auto-merge.
- **Don't bundle unrelated fixes** into one commit.
- **Don't run this automatically from deploy/code-review-brief.** It is user-started.

## Reference

- Counterpart (prepares the review): `../code-review-brief/SKILL.md`
- Apply discipline: `../develop/SKILL.md`, `../../references/commit-conventions.md`, `../../references/tdd-policy.md`
- Push/PR update: `../commit-pr/SKILL.md`
- Thread reply/resolve mechanics: `../../references/inline-review-posting.md`
- Project defaults: `../../references/config.md`
