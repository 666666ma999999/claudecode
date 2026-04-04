#!/bin/bash
# PostToolUse hook: mcp__codex__codex 実行時にCodexレビュー段階を追跡
# implementation-checklist.pending 存在時のみ追跡
# 2段階: Stage 1(仕様準拠) → Stage 2(品質) → .done 作成

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/implementation-checklist.pending"
COUNT_FILE="$STATE_DIR/codex-review.count"
DONE="$STATE_DIR/codex-review.done"

# pending状態でなければ追跡不要
[ -f "$PENDING" ] || exit 0

# 既に2段階完了済みなら追加カウントしない（修正後の再レビュー等）
[ -f "$DONE" ] && exit 0

mkdir -p "$STATE_DIR"

# カウント読み取り・インクリメント
COUNT=0
[ -f "$COUNT_FILE" ] && COUNT=$(cat "$COUNT_FILE" 2>/dev/null | tr -d '[:space:]')
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if [ "$COUNT" -ge 2 ]; then
    date '+%Y-%m-%d %H:%M:%S' > "$DONE"
    echo "✅ Codex review Stage 2 (品質) recorded. Both stages complete. checklist解除可能。"
else
    echo "✅ Codex review Stage 1 (仕様準拠) recorded. Stage 2 (品質レビュー) が必要です。"
fi
