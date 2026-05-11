# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`council-flow` is a Claude Code **plugin marketplace** hosting a single plugin called `flow` — an opinionated multi-step development workflow (`prep → research → plan → plan-review → develop → deploy`). The plugin is consumed by other Claude Code installs via `/plugin marketplace add gitgitWi/council-flow`; this repo is the source.

There is no application code, no build, no test runner, no linter. The shippable surface is:

- `.claude-plugin/marketplace.json` — marketplace manifest (one plugin entry: `flow`)
- `.claude-plugin/plugin.json` — plugin manifest; registers each `SKILL.md` path
- `skills/<name>/SKILL.md` — the skills themselves (frontmatter + Markdown body)
- `references/*.md` — shared docs linked from skills (model registry, dir layout, TDD policy, commit/PR conventions, inline-review API mechanics)
- `scripts/prep.sh` — the only executable; called by the `prep` skill

## Architecture: skills + references, not code

Skills are read by the orchestrating Claude session at runtime. They are prose with a YAML frontmatter `name` and `description`. The frontmatter `description` is load-bearing — Claude Code uses it for skill auto-invocation, so wording determines when a skill fires. Don't bury triggering keywords.

The flow is sequenced by `skills/orchestrate/SKILL.md`, which is a thin wrapper that invokes the six step-skills in order with **size-based skip logic** (S/M/L from `meta.md`). The mandatory pause is the user checkpoint between `plan-review` and `develop`. `deploy` is intentionally run in a fresh session so reviewer LLMs see a clean diff.

Key cross-cutting conventions encoded in the references (treat as authoritative — don't reinvent):

- **`.planning/<yyyy-mm-dd>-<kebab-task>/`** is the per-task working memory. All artifacts (`meta.md`, `plan.md`, `tasks.md`, `research.md`, `code-reviews/`) live here. Committed by default. See `references/directory-structure.md`.
- **Language split**: LLM-facing docs (`plan.md`, `tasks.md`, `research.md`, `meta.md`, every `SKILL.md`, every `references/*.md`) MUST be English. User-facing summaries (`plan-summary.md`, `code-summary.md`, PR body) MUST be Korean. This split is structural, not stylistic — don't translate either direction without reason.
- **Plan versioning**: `plan-review` renames the old `plan.md` to `plan.v<N>.md` *only* when substantive changes apply. Never delete prior versions.
- **Multi-LLM output handling**: Other-LLM output (Gemini, OpenCode/Kimi, OpenCode/DeepSeek) is *always* written to a file under `code-reviews/`, never piped back into Claude's context as raw text. See `references/multi-llm.md`.
- **Model IDs live in `references/models.md`** — when models change, update there, not in individual skills.
- **Atomic + Conventional Commits** with TDD pairs (`test(...)` then `feat(...)`). See `references/commit-conventions.md` and `references/tdd-policy.md`.

## Working on the plugin itself

When the user asks you to modify *this* repo (as opposed to running the workflow on another project):

- **Adding a new skill** requires three coordinated edits: create `skills/<name>/SKILL.md` (with frontmatter), append its path to the `skills` array in `.claude-plugin/plugin.json`, and link it from any orchestrator/README references that should know about it.
- **Renaming a skill** must update the directory, the frontmatter `name`, the `plugin.json` array entry, every cross-link in other skills (skills reference each other as `flow:<name>`), and any reference docs that mention the old name.
- **Changing model IDs or CLIs** → edit only `references/models.md`. Skills consume the registry; do not hardcode model IDs in skill bodies.
- **Version bumps** are mirrored in two files: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (both currently `0.1.0`). Keep them in sync.
- **`scripts/prep.sh`** is invoked from `skills/prep/SKILL.md`. It's idempotent (re-running with the same `--task` prints the existing worktree path), creates worktrees at `<repo-parent>/<repo-name>.worktrees/<task>`, and seeds `meta.md`. If you change its flag surface or output contract, update the prep skill too.
- **No build, lint, or test commands.** Validation is reading the files. If a skill references another file, click through and confirm the path resolves.

## What NOT to do

- Do not add a package manager, build pipeline, or test framework — the plugin is pure docs + one shell script and should stay that way.
- Do not add new top-level directories beyond `.claude-plugin/`, `skills/`, `references/`, `scripts/` without strong reason. Predictable layout is part of the product.
- Do not rewrite skills in Korean. The reverse-translation policy is explicit.
- Do not edit `.planning/` in this repo — the plugin is self-hosted and doesn't dogfood its own workflow inside its own source tree.
