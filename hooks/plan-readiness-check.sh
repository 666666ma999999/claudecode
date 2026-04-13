#!/bin/bash
set -uo pipefail
# PreToolUse hook: EnterPlanMode 前の準備状態チェック
# Execution Strategy 未選択 or 成功基準未定義なら警告（ブロックはしない）。
# 旧実装はセッション中1回のみ表示だったが、2個目タスク以降で効かない問題を解消:
#   - stamp に 5分TTL を導入（古ければ再警告）
#   - plan-strategy.json が存在する場合は即 skip（quality-check が直近プランから抽出したもの）

INPUT=$(cat)
STATE_DIR="$HOME/.claude/state"
STAMP="$STATE_DIR/plan-readiness.done"
STRATEGY_FILE="$STATE_DIR/plan-strategy.json"
TTL_SECONDS=300  # 5分

mkdir -p "$STATE_DIR"

# Strategy 宣言の state が存在すれば skip（直近プランで選択済み）
if [ -f "$STRATEGY_FILE" ]; then
    exit 0
fi

# stamp TTL 判定（5分以内なら skip）
if [ -f "$STAMP" ]; then
    NOW=$(date +%s)
    # stat -f %m (BSD/macOS) → フォールバック stat -c %Y (GNU/Linux)
    MTIME=$(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP" 2>/dev/null || echo 0)
    if [ -n "$MTIME" ] && [ "$MTIME" -gt 0 ]; then
        AGE=$((NOW - MTIME))
        if [ "$AGE" -lt "$TTL_SECONDS" ]; then
            exit 0
        fi
    fi
fi

# 警告出力
cat <<MSG
PLAN READINESS CHECK:
EnterPlanMode 前に以下を確認してください:
1. Execution Strategy（Delivery/Prototype/Clarify）を選択しましたか？
2. Deliveryモード: 成功基準を定義しましたか？
3. スキル確認（30-routing.md + find-skills）を完了しましたか？

確認済みなら続行してください。次の警告は5分後以降、または新しいタスクで再表示されます。
MSG

# stamp 更新
date '+%Y-%m-%d %H:%M:%S' > "$STAMP"

exit 0
