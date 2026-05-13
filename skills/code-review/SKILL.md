---
name: code-review
description: Run a multi-LLM code review on a pull request — gather the diff, dispatch reviewer CLIs in parallel via the file-write contract, synthesize a Korean summary, and post inline comments tagged by severity and model signature. Use this for any PR review whether the PR was just opened by flow:deploy or already exists on GitHub. Even when the user says "review PR #N", "이 PR 리뷰해줘", "기존 PR 멀티 LLM 리뷰", or "second opinion on this PR", invoke this skill — multi-LLM diversity is the point, not optional dressing. Auto-resolves output directory: an existing flow task's `code-reviews/` if available, otherwise a fresh `.planning/<date>-pr<N>-review/code-reviews/`. Run in its own session so reviewer LLMs see a clean diff without orchestrator noise.
---

# flow:code-review — Multi-LLM PR review

Code-review is the review-only half of the deploy pipeline, extracted so it can run on **any** PR — not just one this session created.

`flow:deploy` invokes this skill automatically after opening the PR. You can also invoke it directly on any existing PR.

## Inputs

1. **PR number** — required, but auto-detected from the current branch if omitted (`gh pr view --json number --jq .number`). If the current branch has no PR, ask the user for the number.
2. **Plan context path** — optional. If invoked inside a flow task worktree, point at `.planning/<date>-<task>/plan.md`. If not available, omit; reviewers work from the diff alone.
3. **Output directory** — auto-resolved (see "Output directory resolution" below). Override only if the user asks.

## Preconditions

- `gh` CLI authenticated against the PR's repo (`gh auth status`).
- PR exists and is open. Closed/merged PRs can be reviewed but warn the user.
- `git` available; the diff is computed against the PR's base branch (`gh pr view <PR> --json baseRefName`).
- Reviewer CLIs (`gemini`, `opencode`) — pre-flight per `../../references/multi-llm.md`. Missing CLIs are skipped, not fatal.

If `gh` is unauthenticated or the PR does not exist, stop and tell the user. Do not "fix it up" silently.

## Output directory resolution

Resolve in this order; first match wins:

1. **Flow task worktree** — if the current working directory is inside a worktree whose branch matches the PR's `headRefName`, and `.planning/<date>-<task>/` exists, use `.planning/<date>-<task>/code-reviews/`. This is the deploy auto-invoke case.
2. **Standalone PR review** — otherwise create `.planning/<YYYY-MM-DD>-pr<N>-review/code-reviews/` in the **current worktree**. The date is today (local timezone). Example: `.planning/2026-05-12-pr42-review/code-reviews/`.

Print the resolved path before starting so the user knows where artifacts will land.

## Step 1 — Resolve PR + gather the diff

```bash
PR=<number>                     # from input or auto-detected
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName)
HEAD=$(gh pr view "$PR" --json headRefName --jq .headRefName)

mkdir -p "$OUT_DIR"
gh pr diff "$PR" > "$OUT_DIR/_pr-diff.patch"
gh pr view "$PR" --json files --jq '.files[].path' > "$OUT_DIR/_pr-files.txt"
```

Use `gh pr diff` (not `git diff origin/main...HEAD`) — it works even when the PR's base is not `main` and even when the local branch is out of sync.

If the diff is empty, stop. Tell the user the PR has no changes to review.

## Step 2 — Run multi-LLM code review in parallel

Three reviewers by default; ask the user before dispatching whether to add optional reviewers (see "Pre-flight + reviewer selection" below). Model IDs come from `../../references/models.md` — do not hardcode here. Default output paths:

- `code-codex.md` — `gpt-5.5` via `codex`
- `code-gemini.md` — `gemini-3.1-pro-preview` via `gemini`
- `code-kimi.md` — `opencode-go/kimi-k2.6` via `opencode run`

Optional (if user opts in):

- `code-deepseek.md` — `opencode-go/deepseek-v4-pro` via `opencode run` (deepest analysis, +10-15 min)
- `code-glm.md` — `opencode-go/glm-5.1` via `opencode run` (fast extra opinion, +5-7 min)

The dispatch contract (file-write, sentinel, runlog capture, heartbeat watcher, exit-code handling, failure signature grep, quorum policy) lives in `../../references/multi-llm.md`. Apply it verbatim — do not paraphrase or shortcut.

### Pre-flight + reviewer selection

Before dispatching any reviewer, do two things in sequence:

**1. Pre-flight** — check which CLIs are installed:

```bash
command -v codex    >/dev/null 2>&1 && echo "codex: ok"    || echo "codex: MISSING"
command -v gemini   >/dev/null 2>&1 && echo "gemini: ok"   || echo "gemini: MISSING"
command -v opencode >/dev/null 2>&1 && echo "opencode: ok" || echo "opencode: MISSING"
```

A missing default-trio CLI is skipped (quorum policy in `../../references/multi-llm.md` still applies — need ≥ 2 valid reviews to synthesize).

**2. Optional reviewer selection** — ask the user:

> Optional reviewers available — add any to the dispatch batch?
> - **DeepSeek v4 Pro** (`opencode-go/deepseek-v4-pro`) — deepest analysis, adds ~10-15 min
> - **GLM 5.1** (`opencode-go/glm-5.1`) — fast extra opinion, adds ~5-7 min

Wait for the user's response before dispatching. If the user says skip (or no response), proceed with the default trio only. Opted-in reviewers join the same parallel batch.

### Frontmatter (every generated document)

Each reviewer file and the synthesized `code-summary.md` carry frontmatter. Schema in `../../references/frontmatter.md`. Instruct each reviewer to lead with this block; if the CLI strips it, prepend after the call returns.

Per-reviewer (`code-reviews/code-<reviewer>.md`):

```yaml
---
title: "Code review — PR #<N> — <reviewer>"
type: code-review
task: <kebab task name OR pr<N>-review>
task_date: <YYYY-MM-DD>           # task date if flow task; today otherwise
created: <today>
last_updated: <today>
status: active
size: <S|M|L>                     # from meta.md if available; M otherwise
parent: ../plan.md                # omit if no plan context
related:
  - ./code-summary.md
reviewer: gemini-3.1-pro-preview
cli: gemini
verdict: merge-as-is              # filled by Claude after reading reviewer output
pr: <N>
prompted_against:
  - ./_pr-diff.patch
  - <abs plan path or "(none)">
---
```

Synthesized summary (`code-reviews/code-summary.md`):

```yaml
---
title: "Code review summary — PR #<N>"
type: code-summary
task: <kebab task name OR pr<N>-review>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
size: <S|M|L>
parent: ../plan.md                # omit if no plan context
related:
  - ./code-gemini.md
  - ./code-kimi.md
  - ./code-deepseek.md
reviewers:
  - gpt-5.5
  - gemini-3.1-pro-preview
  - opencode-go/kimi-k2.6
  # append optional reviewers if user opted in:
  # - opencode-go/deepseek-v4-pro
  # - opencode-go/glm-5.1
missing_reviewers: []
pr: <N>
---
```

### Reviewer prompt (shared shape)

Reuse this skeleton; each call differs only in model + output path. Substitute absolute paths.

```
You are a non-interactive PR reviewer. Use Read and Write tools. Do not ask questions.

TASK:
1. Read the diff at <abs>/_pr-diff.patch and the file list at <abs>/_pr-files.txt.
   [If plan context exists] Also read the plan at <abs plan path>.
2. Write your review using the Write tool to: <abs>/code-<reviewer>.md
3. The LAST LINE of the file MUST be exactly:
     <!-- council-flow:review-complete -->
4. Print only: "wrote code-<reviewer>.md"

Focus on: correctness, security, missed edge cases, test coverage, maintainability.

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

Issue all reviewer Bash calls (default trio + any opted-in) in the **same message** so they run in parallel; run the heartbeat watcher (`watch_review` from `../../references/multi-llm.md`) alongside.

### Quick recap of failure handling

Full policy in `../../references/multi-llm.md`. Apply it verbatim. The short version:

- Pre-flight (`command -v gemini` / `command -v opencode`); skip a missing CLI without aborting.
- Wrap each call with `timeout 600`; capture exit code to `_runlog-<reviewer>.exit`; never let one failure kill the parallel batch.
- Verify each output: exit code 0, file non-empty, sentinel present as last line, structural content (≥1 `## ` heading + ≥1 `- ` bullet in first 50 lines), no failure signature in first 40 lines. Failures get `code-<reviewer>.FAILED.md`.
- **≥ 2 valid reviews** → synthesize as normal; list missing reviewer under `## 결손 리뷰어` in `code-summary.md`; inline comments only attribute models that produced output.
- **1 valid review** → stop and ask the user (retry / swap reviewer / proceed as single-reviewer with explicit labelling). Do **not** post a single-reviewer review pretending it was multi-LLM.
- **0 valid reviews** → stop. Surface failure records.

Posting a review with fewer than the original reviewer count is allowed; pretending the missing reviewer agreed is not.

## Step 3 — Synthesize code-summary.md (Korean)

Read each reviewer file once, extract findings, and write `code-reviews/code-summary.md` in Korean:

```markdown
# 코드 리뷰 요약 — PR #<N>

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
- gemini-3.1-pro-preview: rate limit (자세한 내용은 `code-gemini.FAILED.md`)

## 모델별 리뷰 원본
- [Codex gpt-5.5](./code-codex.md)
- [Gemini 3.1 Pro](./code-gemini.md)
- [Kimi K2.6](./code-kimi.md)
<!-- 아래는 사용자가 optional 리뷰어를 선택한 경우에만 포함 -->
- [DeepSeek v4 Pro](./code-deepseek.md)
- [GLM 5.1](./code-glm.md)
```

Verify file:line references reviewers cite — grep their outputs for path-shaped strings, check against `git ls-files`, and surface unverifiable paths in a "Paths to verify" section. Contributors hallucinate paths regularly; do not promote them silently.

## Step 4 — Build the GitHub review payload

Aggregate inline findings across all reviewers:

- **Dedupe** when multiple reviewers flagged the same `file:line` with the same concern. Sign the merged comment with all contributing models (`— signed: gemini-3.1-pro-preview, kimi-k2.6`).
- **Keep separate** when reviewers flagged the same line with different concerns. Two distinct comments are fine.
- **Filter** NIT comments if the count is overwhelming (>10). Keep them in the per-model files; only post the most important ones inline.

Each inline comment body **must** follow the format from `../../references/inline-review-posting.md`:

```
**[<SEVERITY>]** <headline>

<body in Korean>

— signed: <model-id>[, <model-id>]
```

Top-level review body is the contents of `code-summary.md`.

## Step 5 — Post the review

POST to `/repos/<owner>/<repo>/pulls/<PR>/reviews` with `event: "COMMENT"` and the inline comments array. Full payload shape and line-number gotchas in `../../references/inline-review-posting.md`.

After posting, verify:

```bash
gh pr view "$PR" --json reviews --jq '.reviews[-1] | {state, comments: .comments | length}'
```

If the comment count is off (GitHub silently drops comments whose line numbers fall outside the diff), reconcile by re-running the dropped lines or posting them as a follow-up review.

## Step 6 — Commit the review artifacts

The `code-reviews/` files are part of the audit trail. Commit policy depends on where the artifacts landed and which branch is currently checked out:

- **Same branch as the PR head** (deploy auto-invoke, or user reviewing their own branch's PR):
  ```bash
  git add .planning/<date>-<task-or-pr>-review/code-reviews/
  git commit -m "docs(review): add multi-LLM PR review artifacts for PR #<N>"
  git push
  ```
- **Different branch** (user is on `main` reviewing someone else's PR):
  Do **not** auto-checkout. Tell the user where the artifacts live and let them decide whether to commit them anywhere. The review is already posted to GitHub — the local files are for the audit trail.

## What NOT to do

- **Don't auto-merge.** Code-review stops at "review posted". The user merges.
- **Don't post raw model output as the PR review.** Always go through `code-summary.md` synthesis.
- **Don't skip the Korean summary.** Even if all reviewers said "merge as-is", write a one-line summary in Korean. Audit trail.
- **Don't post inline comments without the severity tag and model signature.** Downstream filtering depends on the fixed format.
- **Don't pipe reviewer stdout into the orchestrator's context.** Read the file once during synthesis. Stdout is a runlog; the file at the agreed path is the review.
- **Don't checkout a different branch silently** to commit review artifacts. Surface the choice to the user.

## Reference

- Multi-LLM invocation, sentinel, heartbeat, failure handling, quorum policy: `../../references/multi-llm.md`
- Inline review posting mechanics: `../../references/inline-review-posting.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Model registry: `../../references/models.md`
- Directory layout: `../../references/directory-structure.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
