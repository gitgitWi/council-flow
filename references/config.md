# `.flow/config.yaml` — per-project defaults

A small optional config that lives in **the target project's root** (`<repo>/.flow/config.yaml`), so flow skills stop re-asking (or making the user re-type) the same values every session: assignee, milestone, labels, worktree root, base branch, issue-first toggle, and which external review agents to use — plus how each is launched.

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

cleanup:
  preview_retention: 10         # flow:cleanup keeps the last N preview deployments, prunes older

review:
  # External agents that judge a review/brainstorm brief.
  # `run: user`   — the flow agent writes the brief and stops; the user runs it (default).
  # `run: paseo`  — the flow agent dispatches via `paseo run` (opt-in, see multi-llm.md).
  # `run: agy`    — the flow agent dispatches via `agy -p` (Antigravity; not a Paseo provider).
  # Effort: pin each model's highest supported level.
  default_run: user
  agents:
    - name: claude-code
      run: paseo
      model: claude-fable-5             # --thinking max
    - name: codex
      run: paseo
      model: gpt-5.6-sol                # --thinking max
    - name: opencode
      run: paseo
      model: opencode-go/kimi-k3        # --thinking max
    - name: antigravity
      run: agy
      model: gemini-3.7-flash-high      # --effort high
```

The short form (`agents: [claude-code, codex]`) still works and means `run: default_run`.

All keys are optional. Omit a section to fall back to ask/infer.

## How skills use it

Read once at the start of a flow step; treat values as defaults that the user can override in-conversation.

- `flow:kickoff` — worktree root, base branch, issue-first toggle, assignee/milestone/labels for the brief's working rules.
- `flow:commit-pr` / `flow:deploy` — assignee, milestone, labels, PR language.
- `flow:code-review-brief` — `review.agents` drives the agent→lens split. Entries with `run: user` are listed for the user to run; `run: paseo` / `run: agy` entries the flow agent may dispatch itself once the user confirms.
- `flow:cleanup` — `worktree.root` to locate the worktree; `cleanup.preview_retention` for how many preview deployments to keep.

## Notes

- Skills must **not** hardcode `est-wiii` / `RN Migration` / worktree paths — those are project-specific and belong here.
- Keep it short. This file is defaults, not a plan. If a value is only ever used once, leave it out of the config and just say it in the prompt.
