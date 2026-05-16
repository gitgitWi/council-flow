# council-flow

An opinionated multi-step development workflow for Claude Code — a small "council" of LLMs (Claude as orchestrator + Gemini + OpenCode/Kimi + OpenCode/DeepSeek) plans, reviews, and ships your changes together.

```
prep → (research) → (brainstorm) → plan → (plan-review) → develop → deploy
```

Atomic commits. TDD-first. `.planning/<date>-<task>/` as the working memory. Multi-LLM review (Gemini, OpenCode/Kimi, OpenCode/DeepSeek) at plan time and review time.

## Skills

| Skill | What it does |
|---|---|
| `flow:prep` | Create worktree, branch, `.planning/<date>-<task>/` folder, size estimate |
| `flow:research` | Optional pre-plan investigation, writes `research.md` |
| `flow:brainstorm` | Optional multi-LLM option-generation, writes `brainstorm.md`; standalone or sub-phase of `flow:research`/`flow:plan` |
| `flow:plan` | One-pager `plan.md` + GWT `tasks.md` |
| `flow:plan-review` | Multi-LLM critique of the plan, Korean summary, version bump on changes |
| `flow:develop` | TDD cycle per `tasks.md` checkbox, atomic conventional commits |
| `flow:deploy` | Push, Korean PR, multi-LLM code review, inline comments with model signatures |
| `flow:orchestrate` | Run the whole sequence end-to-end with size-based skip logic |

## Conventions

- LLM-facing docs (plan.md, tasks.md, research.md, meta.md): **English**
- User-facing summaries (plan-summary.md, code-summary.md, PR body): **Korean**
- Working dir: `.planning/<yyyy-mm-dd>-<kebab-task>/` (committed by default)
- Branches: `<type>/<task-name>` where type ∈ `feature|fix|chore|refactor|docs`
- Commits: Conventional Commits, atomic (one behavior per commit)

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

- `references/models.md` — model registry (swap IDs here, not in skills)
- `references/multi-llm.md` — how to call other coding agents
- `references/directory-structure.md` — `.planning/` layout
- `references/commit-conventions.md` — atomic + conventional commits
- `references/tdd-policy.md` — when TDD applies, when it doesn't
- `references/inline-review-posting.md` — gh API mechanics for inline PR comments

## Scripts

- `scripts/prep.sh` — worktree + branch + `.planning/` scaffolding (idempotent)

## Acknowledgements

Inspired by [claude-octopus](https://github.com/nyldn/claude-octopus) — many of the design decisions here (multi-LLM orchestration, phase-based workflow, skill-per-step structure, plan/review separation) draw directly from patterns nyldn established there. `council-flow` is a smaller, opinionated subset focused on a single bilingual TDD-first development loop, but the foundations are theirs.

The planning and research skills also borrow from [Superpowers](https://github.com/obra/superpowers) and [gstack](https://github.com/garrytan/gstack): Superpowers' emphasis on design-before-implementation, explicit alternatives, and self-review; and gstack's stronger problem framing, premise challenge, existing-code leverage, and plan-review rigor.

## License

MIT
