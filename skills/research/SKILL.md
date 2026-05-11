---
name: research
description: Investigate codebase context, related projects, and external sources for a task that is large or unfamiliar enough that planning blind would waste effort. Use this when the task crosses modules, touches a subsystem the user has not worked on recently, or depends on external APIs / libraries whose current shape matters. Also use whenever the user explicitly asks for research, exploration, or a "deep dive" before planning. Output goes to `.planning/<date>-<task>/research.md` so the planner and reviewer can build on it.
---

# flow:research — Pre-plan investigation

Research exists to make the plan better. The output is not for shipping; it is a working document that the plan skill consumes. Optimize for *useful pointers and decision-relevant facts*, not for thoroughness.

## When to run

- Task size is **L** (always)
- Task size is **M** and any of:
  - The user is unsure how the existing code is structured
  - The change depends on a library/API behavior the user has not verified
  - There is an existing similar pattern elsewhere in the repo or org that should be matched
- Task size is **S** — usually skip. The plan can be drafted directly from the file under change.

If you are not sure whether to research: **time-box it.** Spend 5–10 minutes scanning the most-likely-relevant files, then write a short `research.md` and move on. The plan-review step can flag if more research is needed.

## What to produce

`<worktree>/.planning/<date>-<task>/research.md`, with the standard frontmatter (full schema in `../../references/frontmatter.md`):

```markdown
---
title: "Research — <task>"
type: research
task: <kebab task name>
task_date: <YYYY-MM-DD>
created: <today>
last_updated: <today>
status: active           # this doc rarely changes status
size: <S|M|L>
parent: ./meta.md
related:
  - ./plan.md (will consume these findings)
time_box: 10m            # 5m | 10m | 20m | 60m
used_external_llm: false # set true if Gemini/OpenCode produced raw output under code-reviews/
---

# Research — <task>

## Decision-relevant findings
- Crisp bullets. Each line should change at least one decision the planner will make.

## Existing code
- file:line references to where related logic lives
- Patterns to follow / patterns to avoid (call out anti-patterns explicitly)
- Test coverage gaps in the area being touched

## External references
- Library API documentation (link + relevant version)
- Internal docs / past PRs / past issues
- Output from other-LLM research if used (saved separately, summarized here)

## Open questions
- Things that need user input before planning can proceed.
```

Keep this document under ~300 lines. If you find yourself writing more, you are probably over-researching — surface the key facts and let the plan or actual implementation pull in the rest.

## How to research

### Codebase exploration

Use grep / find / Glob to locate related code. For broader exploration where you do not know the right keyword, spawn an `Explore` subagent — it scans without filling the orchestrator's context with raw file contents.

### Web research (optional, fast path)

When the user OK's it and the task involves a less-familiar library or API, delegate web research to Gemini's fast model. The Gemini output is verbose; save it to a file and summarize.

```bash
gemini --model gemini-3-flash-preview --yolo --skip-trust --prompt "$(cat <<'PROMPT'
Research the current shape of the <topic> API in <library@version>.
Cover: authentication flow, required scopes, callback behavior, error responses,
and any breaking changes in the last 12 months.
Cite source URLs.
PROMPT
)" > .planning/<date>-<task>/code-reviews/research-gemini.md
```

Then read that file once, distill the load-bearing facts into `research.md` under **External references**, and discard the rest from your active context.

### Past project memory

If the user mentions "we did this before" or similar, check claude-mem search for prior sessions before retracing the same path.

## What NOT to do

- **Don't research the obvious.** Linking to the React docs for `useState` is noise.
- **Don't paste long code blocks.** Use file:line references instead — they stay current as the code evolves.
- **Don't decide the implementation here.** Research surfaces options and constraints. The plan picks among them. Mixing the two means the plan has nowhere to add value.
- **Don't research what the user has already told you.** If they said "we use Firebase Auth", don't go verify that.

## Reference

- Directory layout: `../../references/directory-structure.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Calling other LLMs: `../../references/multi-llm.md`
