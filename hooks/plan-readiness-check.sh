#!/bin/bash
set -uo pipefail
# PreToolUse hook: EnterPlanMode 前の準備状態チェック
# 旧版は plain stdout + exit 0 で警告していたが、PreToolUse の exit 0 stdout は
# モデルに届かない（2026-07-04 配達監査で確定・人間の transcript 表示のみ）。
# TTL 内初回のみ exit 2 でブロックし stderr でチェックリストを届ける方式に変更。
# stamp を exit 2 の前に記録するため、再実行（2回目）は素通し = 1往復のみ。
#   - plan-strategy.json が存在する場合は即 skip（quality-check が直近プランから抽出したもの）
#   - stamp 5分TTL（古ければ再度チェックリストを出す）

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

# stamp TTL 判定（5分以内なら skip = ブロック直後の再実行は通過）
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

# stamp を先に記録（直後の再実行を通すため）
date '+%Y-%m-%d %H:%M:%S' > "$STAMP"

cat >&2 <<'MSG'
PLAN READINESS [BLOCK] このタスク初回のみ。下記を認識したらそのまま EnterPlanMode を再実行すれば通過します:
1. 応答冒頭で「Strategy宣言: [Delivery/Prototype/Clarify] — 成功基準: <1行>」を宣言する
2. プランは2段で提示する: まず骨組み（見出し+各1行）だけを出してユーザーの合意を取る。肉付けは合意後。いきなり完成品を出さない
3. 変更2ファイル以上 or 調査+実装+検証が混在するなら、Explore+Verify の並列SubAgent構成をプランに含める（execution-patterns 参照）
4. アーキ判断・設計二択・3ファイル以上なら敵対レビューの重/軽を決める: plan-adversarial-review（重）/ /review --mode=challenge（軽）。不要なら理由1行
MSG

exit 2
