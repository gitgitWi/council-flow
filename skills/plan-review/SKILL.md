---
name: plan-review
description: Run a multi-LLM review on `plan.md` and `tasks.md` before implementation starts, capturing each reviewer's output as a file and synthesizing a Korean summary the user reads. Use this whenever a plan is non-trivial (size M with external dependencies, or any size L). Different models catch different gaps; the cost of an extra reviewer pass is tiny compared to discovering a missing requirement halfway through develop. Also use whenever the user asks for a "second opinion" on a plan or wants to validate an approach before committing to it.
---

# flow:plan-review — Multi-LLM plan critique

Plan-review is cheap insurance. Each model reads the same plan and tasks list independently, raises issues in its own voice, and the orchestrator (Claude) reconciles them into a Korean summary the user reviews. If the review surfaces meaningful gaps, the plan gets versioned (`plan.v1.md`) and a new `plan.md` is written.

## Preconditions

- `<worktree>/.planning/<date>-<task>/plan.md` exists.
- `<worktree>/.planning/<date>-<task>/tasks.md` exists.
- Optionally `research.md`.

If any of these are missing, do not run plan-review — go back to `flow:plan` first.

## Reviewers

Use three reviewers by default; the diversity is the point. Model IDs come from `../../references/models.md` — do not hardcode here, and re-check that file when models move.

Default trio (diverse stack: codex + gemini + opencode):

- `review/plan-codex.md` — `gpt-5.5` via `codex`
- `review/plan-gemini.md` — `gemini-3.1-pro-preview` via `gemini`
- `review/plan-kimi.md` — `opencode-go/kimi-k2.6` via `opencode`

Optional reviewers (ask the user before dispatching — see "Pre-flight + reviewer selection" below):

- `review/plan-deepseek.md` — `opencode-go/deepseek-v4-pro` via `opencode` (deepest analysis, +10-15 min)
- `review/plan-glm.md` — `opencode-go/glm-5.1` via `opencode` (fast extra opinion, +5-7 min)

If the user wants only two reviewers (token / time budget), keep Gemini + one of the Codex/OpenCode options. Always keep at least two; one reviewer is not a "multi-LLM review."

CLI invocation flags are normative in `../../references/multi-llm.md` — in particular: `opencode run` must use `-m provider/model` (not `--format json`); `codex exec` (now a default reviewer) must pass `--skip-git-repo-check --sandbox workspace-write --cd <abs-path>`. Do not paraphrase these flags in this skill; they were the root cause of the prior session's opencode/codex timeouts.

## Frontmatter (every generated document)

The reviewer files, the synthesized summary, and any superseded plan version all carry frontmatter. Schema in `../../references/frontmatter.md`.

Per-reviewer (`review/plan-<reviewer>.md`) — instruct the reviewer to start its output with this block (some CLIs strip it; if so, prepend it after the call returns):

```yaml
---
title: "Plan review — <task> — <reviewer>"
type: plan-review
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
size: <S|M|L>
parent: ../plan.md
related:
  - ../tasks.md
  - ./plan-summary.md (synthesized summary)
reviewer: gemini-3.1-pro-preview
cli: gemini
verdict: ship-as-is        # filled by Claude after reading reviewer output
prompted_against:
  - /abs/.../plan.md
  - /abs/.../tasks.md
---
```

Synthesized summary (`review/plan-summary.md`):

```yaml
---
title: "Plan review summary — <task>"
type: plan-summary
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active
size: <S|M|L>
parent: ../plan.md
related:
  - ./plan-gemini.md
  - ./plan-kimi.md
  - ./plan-deepseek.md
reviewers:
  - gpt-5.5
  - gemini-3.1-pro-preview
  - opencode-go/kimi-k2.6
  # append optional reviewers if user opted in:
  # - opencode-go/deepseek-v4-pro
  # - opencode-go/glm-5.1
missing_reviewers: []      # populate with the failed reviewers, if any
---
```

When versioning the plan (substantive changes apply), the moved `versions/plan.v<N>.md` gets:

```yaml
status: superseded
superseded_by: ./plan.md
```

…and the new `plan.md` gets `version: <N+1>` and `supersedes: ./versions/plan.v<N>.md`. Same rules for `tasks.md` ↔ `versions/tasks.v<N>.md` if tasks change.

## Prompt template

Same template across reviewers. Variables are filled in at call time.

```
You are reviewing a plan document for a software change before implementation begins.

Read the following files and review them critically:
- Plan: <abs-path>/.planning/<date>-<task>/plan.md
- Tasks: <abs-path>/.planning/<date>-<task>/tasks.md
- Research (if present): <abs-path>/.planning/<date>-<task>/research.md

Produce a Markdown review with these sections:

## Strengths
What is well-reasoned about this plan? Be specific — don't write filler.

## Gaps and risks
What did the planner miss or under-specify? Edge cases, error handling, rollout
concerns, missing tests, scope creep. Cite the plan section by heading when
applicable.

## Concrete suggestions
Actionable changes to the plan or tasks list. For each: what to change, why,
where in the plan/tasks file.

## Verdict
One line: "ship as-is" | "ship after minor edits" | "rework needed".
```

## Pre-flight + reviewer selection

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

Wait for the user's response before dispatching. If the user says skip (or no response), proceed with the default trio only. Opted-in reviewers join the same parallel batch; do not run a second wave.

## Running the reviewers in parallel

Issue all reviewer Bash calls (default trio + any opted-in) in the same message so they execute in parallel. See `../../references/multi-llm.md` for the exact invocation patterns, including the **mandatory pre-flight check, post-call verification, and quorum policy** when one or more reviewers fail (auth expiry, rate limit, network, etc.).

Quick recap of the failure handling, in this skill's terms:

- Run pre-flight (`command -v gemini` etc.) and skip any missing CLI up front.
- Wrap each call with `timeout` and capture the exit code; never let one CLI failure abort the parent shell.
- After the parallel batch returns, verify each reviewer file (exit code, non-empty, no failure signature) before reading it. If a check fails, write `review/plan-<reviewer>.FAILED.md` and continue.
- **≥ 2 valid reviews** → synthesize as normal, list missing reviewer(s) under `## 결손 리뷰어` in `plan-summary.md`.
- **1 valid review** → stop and ask the user (retry / swap reviewer / proceed as single-reviewer with explicit labelling).
- **0 valid reviews** → stop, do not synthesize, surface failure records.

## Synthesizing the summary

After all three review files exist:

1. **Read each file once.** Extract: each reviewer's top 3 risks, top 3 suggestions, and verdict.
2. **Look for agreement.** Items raised by 2+ reviewers are high signal. Items raised by only one but with strong reasoning still matter — don't filter by vote count alone.
3. **Look for disagreement.** When reviewers conflict (e.g., one says "use event sourcing", another says "stay relational"), this is the most valuable part of the review — surface the disagreement, don't paper over it.
4. **Write** `review/plan-summary.md` in **Korean** (this file is for the user, not for downstream agents):

```markdown
# 플랜 리뷰 요약 — <task>

## 한 줄 평가
<성공한 모델들의 verdict 종합>

## 합의된 강점
- ...

## 합의된 위험 / gap
- ...

## 모델 간 의견이 갈리는 지점
가장 중요한 섹션. 어느 모델이 어떤 주장을 했고, 왜 갈리는지, 사용자가 결정해야 할 것이 무엇인지.

## 권장 후속 조치
- [ ] plan.md에 반영할 것
- [ ] tasks.md에 추가할 것
- [ ] 사용자 확인 필요한 것

## 결손 리뷰어
(있을 때만 추가. 없으면 이 섹션 생략.)
- gemini-3.1-pro-preview: rate limit (자세한 내용은 `plan-gemini.FAILED.md`)

## 모델별 리뷰 원본
- [Codex gpt-5.5](./plan-codex.md)
- [Gemini 3.1 Pro Preview](./plan-gemini.md)
- [Kimi K2.6](./plan-kimi.md)
<!-- 아래는 사용자가 optional 리뷰어를 선택한 경우에만 포함 -->
- [DeepSeek v4 Pro](./plan-deepseek.md)
- [GLM 5.1](./plan-glm.md)
```

## Versioning the plan

The user reads `plan-summary.md` and decides what to apply.

- **No substantive change needed** — keep `plan.md` as-is. Don't bump.
- **Substantive changes** — move current `plan.md` to `versions/plan.v<N>.md` (next available `N` starting at 1). Also move `translates/plan.ko.md` to `versions/plan.ko.v<N>.md` if it exists. Write the new `plan.md` with edits applied. Note in the new plan's header which version it came from and what changed at a high level. Same versioning rule for `tasks.md` / `tasks.ko.md` if tasks change.
- **Re-dispatch Korean translation** — after writing the new `plan.md` (and `tasks.md` if changed), dispatch Korean translation using the same method as `flow:plan` (Sonnet subagent by default, GLM 5.1 on user request). The new translations land at `translates/plan.ko.md` and `translates/tasks.ko.md`.

Do **not** delete old plan versions. They are part of the audit trail — `versions/` preserves them.

## Reference

- Multi-LLM invocation: `../../references/multi-llm.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Model registry: `../../references/models.md`
- Directory layout: `../../references/directory-structure.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
