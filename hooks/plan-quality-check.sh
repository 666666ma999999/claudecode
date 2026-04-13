#!/bin/bash
# PreToolUse hook: ExitPlanMode 前のプラン品質チェック
# 必須セクション（Goal/Architecture/Tasks/Verification、Delivery時は成功基準）を検査。
# プラン内のファイルパスを plan-files-snapshot.txt にスナップショット保存（drift検知用）。
# Strategy 宣言を state/plan-strategy.json に保存（readiness-check/drift-warn の下流で参照）。
#
# プラン本文の入手優先度:
#   1) stdin の tool_input.plan
#   2) $CLAUDE_PLAN_FILE
#   3) ./.claude/plans/*.md、~/.claude/plans/*.md、./tasks/*.md、./docs/plans/*.md の最新

INPUT=$(cat)
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

# 1) stdin の tool_input.plan を取得
PLAN_TEXT=$(python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read() or '{}')
    print(data.get('tool_input', {}).get('plan', ''))
except Exception:
    pass
" <<<"$INPUT" 2>/dev/null)

PLAN_FILE=""
TMP_PLAN=""

if [ -n "$PLAN_TEXT" ]; then
    TMP_PLAN=$(mktemp)
    printf '%s' "$PLAN_TEXT" > "$TMP_PLAN"
    PLAN_FILE="$TMP_PLAN"
elif [ -n "${CLAUDE_PLAN_FILE:-}" ] && [ -f "$CLAUDE_PLAN_FILE" ]; then
    PLAN_FILE="$CLAUDE_PLAN_FILE"
else
    # 2) ファイル探索（拡張ロケーション）
    for dir in "./.claude/plans" "$HOME/.claude/plans" "./tasks" "./docs/plans"; do
        if [ -d "$dir" ]; then
            CANDIDATE=$(ls -t "$dir"/*.md 2>/dev/null | head -1)
            if [ -n "$CANDIDATE" ]; then
                PLAN_FILE="$CANDIDATE"
                break
            fi
        fi
    done
fi

cleanup() { [ -n "$TMP_PLAN" ] && rm -f "$TMP_PLAN"; }
trap cleanup EXIT

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
    echo "PLAN QUALITY: プランファイルが見つかりません。ExitPlanMode 前にプランを作成してください。"
    exit 0
fi

# 3) セクション検査 + Strategy 抽出
RESULT=$(python3 - "$PLAN_FILE" "$STATE_DIR" <<'PY' 2>/dev/null
import re, sys, json, os, datetime

plan_path = sys.argv[1]
state_dir = sys.argv[2]
with open(plan_path, encoding='utf-8') as f:
    content = f.read()

# Strategy 抽出
m = re.search(r'Execution\s*Strategy\s*[::]\s*(Delivery|Prototype|Clarify)', content, re.I)
strategy = m.group(1).capitalize() if m else None
if strategy:
    with open(os.path.join(state_dir, 'plan-strategy.json'), 'w') as sf:
        json.dump({
            'strategy': strategy,
            'selected_at': datetime.datetime.now().isoformat(timespec='seconds'),
        }, sf)

required = {
    'Goal':         bool(re.search(r'##\s*(Goal|Context|目標|ゴール)', content, re.I)),
    'Architecture': bool(re.search(r'##\s*(Architecture|設計|アーキテクチャ)', content, re.I)),
    'Tasks':        bool(re.search(r'##\s*(Tasks|タスク|実装|変更ファイル)', content, re.I)),
    'Verification': bool(re.search(r'##\s*(Verif|検証|テスト)', content, re.I)),
}
# 成功基準は Delivery の時のみ必須。未検出（None）は「Delivery相当」で必須扱い。
if strategy in (None, 'Delivery'):
    required['成功基準'] = bool(re.search(r'##\s*(成功基準|Success\s*Criteria)', content, re.I))

missing = [k for k, v in required.items() if not v]
if missing:
    print('MISSING=' + ','.join(missing))
else:
    print('OK')
PY
)

case "$RESULT" in
    OK)
        # プランドリフト検知用スナップショット
        grep -oE '[A-Za-z0-9_./-]+\.(py|js|ts|tsx|jsx|go|rs|html|css)' "$PLAN_FILE" 2>/dev/null \
            | sort -u > "$STATE_DIR/plan-files-snapshot.txt" 2>/dev/null
        ;;
    MISSING=*)
        SECTIONS=$(echo "$RESULT" | cut -d= -f2)
        echo "PLAN QUALITY: プランに以下のセクションがありません: ${SECTIONS}。追加を検討してください。"
        # OKでないが snapshot は部分的に書いておく（drift検知は続けたい）
        grep -oE '[A-Za-z0-9_./-]+\.(py|js|ts|tsx|jsx|go|rs|html|css)' "$PLAN_FILE" 2>/dev/null \
            | sort -u > "$STATE_DIR/plan-files-snapshot.txt" 2>/dev/null
        ;;
    *)
        echo "PLAN QUALITY: プランファイルの検証に失敗しました。"
        ;;
esac

exit 0
