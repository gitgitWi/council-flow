#!/usr/bin/env bash
#
# flow:prep — create worktree + branch + .planning folder for a new task.
#
# Usage:
#   prep.sh --task <kebab-name> --type <feature|fix|chore|refactor|docs> [--base <branch>] [--size S|M|L] [--goal "<goal>"] [--force]
#
# Defaults:
#   --base    main
#   --size    M
#
# Worktree path:
#   <repo-parent>/<repo-name>.worktrees/<task>
#
# Idempotency:
#   If the worktree already exists and --force is NOT set, the script exits 0 with the
#   existing path printed — safe to re-run. With --force, the existing worktree and
#   branch are removed first.

set -euo pipefail

die() { echo "prep: $*" >&2; exit 1; }

# --- parse args ---
TASK=""
TYPE=""
BASE="main"
SIZE="M"
GOAL=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)  TASK="$2"; shift 2;;
    --type)  TYPE="$2"; shift 2;;
    --base)  BASE="$2"; shift 2;;
    --size)  SIZE="$2"; shift 2;;
    --goal)  GOAL="$2"; shift 2;;
    --force) FORCE=1; shift;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

[[ -n "$TASK" ]] || die "--task required (kebab-case)"
[[ -n "$TYPE" ]] || die "--type required (feature|fix|chore|refactor|docs)"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "--task must be kebab-case (lowercase, hyphens)"
[[ "$TYPE" =~ ^(feature|fix|chore|refactor|docs)$ ]] || die "--type must be one of: feature, fix, chore, refactor, docs"
[[ "$SIZE" =~ ^[SML]$ ]] || die "--size must be S, M, or L"

# --- locate repo ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
REPO_NAME="$(basename "$REPO_ROOT")"
REPO_PARENT="$(dirname "$REPO_ROOT")"
WORKTREES_DIR="${REPO_PARENT}/${REPO_NAME}.worktrees"
WORKTREE_PATH="${WORKTREES_DIR}/${TASK}"
BRANCH="${TYPE}/${TASK}"
DATE="$(date +%Y-%m-%d)"
PLANNING_DIR=".planning/${DATE}-${TASK}"

# --- handle existing state ---
if git worktree list --porcelain | grep -q "^worktree ${WORKTREE_PATH}$"; then
  if [[ $FORCE -eq 1 ]]; then
    echo "prep: --force set, removing existing worktree ${WORKTREE_PATH}"
    git worktree remove --force "${WORKTREE_PATH}"
  else
    echo "${WORKTREE_PATH}"
    echo "prep: worktree exists, reusing (use --force to recreate)" >&2
    exit 0
  fi
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  if [[ $FORCE -eq 1 ]]; then
    echo "prep: --force set, deleting existing branch ${BRANCH}"
    git branch -D "${BRANCH}"
  else
    die "branch ${BRANCH} already exists (use --force to recreate, or pick a different --task)"
  fi
fi

# --- ensure base is up to date locally (fetch, don't merge) ---
git fetch origin "${BASE}" --quiet 2>/dev/null || true

# --- create worktree + branch ---
mkdir -p "${WORKTREES_DIR}"
git worktree add -b "${BRANCH}" "${WORKTREE_PATH}" "${BASE}"

# --- detect package manager and install dependencies ---
if [[ -f "${WORKTREE_PATH}/pnpm-lock.yaml" ]]; then
  echo "prep: detected pnpm, running pnpm install..." >&2
  ( cd "${WORKTREE_PATH}" && pnpm install ) >&2 || echo "prep: WARNING — pnpm install failed (non-fatal)" >&2
elif [[ -f "${WORKTREE_PATH}/bun.lockb" ]] || [[ -f "${WORKTREE_PATH}/bun.lock" ]]; then
  echo "prep: detected bun, running bun install..." >&2
  ( cd "${WORKTREE_PATH}" && bun install ) >&2 || echo "prep: WARNING — bun install failed (non-fatal)" >&2
elif [[ -f "${WORKTREE_PATH}/package-lock.json" ]]; then
  echo "prep: detected npm, running npm install..." >&2
  ( cd "${WORKTREE_PATH}" && npm install ) >&2 || echo "prep: WARNING — npm install failed (non-fatal)" >&2
elif [[ -f "${WORKTREE_PATH}/yarn.lock" ]]; then
  echo "prep: detected yarn, running yarn install..." >&2
  ( cd "${WORKTREE_PATH}" && yarn install ) >&2 || echo "prep: WARNING — yarn install failed (non-fatal)" >&2
elif [[ -f "${WORKTREE_PATH}/uv.lock" ]]; then
  echo "prep: detected uv, running uv sync..." >&2
  ( cd "${WORKTREE_PATH}" && uv sync ) >&2 || echo "prep: WARNING — uv sync failed (non-fatal)" >&2
else
  echo "prep: no lockfile found, skipping dependency install" >&2
fi

# --- create planning folder + meta.md ---
mkdir -p "${WORKTREE_PATH}/${PLANNING_DIR}/review"
mkdir -p "${WORKTREE_PATH}/${PLANNING_DIR}/translates"
mkdir -p "${WORKTREE_PATH}/${PLANNING_DIR}/versions"

cat > "${WORKTREE_PATH}/${PLANNING_DIR}/meta.md" <<META
---
title: "Meta — ${TASK}"
type: meta
task: ${TASK}
task_date: ${DATE}
created: ${DATE}
last_updated: ${DATE}
status: active
size: ${SIZE}
parent: ../../
related: []
branch: ${BRANCH}
worktree: ${WORKTREE_PATH}
base: ${BASE}
started: ${DATE}
goal: |
  ${GOAL:-<fill in>}
---

## Notes

(Free-form. Optional.)
META

# --- output for caller ---
echo "${WORKTREE_PATH}"
echo "prep: created branch ${BRANCH} at ${WORKTREE_PATH}" >&2
echo "prep: planning dir ${WORKTREE_PATH}/${PLANNING_DIR}" >&2
