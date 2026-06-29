# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`council-flow` is a Claude Code **plugin marketplace** hosting a single plugin called `flow` — an opinionated multi-step development workflow (`kickoff → prep → research → plan → develop → deploy → code-review`). The plugin is consumed by other Claude Code installs via `/plugin marketplace add gitgitWi/council-flow`; this repo is the source.

`code-review` is also invocable standalone for any existing PR — `flow:deploy` auto-invokes it after opening a PR, but the user can also invoke it directly when they want a multi-LLM review on a PR they did not create through the flow workflow.

There is no application code, no build, no test runner, no linter. The shippable surface is:

- `.claude-plugin/marketplace.json` — marketplace manifest (one plugin entry: `flow`)
- `.claude-plugin/plugin.json` — plugin manifest; registers each `SKILL.md` path
- `skills/<name>/SKILL.md` — the skills themselves (frontmatter + Markdown body)
- `references/*.md` — shared docs linked from skills (model registry, dir layout, TDD policy, commit/PR conventions, inline-review API mechanics)
- `scripts/prep.sh` — the only executable; called by the `prep` skill

## Architecture: skills + references, not code

Skills are read by the orchestrating Claude session at runtime. They are prose with a YAML frontmatter `name` and `description`. The frontmatter `description` is load-bearing — Claude Code uses it for skill auto-invocation, so wording determines when a skill fires. Don't bury triggering keywords.

The flow is sequenced by `skills/orchestrate/SKILL.md`, which is a thin wrapper that invokes the step-skills in order with **size-based skip logic** (S/M/L from `prepare.md`). The mandatory pause is the user checkpoint between `plan` and `develop` — the user reads the lightweight plan and gives go/no-go. `deploy` is intentionally run in a fresh session so the PR and the code-review brief reflect a clean final diff. The design bias is **lightweight, visual, fast iteration** (plan→implement→review→fix, repeated) over heavy up-front planning — there is no separate plan-review step; review concentrates on the result.

Key cross-cutting conventions encoded in the references (treat as authoritative — don't reinvent):

- **`.planning/<yyyy-mm-dd>-<kebab-task>/`** is the per-task working memory. Canonical docs (`brief.md`, `prepare.md`, `plan.md`, `tasks.md`, `research.md`, `brainstorm.md`) sit at the root; supporting artifacts (briefs, returned reviews, summaries, translations, superseded versions) live in a single flat `artifacts/` folder. **Not committed** — it is gitignored local working memory; the durable copy of non-code docs lives in GitHub Issues / PR bodies. See `references/directory-structure.md`.
- **Language split**: LLM-facing docs (`brief.md`, `plan.md`, `tasks.md`, `research.md`, `prepare.md`, every `SKILL.md`, every `references/*.md`) MUST be English. User-facing docs — the kickoff/review **briefs** (Korean GitHub Issue / review briefs), `artifacts/code-review-summary.md`, PR body — and translations (`artifacts/plan.ko.md`, `artifacts/tasks.ko.md`) MUST be Korean. This split is structural, not stylistic.
- **Plan visualization**: lead `plan.md` with a Mermaid diagram (flowchart / sequence / erd / journey). `tasks.md` uses a one-line behavior + pseudo-code test or small Mermaid — **no Given-When-Then prose**. See `references/mermaid.md`.
- **Multi-LLM model**: the flow agent **does not run reviewer CLIs**. It writes a **brief** (for code-review or brainstorm) and the user runs their own external agent(s) against it. See `references/multi-llm.md`. Never pipe raw other-LLM output back into Claude's context — file it under `artifacts/`.
- **Research subagents**: pre-plan research (codebase / GitHub / history / web) is fanned out to cost-efficient subagents (Sonnet in Claude Code), not the frontier orchestrator. See `references/models.md`.
- **Project defaults** (assignee / milestone / labels / worktree root / review agents) live in the consumer repo's `.flow/config.yaml` — don't hardcode them in skills. See `references/config.md`.
- **Atomic + Conventional Commits** with TDD pairs (`test(...)` then `feat(...)`). See `references/commit-conventions.md` and `references/tdd-policy.md`.
- **Prefer lists over tables** in all authored docs. Tables render inconsistently across renderers and on mobile — reserve them for decision/comparison matrices. See `references/doc-style.md`.

## Working on the plugin itself

When the user asks you to modify *this* repo (as opposed to running the workflow on another project):

- **Adding a new skill** requires three coordinated edits: create `skills/<name>/SKILL.md` (with frontmatter), append its path to the `skills` array in `.claude-plugin/plugin.json`, and link it from any orchestrator/README references that should know about it.
- **Renaming a skill** must update the directory, the frontmatter `name`, the `plugin.json` array entry, every cross-link in other skills (skills reference each other as `flow:<name>`), and any reference docs that mention the old name.
- **Changing model IDs or CLIs** → edit only `references/models.md`. Skills consume the registry; do not hardcode model IDs in skill bodies.
- **Version bumps** are mirrored in two files: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (both currently `0.1.0`). Keep them in sync.
- **`scripts/prep.sh`** is invoked from `skills/prep/SKILL.md`. It's idempotent (re-running with the same `--task` prints the existing worktree path), creates worktrees at `<repo-parent>/<repo-name>.worktrees/<task>`, ensures `.planning/` is gitignored in the target repo, and seeds `prepare.md`. If you change its flag surface or output contract, update the prep skill too.
- **No build, lint, or test commands.** Validation is reading the files. If a skill references another file, click through and confirm the path resolves.

## What NOT to do

- Do not add a package manager, build pipeline, or test framework — the plugin is pure docs + one shell script and should stay that way.
- Do not add new top-level directories beyond `.claude-plugin/`, `skills/`, `references/`, `scripts/` without strong reason. Predictable layout is part of the product.
- Do not rewrite skills in Korean. The reverse-translation policy is explicit.
- Do not commit `.planning/` in this repo — it is gitignored so the workflow can be dogfooded here, but task-local working memory must not ship to plugin consumers via the marketplace.
