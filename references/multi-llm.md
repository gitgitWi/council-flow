# Multi-LLM Invocation Patterns

For model IDs and CLI flags, see `models.md`. This file is about *how* to drive other coding agents from inside a flow skill.

## Core principle

**Never paste raw output from another LLM into your conversation.** Always pipe to a file, then read only the parts you need. Other LLMs emit verbose preambles, restatements, and reasoning that bloat the orchestrator's context.

## Calling pattern (Gemini)

```bash
gemini --model gemini-3.1-pro --yolo --skip-trust --prompt "$(cat <<'PROMPT'
You are reviewing a plan document for a software change.

Read the plan at <abs-path>/plan.md and the task list at <abs-path>/tasks.md.
Produce a review with the following sections in Markdown:
- Strengths
- Risks / gaps
- Concrete suggestions (file:line where applicable)
- Verdict: ship / revise

Focus on correctness and missed edge cases. Be specific.
PROMPT
)" > .planning/<task>/code-reviews/plan-gemini.md
```

## Calling pattern (OpenCode)

```bash
opencode --model opencode-go/kimi-k2.6 --prompt "$(cat <<'PROMPT'
... same kind of prompt ...
PROMPT
)" > .planning/<task>/code-reviews/plan-kimi.md
```

## Parallel execution

For Plan Review and Code Review, run all reviewer CLIs in parallel — they are independent.

```bash
# In your skill, kick all three off in the same step
gemini --model gemini-3.1-pro ... > .../plan-gemini.md &
opencode --model opencode-go/kimi-k2.6 ... > .../plan-kimi.md &
opencode --model opencode-go/deepseek-v4-pro ... > .../plan-deepseek.md &
wait
```

If invoking from Claude tool calls instead of a single shell pipeline, issue the Bash calls in the same message so Claude executes them in parallel.

## After invocation

1. Verify each output file exists and is non-empty.
2. **Read each file once** to extract structured findings — strengths, risks, suggestions, verdict. Do not dump all three into context simultaneously.
3. Synthesize a Korean summary (`plan-summary.md` / `code-summary.md`):
   - 합의된 강점
   - 합의된 위험 요소
   - 모델 간 의견이 갈리는 지점 (이 부분이 가장 중요)
   - 권장 후속 조치

## Prompt construction tips

- Always give the reviewer an absolute file path, not a relative path. Different CLIs have different working-directory assumptions.
- Tell the reviewer the **format** of output you want (sections, headings). Otherwise output varies wildly between models.
- Tell the reviewer **what role** to take — "you are reviewing a plan" vs "you are reviewing code" leads to different attention.
- For code review, include `git diff` output or the changed file paths so the model has something concrete to react to.

## When to skip multi-LLM

- Task size `S` (single-file edits)
- User said "just plan it" / "just ship it"
- The reviewers would all read the same small change and produce the same review

When skipping, write a `plan-summary.md` (or `code-summary.md`) explaining that multi-LLM was skipped and why, so the audit trail is complete.
