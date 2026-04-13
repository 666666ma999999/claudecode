#!/bin/bash
# PostToolUse hook: mcp__codex__codex 実行時にCodexレビュー段階を追跡
# - 成功時: 2段階カウント (仕様準拠 → 品質) → .done 作成
# - 失敗時 (quota超過等): count増やさず、フォールバックreviewer起動をClaudeに要請

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/implementation-checklist.pending"
COUNT_FILE="$STATE_DIR/codex-review.count"
DONE="$STATE_DIR/codex-review.done"
FALLBACK_FLAG="$STATE_DIR/codex-fallback-needed"

# pending状態でなければ追跡不要
[ -f "$PENDING" ] || exit 0

# 既に2段階完了済みなら追加カウントしない
[ -f "$DONE" ] && exit 0

mkdir -p "$STATE_DIR"

# stdin から Codex の tool_response を読み、失敗判定
INPUT=$(cat)
IS_ERROR=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    data = json.load(sys.stdin)
    resp = json.dumps(data.get('tool_response', ''), ensure_ascii=False).lower()
    # quota / rate limit / auth error を検知
    patterns = [r'quota exceeded', r'rate limit', r'authentication', r'\"is_error\"\s*:\s*true']
    if any(re.search(p, resp) for p in patterns):
        print('error')
    else:
        print('ok')
except Exception:
    print('ok')
" 2>/dev/null)

# JSON additionalContext ヘルパー（PostToolUse stdout は Claude に届かないため）
emit_context() {
    python3 -c "
import json, sys
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': sys.stdin.read()
    }
}))
" <<< "$1"
}

if [ "$IS_ERROR" = "error" ]; then
    # Codex失敗 → count増やさず、フォールバックを要請
    touch "$FALLBACK_FLAG"
    FILES=$(tail -n +2 "$PENDING" 2>/dev/null | head -5 | sed 's/^/   - /')
    emit_context "<system-reminder severity=\"high\" action-required=\"codex-fallback-review\">
Codex呼び出しが失敗しました（quota/rate limit/auth等）。Codexレビューはスキップされます。

フォールバック手順（次のターンで自動実行してください）:
1. feature-dev:code-reviewer Agentを起動し、以下ファイルを仕様準拠+コード品質の2観点でレビュー:
${FILES}
2. ブロッカーがあれば修正
3. 完了したら: touch ~/.claude/state/codex-review.done

これでパイプライン（auto-skill-review等）が再開します。
</system-reminder>"
    exit 0
fi

# 正常系: カウント読み取り・インクリメント
COUNT=0
[ -f "$COUNT_FILE" ] && COUNT=$(cat "$COUNT_FILE" 2>/dev/null | tr -d '[:space:]')
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if [ "$COUNT" -ge 2 ]; then
    date '+%Y-%m-%d %H:%M:%S' > "$DONE"
    rm -f "$FALLBACK_FLAG"
    emit_context "<system-reminder severity=\"info\">
✅ Codex review Stage 2 (品質) recorded. Both stages complete. checklist解除可能。
</system-reminder>"
else
    emit_context "<system-reminder severity=\"info\" action-required=\"codex-stage-2\">
✅ Codex review Stage 1 (仕様準拠) recorded. Stage 2 (品質レビュー) が必要です。
</system-reminder>"
fi
