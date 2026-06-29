---
name: code-review-brief
description: Write the base material for a code review — a "review brief" for a pull request that the USER feeds to their own external agent(s) to post review/comments on GitHub. This skill does NOT perform the review itself and does NOT post comments; it prepares the document a reviewer works from. The flow agent gathers the diff, the changed-file list, a summary of major changes, and the original intent/plan plus the user's key requests, then writes multi-angle review prompts (UX, code quality, redundant or over-engineered implementation, security, stability) tailored to the change. Use to prepare a review for any PR, whether just opened by flow:deploy or already on GitHub. Triggers on "코드리뷰 준비", "리뷰 brief 만들어줘", "PR 리뷰 자료 작성", "prep a review for PR #N".
---

# flow:code-review-brief — Prepare the base material for a PR review

This skill **prepares the base material** a reviewer needs — it does not run the review itself. It writes a **review brief**: the diff facts, change summary, original intent, and the lenses to review through. The **user** then runs their preferred agent(s) (Antigravity, Codex, Claude Code, …) against the brief to post review/comments on the GitHub PR.

> **The flow agent does not run reviewer CLIs and does not post comments.** The old auto-dispatch mechanism is deprecated (Gemini CLI discontinued; Antigravity has no non-interactive mode; opencode overhead is high). Diversity comes from the user running the agents they choose. See `../../references/multi-llm.md`.

`flow:deploy` **asks** whether to run this skill after opening a PR and runs it on confirm; you can also invoke it directly on any existing PR.

## Inputs

1. **PR number** — auto-detect from the current branch (`gh pr view --json number --jq .number`); ask if there is none.
2. **Context** — if inside a flow task worktree, read `brief.md` / `plan.md` for original intent and the user's requests. Otherwise work from the diff + PR description alone.
3. **`.flow/config.yaml`** — read `review.agents` to suggest an agent→lens split **in chat** (this goes to the user, not into the brief).

## Preconditions

- `gh` authenticated against the PR's repo; confirm the active account is correct.
- PR exists and is open (warn if closed/merged).
- If `gh` is unauthenticated or the PR is missing, stop and tell the user. Do not paper over it.

## Output location

- **Flow task worktree** (branch matches the PR head, `.planning/<date>-<task>/` exists) → `.planning/<date>-<task>/artifacts/code-review-brief.md`.
- **Standalone** → `.planning/<YYYY-MM-DD>-pr<N>-review/artifacts/code-review-brief.md` in the current worktree.

Print the resolved path before writing.

## Step 1 — Gather the diff and facts

```bash
PR=<number>
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName)
mkdir -p "$OUT_DIR"
gh pr diff "$PR" > "$OUT_DIR/_pr-diff.patch"
gh pr view "$PR" --json files  --jq '.files[].path'                      > "$OUT_DIR/_pr-files.txt"
gh pr view "$PR" --json additions,deletions,title,body --jq '.'          > "$OUT_DIR/_pr-meta.json"
```

Use `gh pr diff` (handles non-`main` bases and out-of-sync local branches). Empty diff → stop, nothing to review.

Read the diff and changed files yourself (or via a Sonnet subagent for a large diff — return a digest) to write an accurate change summary. Do not guess from filenames.

## Step 2 — Write the review brief (Korean)

Write `code-review-brief.md`. It is user/team-facing and fed to the agents the user runs, so write it in **Korean**. Frontmatter first (schema in `../../references/frontmatter.md`):

```yaml
---
title: "코드리뷰 brief — PR #<N>"
type: code-review-brief
task: <kebab task OR pr<N>-review>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
pr: <N>
related:
  - ../plan.md        # omit if no plan context
  - ../brief.md       # omit if none
---
```

Body:

```markdown
# 코드리뷰 brief — PR #<N>: <제목>

## 작업한 파일
- `path/a.ts` — <한 줄 변경 요지>
- `path/b.ts` — <…>
(추가/삭제 라인 수 요약)

## 주요 변경사항 요약
- <핵심 변경 3~7개 bullet. 무엇을, 왜.>
- 흐름이 비자명하면 Mermaid 다이어그램 1개 첨부 (../../references/mermaid.md).

## 원래 의도 / 플랜
- <brief.md / plan.md / 이슈에서: 이 작업의 목표와 수용 기준>

## 사용자 주요 요청사항
- <세션에서 사용자가 강조한 제약·선호. 리뷰어가 의도를 오해하지 않도록.>

## 리뷰 관점 (작업 성격에 맞는 것만)
아래 관점으로 다각도 분석을 요청한다. 각 발견은 `파일:라인 — [심각도] 한 줄 + 근거 + 제안` 형식.
- **UX** — 사용자 경험/접근성/엣지 상태에 영향이 있는가? (UI 변경 시)
- **코드 퀄리티** — 가독성, 네이밍, 응집도, 테스트 커버리지, 프로젝트 패턴 부합.
- **불필요/과잉 구현** — 다른 곳에 이미 유사 구현이 있는데 중복했는가? 언어/프레임워크/라이브러리가 간단히 제공하는 걸 굳이 low-level로 구현했는가?
- **보안** — 인증/인가, 입력 검증, 비밀값, 의존성 표면.
- **안정성** — 에러/타임아웃/동시성/부분 실패 경로, 회귀 위험.
```

The brief ends with the review lenses — it contains **only review material**. The reviewing agent is given a link to this document and reviews directly, so do **not** add orchestration content to it: no "which agents to run", no agent→lens split, no posting-mechanics pointer. Keep it tight — a brief, not a report. Tailor the "리뷰 관점" list to the change (drop UX for a pure build-script PR, emphasize 보안 for auth, etc.).

## Step 3 — Hand off (chat only)

In the **chat** (not the document) tell the user:

- The brief path (so they can link the reviewing agent to it).
- A one-line change summary.
- A suggested **agent→lens split** based on `.flow/config.yaml` `review.agents` — e.g. "Codex = 보안/안정성, Antigravity = UX/퀄리티, Claude Code = 코드 퀄리티". This suggestion lives in the chat only; it is deliberately kept out of the brief.

Do **not** post anything to GitHub yourself. If the user later brings reviewer output back, save it under `artifacts/` and help triage — but the user posts to the PR.

## Step 4 — Do not commit the brief

`.planning/` is gitignored — the brief is local working memory, not a repo artifact. **Never `git add` it.** If the brief should be shared, post it (or its key points) to the PR as a comment or to a GitHub Issue — that is the durable copy. See `../../references/directory-structure.md` (Git policy).

## What NOT to do

- **Don't run reviewer CLIs or post PR comments.** Write the brief; the user runs the agents.
- **Don't auto-merge.**
- **Don't invent file:line references or change summaries** — read the diff.
- **Don't put orchestration in the brief.** No "run these agents", no agent→lens split, no posting guide — those go to chat. The brief is review material only.
- **Don't pad the brief.** Lenses irrelevant to the change are noise; cut them.

## Reference

- New multi-LLM model (brief → user-run agents): `../../references/multi-llm.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Project defaults (`review.agents`, for the chat suggestion): `../../references/config.md`
- Mermaid: `../../references/mermaid.md`
