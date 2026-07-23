# `.flow/config.yaml` — per-project defaults

A small optional config that lives in **the target project's root** (`<repo>/.flow/config.yaml`), so flow skills stop re-asking (or making the user re-type) the same values every session: assignee, milestone, labels, worktree root, base branch, issue-first toggle, and which external review agents the user runs.

It is **not** in this plugin repo — it belongs to each consumer project. Skills read it; if it is absent, they fall back to asking or inferring (the pre-config behavior).

## Schema

```yaml
# .flow/config.yaml
github:
  assignee: est-wiii            # default PR/Issue assignee
  milestone: RN Migration       # default milestone ("" or omit for none)
  labels: [RN Migration]        # seed labels always considered; skills still reuse
                                #   existing repo labels and create new ones as needed
  use_cli: true                 # use `gh` CLI directly (not MCP)

worktree:
  root: ~/Codes/alan-mobile.worktrees   # where flow:kickoff setup creates worktrees
  base: main                            # default base branch

flow:
  issue_first: true             # research/plan → GitHub Issue, user approves before code
  pr_language: ko               # language for PR/Issue bodies (user/team-facing)

review:
  # External agents the USER runs against a review/brainstorm brief.
  # The flow agent does NOT execute these — it writes the brief; the user runs them.
  agents:
    - claude-code   # Sonnet
    - antigravity   # Gemini 3.5 Flash
    - codex         # Codex 5.6 Sol
```

All keys are optional. Omit a section to fall back to ask/infer.

## How skills use it

Read once at the start of a flow step; treat values as defaults that the user can override in-conversation.

- `flow:kickoff` — worktree root, base branch, issue-first toggle, assignee/milestone/labels for the brief's working rules.
- `flow:commit-pr` / `flow:deploy` — assignee, milestone, labels, PR language.
- `flow:code-review-brief` — `review.agents` is listed in the brief so the user knows which agents to run; the flow agent never invokes them.

## Notes

- Skills must **not** hardcode `est-wiii` / `RN Migration` / worktree paths — those are project-specific and belong here.
- Keep it short. This file is defaults, not a plan. If a value is only ever used once, leave it out of the config and just say it in the prompt.
