#!/bin/bash
# PreToolUse hook: EnterPlanMode 前の準備状態チェック
# Execution Strategy 未選択 or 成功基準未定義なら警告（ブロックはしない）
# セッション中1回のみ表示（plan-readiness.done スタンプで制御）

INPUT=$(cat)
STATE_DIR="$HOME/.claude/state"

# plan-readiness スタンプが存在すれば準備済み
if [ -f "$STATE_DIR/plan-readiness.done" ]; then
    exit 0
fi

# 警告メッセージ出力（stdout → Claude コンテキスト）
cat <<MSG
PLAN READINESS CHECK:
EnterPlanMode 前に以下を確認してください:
1. Execution Strategy（Delivery/Prototype/Clarify）を選択しましたか？
2. Deliveryモード: 成功基準を定義しましたか？
3. スキル確認（30-routing.md + find-skills）を完了しましたか？

確認済みなら続行してください。このメッセージは初回のみ表示されます。
MSG

# スタンプ作成（セッション中1回のみ警告）
mkdir -p "$STATE_DIR"
date '+%Y-%m-%d %H:%M:%S' > "$STATE_DIR/plan-readiness.done"

exit 0
