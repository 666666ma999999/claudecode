#!/bin/bash
# PreCompact hook: Build a restore note for Claude to reference after context compression
# Creates ~/.claude/state/compact-restore.md with pending state, git status, and task info

INPUT=$(cat)

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
RESTORE_FILE="$STATE_DIR/compact-restore.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --- Pending State ---
PENDING_FILE="$STATE_DIR/implementation-checklist.pending"
if [ -f "$PENDING_FILE" ]; then
  PENDING_STATUS="pending"
  PENDING_FILES=$(tail -n +2 "$PENDING_FILE" | sed 's/^/  - /')
else
  PENDING_STATUS="clear"
  PENDING_FILES=""
fi

# --- Git Status (max 20 lines) ---
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_STATUS=$(git status --short 2>/dev/null | head -20)
else
  GIT_STATUS="(not a git repository)"
fi

# --- Current Task (Session Handoff section) ---
TASK_CONTENT=""
for candidate in "task.md" tasks/*.md; do
  [ -f "$candidate" ] || continue
  HANDOFF=$(sed -n '/## Session Handoff/,/^## [^S]/{/^## [^S]/d;p;}' "$candidate" 2>/dev/null | head -20)
  if [ -n "$HANDOFF" ]; then
    TASK_CONTENT="Source: ${candidate}
${HANDOFF}"
    break
  fi
done
[ -z "$TASK_CONTENT" ] && TASK_CONTENT="No active task"

# --- Write restore file ---
cat > "$RESTORE_FILE" << EOF
# Session Restore Note (auto-generated at ${TIMESTAMP})

## Pending State
- implementation-checklist: ${PENDING_STATUS}
${PENDING_FILES}

## Git Status
\`\`\`
${GIT_STATUS}
\`\`\`

## Current Task
${TASK_CONTENT}
EOF

# Print nothing to stdout (don't interfere with compression)
exit 0
