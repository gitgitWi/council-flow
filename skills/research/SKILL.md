---
name: research
description: Investigate codebase context, related projects, and external sources for a task that is large or unfamiliar enough that planning blind would waste effort. Use this when the task crosses modules, touches a subsystem the user has not worked on recently, or depends on external APIs / libraries whose current shape matters. Also use whenever the user explicitly asks for research, exploration, or a "deep dive" before planning. Output goes to `.planning/<date>-<task>/research.md` so the planner and reviewer can build on it.
---

# flow:research — Pre-plan investigation

Research exists to make the plan better. The output is not for shipping; it is a working document that the plan skill consumes. Optimize for *useful pointers, decision-relevant facts, and explicit options*, not for thoroughness.

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
used_external_llm: false # set true if Gemini/OpenCode produced raw output under review/
---

# Research — <task>

## Problem framing
- User goal in one sentence, in the user's words when possible.
- Who is affected by this change (end user, operator, maintainer, downstream agent).
- Success criteria: what must be true for the task to be done.
- Constraints and non-goals already known.

## Premises to validate
- List the assumptions the plan would rely on. Each line should say whether it is
  verified, likely, or still unknown.
- Challenge vague framing: if the task says "make it better", "simplify",
  "support X", or "improve UX", define the measurable version.

## Decision-relevant findings
- Crisp bullets. Each line should change at least one decision the planner will make.

## Existing code
- file:line references to where related logic lives
- Existing code, flows, docs, or past PRs that partially solve the problem
- Patterns to follow / patterns to avoid (call out anti-patterns explicitly)
- Anything the plan must reuse rather than rebuild, or a concrete reason not to
- Test coverage gaps in the area being touched

## External references
- Library API documentation (link + relevant version)
- Internal docs / past PRs / past issues
- Output from other-LLM research if used (saved separately, summarized here)

## Candidate approaches
- 2-3 viable shapes when the task is non-trivial. For each: summary, effort,
  risk, reversibility, blast radius, and existing code reused.
- Include a minimal viable approach and an ideal/local-architecture approach when
  they differ. Add a creative/lateral approach only when it is meaningfully
  different, not just bigger.
- Do not pick the final answer here unless the evidence clearly eliminates every
  alternative. The plan makes the decision.

## Open questions
- Things that need user input before planning can proceed.
```

Keep this document under ~300 lines. If you find yourself writing more, you are probably over-researching — surface the key facts and let the plan or actual implementation pull in the rest.

## How to research

### Codebase exploration

Use grep / find / Glob to locate related code. For broader exploration where you do not know the right keyword, spawn an `Explore` subagent — it scans without filling the orchestrator's context with raw file contents.

When exploring, explicitly look for leverage before inventing structure:

- Existing flows that already produce the desired data or behavior.
- Shared helpers, adapters, tests, or docs that should be extended.
- Nearby anti-patterns the plan should avoid copying.
- Deferred TODOs or prior plans that overlap with the task.

### Web research (optional, fast path)

When the user OK's it and the task involves a less-familiar library or API, delegate web research to Gemini's fast model. The Gemini output is verbose; save it to a file and summarize.

If the task is about a library, framework, SDK, API, CLI tool, or cloud service,
follow the current project's documented source-of-truth lookup first (for example,
`ctx7` where configured) before relying on general web search or model memory.

```bash
gemini --model gemini-3-flash-preview --yolo --skip-trust --prompt "$(cat <<'PROMPT'
Research the current shape of the <topic> API in <library@version>.
Cover: authentication flow, required scopes, callback behavior, error responses,
and any breaking changes in the last 12 months.
Cite source URLs.
PROMPT
)" > .planning/<date>-<task>/review/research-gemini.md
```

Then read that file once, distill the load-bearing facts into `research.md` under **External references**, and discard the rest from your active context.

### Past project memory

If the user mentions "we did this before" or similar, check claude-mem search for prior sessions before retracing the same path.

### Approach framing

Before finishing `research.md`, write candidate approaches when the choice is not
obvious. Use this shape:

```markdown
## Candidate approaches
- **Minimal viable** — smallest change that satisfies the success criteria.
  Effort: S/M/L. Risk: low/medium/high. Reuses: <existing code/docs>.
- **Local architecture fit** — approach that best matches current project
  structure, even if it touches a little more code.
  Effort: S/M/L. Risk: low/medium/high. Reuses: <existing code/docs>.
- **Ideal / lateral** — include only when it changes the framing or long-term
  trajectory in a meaningful way.
  Effort: S/M/L. Risk: low/medium/high. Reuses: <existing code/docs>.
```

## What NOT to do

- **Don't research the obvious.** Linking to the React docs for `useState` is noise.
- **Don't paste long code blocks.** Use file:line references instead — they stay current as the code evolves.
- **Don't decide the implementation here.** Research surfaces options and constraints. The plan picks among them. Mixing the two means the plan has nowhere to add value.
- **Don't research what the user has already told you.** If they said "we use Firebase Auth", don't go verify that.
- **Don't skip problem framing.** If the problem statement is fuzzy, the plan will
  encode fuzzy assumptions. Tighten the framing before drafting options.

## Reference

- Directory layout: `../../references/directory-structure.md`
- Frontmatter schema: `../../references/frontmatter.md`
- Calling other LLMs: `../../references/multi-llm.md`
- Doc style (prefer lists over tables): `../../references/doc-style.md`
