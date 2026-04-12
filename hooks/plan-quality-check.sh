#!/bin/bash
# PreToolUse hook: ExitPlanMode 前のプラン品質チェック
# プランファイルに必須セクション（Goal/Tasks/Verification）が含まれているか検証
# プラン内のファイルパスを plan-files-snapshot.txt にスナップショット保存（drift検知用）

INPUT=$(cat)
STATE_DIR="$HOME/.claude/state"

# プランファイルパスを取得（plans/ ディレクトリの最新 .md）
PLAN_FILE=""
for dir in "$HOME/.claude/plans" "./.claude/plans"; do
    if [ -d "$dir" ]; then
        CANDIDATE=$(ls -t "$dir"/*.md 2>/dev/null | head -1)
        if [ -n "$CANDIDATE" ]; then
            PLAN_FILE="$CANDIDATE"
            break
        fi
    fi
done

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
    echo "PLAN QUALITY: プランファイルが見つかりません。ExitPlanMode 前にプランを作成してください。"
    exit 0
fi

# 必須セクション検査（python3 で一括チェック）
RESULT=$(python3 -c "
import re
with open('$PLAN_FILE') as f:
    content = f.read()

required = {
    'Goal': bool(re.search(r'##\s*(Goal|Context|目標|ゴール)', content, re.I)),
    'Tasks': bool(re.search(r'##\s*(Tasks|タスク|実装|変更ファイル)', content, re.I)),
    'Verification': bool(re.search(r'##\s*(Verif|検証|テスト)', content, re.I)),
}

missing = [k for k, v in required.items() if not v]
if missing:
    print('MISSING=' + ','.join(missing))
else:
    print('OK')
" 2>/dev/null)

mkdir -p "$STATE_DIR"

case "$RESULT" in
    OK)
        # プランドリフト検知用: プランのファイルパスをスナップショット保存
        grep -oE '/[^ )]*\.(py|js|ts|tsx|jsx|go|rs|html|css)' "$PLAN_FILE" 2>/dev/null | sort -u > "$STATE_DIR/plan-files-snapshot.txt" 2>/dev/null
        ;;
    MISSING=*)
        SECTIONS=$(echo "$RESULT" | cut -d= -f2)
        echo "PLAN QUALITY: プランに以下のセクションがありません: ${SECTIONS}。追加を検討してください。"
        ;;
    *)
        echo "PLAN QUALITY: プランファイルの検証に失敗しました。"
        ;;
esac

exit 0
