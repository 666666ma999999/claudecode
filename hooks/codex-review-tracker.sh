#!/bin/bash
# PostToolUse hook: mcp__codex__codex 実行時にCodexレビュー完了を記録
# implementation-checklist.pending 存在時のみ追跡

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/implementation-checklist.pending"
DONE="$STATE_DIR/codex-review.done"

# pending状態でなければ追跡不要
[ -f "$PENDING" ] || exit 0

mkdir -p "$STATE_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$DONE"
echo "✅ Codex review recorded. implementation-checklist STEP 2 progressing."
