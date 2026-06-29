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
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)   # owner/name — fill into the brief's 작업 규칙
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

````markdown
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

## 리뷰 관점 (참고용 — 여기에 국한하지 말 것)
전체 변경을 면밀히 검토하고, 발견한 모든 문제를 보고한다. 아래는 **출발점일 뿐**이니 이 항목에만 한정하지 말고, 파일·관점을 1:1로 묶지도 말 것.
- UX, 코드 퀄리티, 불필요/과잉 구현(중복·과한 low-level), 보안, 안정성, 그 외 눈에 띄는 무엇이든.

## 리뷰 작업 규칙 (이 문서만 보고 따를 것 — 별도 plugin/skill 없음 가정)
- 리뷰 결과는 **이 PR(#<N>)에 직접 등록**한다. 콘솔 출력만 하지 말 것.
- **GitHub CLI 직접 사용**(MCP 아님). 등록 전 `gh auth status`로 이 repo(`<owner>/<repo>`) 권한 계정인지 확인.
- 인라인 코멘트는 한 번의 review로 묶어 등록 (라인 번호는 diff의 head(new) 기준; diff 범위 밖은 총평으로):
  ```bash
  gh api repos/<owner>/<repo>/pulls/<N>/reviews -X POST --input review.json
  # review.json: {"event":"COMMENT","body":"<총평 + verdict 한 줄>",
  #   "comments":[{"path":"<file>","line":<n>,"body":"[심각도] 한 줄 + 근거 + 제안"}]}
  ```
  (리뷰 에이전트에 자체 PR 리뷰 기능이 있으면 그걸 써도 됨 — 결과가 PR에 남기만 하면 된다.)
- 코멘트 형식: `[심각도] 한 줄` + 근거 + 제안. 심각도: CRITICAL / MAJOR / MINOR / NIT / QUESTION.
- 총평(review body)에 한 줄 verdict 포함: 머지 가능 / 조건부 / 변경요청.
- **머지하지 말 것.** 리뷰·코멘트까지만.
````

The brief must be **self-contained**: the reviewing agent may not have this plugin or its references installed, so write the working rules **into** the brief (the `## 리뷰 작업 규칙` section) — substitute the real `<owner>/<repo>` and `<N>`. Source the posting recipe from `../../references/inline-review-posting.md` and inline the essentials; never leave a bare pointer the external agent can't open.

What still stays **out** of the brief is **user-orchestration**: which agents the user runs, and the agent→lens split — those go to chat (Step 3), not the document. Keep it tight — a brief, not a report.

Keep the **리뷰 관점 section rough**: a short, non-binding list of starting points, *not* an exhaustive checklist and *never* lenses pinned to specific files/changes. The worry is a narrow brief makes the agent review only what is listed — so explicitly invite it to go beyond. Don't pre-classify each file by lens; let the reviewer decide what matters where. Drop a lens only when it is plainly irrelevant (e.g. UX for a pure build-script PR).

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
- **Don't put user-orchestration in the brief.** Which agents the user runs and the agent→lens split go to chat — not the document. (The reviewer's *own* working rules, e.g. how to post to the PR, DO belong in the brief — it must be self-contained.)
- **Don't leave bare references the external agent can't open.** Inline the posting rules; the reviewer may not have this plugin.
- **Don't over-scope the review prompt.** Keep the lenses rough and non-binding; never pin a lens to a specific file/change or present them as an exhaustive checklist — that narrows the reviewer. Drop only plainly-irrelevant lenses.

## Reference

- New multi-LLM model (brief → user-run agents): `../../references/multi-llm.md`
- Inline review posting mechanics (source for the brief's 작업 규칙 — inline it, don't just link): `../../references/inline-review-posting.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Project defaults (`review.agents`, for the chat suggestion): `../../references/config.md`
- Mermaid: `../../references/mermaid.md`
