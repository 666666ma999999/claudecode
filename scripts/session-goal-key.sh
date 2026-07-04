#!/usr/bin/env bash
# session-goal-key.sh — single source of truth for the session-goal file path.
#
# SOURCE this file (do not execute). It is the ONE place that derives the goal
# storage key, so the writer (session-goal.sh), the statusline (statusline.sh),
# and the per-turn injection hook (hooks/session-goal-gate.sh) never drift.
#
# Optional input : SGK_BASE env var = base directory (default: current pwd).
# Exports        : GOAL_KEY, GOAL_DIR, GOAL_FILE, GOAL_ROOT
#
# The unit is the git "work tree" (so each worktree has its own goal; subdirs
# resolve to the same root). Falls back to the literal base dir outside git.

_sgk_base="${SGK_BASE:-$(pwd -P)}"
_sgk_top="$(git -C "$_sgk_base" rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$_sgk_top" ]; then _sgk_dir="$_sgk_top"; else _sgk_dir="$_sgk_base"; fi

GOAL_ROOT="$_sgk_dir"
GOAL_KEY=$(printf '%s' "$_sgk_dir" | sed 's|[^A-Za-z0-9._-]|-|g; s|^-*||')
GOAL_DIR="$HOME/.claude/state/session-goals"
GOAL_FILE="$GOAL_DIR/$GOAL_KEY.txt"
export GOAL_ROOT GOAL_KEY GOAL_DIR GOAL_FILE

unset SGK_BASE _sgk_base _sgk_top _sgk_dir
