# council-flow

An opinionated multi-step development workflow for Claude Code. Claude is the **orchestrator** (team lead): it frames the task, delegates each phase to a cost-appropriate bundled subagent tier, runs non-overlapping work in parallel, reviews what comes back, and prepares a **review brief** the user runs their own external agent(s) against. Lightweight, visual, fast iteration over heavy up-front planning.

```
kickoff → (research) → plan → develop → deploy → (code-review-brief) → (review-triage) → (cleanup)
```

`flow:quick` is the fast lane for a trivial task (jumps toward develop after a green/yellow/red safety check). Atomic commits. TDD-first. `.flow/tasks/<date>-<task>/` as local working memory (gitignored — the durable copy of non-code docs lives in GitHub Issues / PR bodies).

## Skills

- **`flow:kickoff`** — the single front door: frame the task (goal + acceptance + scope + Mermaid direction) **and** set up the worktree, branch, and `.flow/tasks/<date>-<task>/`.
- **`flow:quick`** — fast lane for a user-asserted trivial task; classifies green/yellow/red and routes to develop / ask / escalate.
- **`flow:research`** — optional pre-plan investigation, fanned out to parallel subagents, writes `research.md`.
- **`flow:plan`** — a short visual `plan.md` (goal + spec + user flow + Mermaid) and a checklist `tasks.md`.
- **`flow:develop`** — TDD cycle per `tasks.md` checkbox, atomic Conventional Commits.
- **`flow:deploy`** — push, open a Korean PR, then offer the code-review brief.
- **`flow:code-review-brief`** — prepare the base material for a review (the user runs their own agents against it); does not post comments.
- **`flow:review-triage`** — pull all PR feedback, triage validity + priority, plan and apply fixes. Recommend-only.
- **`flow:cleanup`** — post-merge teardown: kill dev-server / e2e processes, remove the worktree, prune stale previews. Recommend-only.
- **`flow:commit-pr`** — the everyday commit → push → open/update-PR loop.
- **`flow:orchestrate`** — run the whole sequence end-to-end with size-based skip logic.

## Agents

Bundled subagents (Claude Code) the orchestrator delegates phases to, each pinned to a cost-appropriate model tier. Invoke scoped, e.g. `flow:researcher`. Model IDs live in `references/models.md`.

- **`flow:planner`** (Opus) — turn a framed task into a visual `plan.md` + `tasks.md`; plans, does not implement.
- **`flow:developer`** (Sonnet) — execute `tasks.md` via TDD + atomic Conventional Commits.
- **`flow:researcher`** (Sonnet) — cost-efficient pre-plan investigation; fan out in parallel, returns a tight digest.
- **`flow:reviewer`** (Fable) — fast in-harness fresh-eyes review; complements the external-agent code-review path.
- **`flow:browser-tester`** (Sonnet, frontend only) — real-browser QA: rendering, event handling, CDP-observed API calls; runs in parallel with review.
- **`flow:react-reviewer`** (Fable / Opus, frontend only) — React composition & reuse audit; runs in parallel with review.

## Conventions

- LLM-facing docs (brief.md, plan.md, tasks.md, research.md, prepare.md): **English**
- User-facing docs (kickoff/review briefs as GitHub Issues, `artifacts/code-review-summary.md`, PR body, `artifacts/*.ko.md`): **Korean**
- Working dir: `.flow/tasks/<yyyy-mm-dd>-<kebab-task>/` (**gitignored** — never committed; durable copy lives in GitHub Issues / PR bodies)
- Branches: `<type>/<task-name>` where type ∈ `feature|fix|chore|refactor|docs`
- Commits: Conventional Commits, atomic (one behavior per commit)
- Writing style: **Simplified Technical English (ASD-STE100)** — one idea per sentence, active voice, one term per concept; Korean docs follow the same discipline

## Install

### From GitHub (recommended)

Claude Code:

```bash
/plugin marketplace add gitgitWi/council-flow
/plugin install flow@council-flow
```

Codex CLI:

```bash
codex plugin marketplace add gitgitWi/council-flow
```

GitHub shorthand resolves to this repo. Equivalent full forms also work:

```bash
# Claude Code
/plugin marketplace add https://github.com/gitgitWi/council-flow.git    # HTTPS
/plugin marketplace add git@github.com:gitgitWi/council-flow.git        # SSH (private/auth)

# Codex CLI
codex plugin marketplace add https://github.com/gitgitWi/council-flow.git    # HTTPS
codex plugin marketplace add git@github.com:gitgitWi/council-flow.git        # SSH (private/auth)
```

### From a local clone

```bash
git clone https://github.com/gitgitWi/council-flow.git ~/Codes/council-flow

# Claude Code
/plugin marketplace add ~/Codes/council-flow
/plugin install flow@council-flow

# Codex CLI
codex plugin marketplace add ~/Codes/council-flow
```

The marketplace name `council-flow` comes from `.claude-plugin/marketplace.json` and is the same regardless of install source.

See the Claude Code docs for the full `/plugin marketplace add` reference: https://code.claude.com/docs/en/discover-plugins.md

See the Codex CLI help for plugin marketplace options:

```bash
codex plugin marketplace add --help
```

## References

Shared reference docs live at the plugin root and are linked from each SKILL.md:

- `references/models.md` — model registry & bundled agent tiers (swap IDs here, not in skills)
- `references/multi-llm.md` — the brief → user-run-agents model (why the flow doesn't dispatch reviewer CLIs)
- `references/config.md` — the consumer repo's `.flow/config.yaml` (assignee/labels/worktree root/review agents)
- `references/directory-structure.md` — `.flow/tasks/` layout & git policy
- `references/frontmatter.md` — YAML frontmatter schema for `.flow/tasks/` docs
- `references/mermaid.md` — diagram types GitHub renders + skeletons
- `references/doc-style.md` — Simplified Technical English (ASD-STE100); prefer lists over tables; GitHub-body gotchas
- `references/commit-conventions.md` — atomic + conventional commits, Issue/PR conventions
- `references/tdd-policy.md` — when TDD applies, when it doesn't
- `references/inline-review-posting.md` — gh API mechanics for inline PR comments

## Scripts

- `scripts/prep.sh` — worktree + branch + `.flow/tasks/` scaffolding (idempotent); invoked by `flow:kickoff`'s setup step

## Acknowledgements

Inspired by [claude-octopus](https://github.com/nyldn/claude-octopus) — many of the design decisions here (multi-agent orchestration, phase-based workflow, skill-per-step structure) draw directly from patterns nyldn established there. `council-flow` is a smaller, opinionated subset focused on a single bilingual TDD-first development loop, but the foundations are theirs.

The planning and research skills also borrow from [Superpowers](https://github.com/obra/superpowers) and [gstack](https://github.com/garrytan/gstack): Superpowers' emphasis on design-before-implementation, explicit alternatives, and self-review; and gstack's stronger problem framing, premise challenge, and existing-code leverage.

## License

MIT
