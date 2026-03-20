#!/bin/bash
# PreCompact hook: Backup important state before context compression
# Saves implementation checklist, task files, git status/diff to timestamped backup

INPUT=$(cat)

STATE_DIR="$HOME/.claude/state"
BACKUP_ROOT="$STATE_DIR/precompact-backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 1. Copy implementation checklist pending file if exists
PENDING="$STATE_DIR/implementation-checklist.pending"
[ -f "$PENDING" ] && cp "$PENDING" "$BACKUP_DIR/"

# 2. Copy task files from current working directory
if [ -f "task.md" ]; then
  cp "task.md" "$BACKUP_DIR/"
fi
if [ -d "tasks" ]; then
  mkdir -p "$BACKUP_DIR/tasks"
  for f in tasks/*.md; do
    [ -f "$f" ] && cp "$f" "$BACKUP_DIR/tasks/"
  done
fi

# 3. Git status and diff snapshots
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git status --short > "$BACKUP_DIR/git-status.txt" 2>/dev/null
  git diff --stat > "$BACKUP_DIR/git-diff-stat.txt" 2>/dev/null
fi

# 4. Keep only the last 10 backups (delete oldest)
BACKUP_COUNT=$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -gt 10 ]; then
  ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | head -n $(( BACKUP_COUNT - 10 )) | while read dir; do
    rm -rf "$dir"
  done
fi

# 5. Report to stderr (not stdout, to avoid interfering with compression)
echo "PreCompact backup saved to $BACKUP_DIR" >&2

exit 0
