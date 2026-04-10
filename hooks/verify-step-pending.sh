#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したら verify-step pending を積む
# implementation-checklist.pending（最終ゲート）とは別の中間検証用state
# edit_count が閾値を超えたら次の Write/Edit をブロックするための情報を蓄積
# ファイルパス追跡は implementation-checklist.pending に一本化済み

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Write/Edit以外は無視
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下は除外
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルかどうか判定
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.html|*.css|*.go|*.rs|*.rb|*.java)
        ;;
    *)
        exit 0
        ;;
esac

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
PENDING_FILE="$STATE_DIR/verify-step.pending"

# FE/BE種別判定
FILE_TYPE="unknown"
case "$FILE_PATH" in
    *.html|*.css|*.jsx|*.tsx)
        FILE_TYPE="FE"
        ;;
    *.py|*.go|*.rs|*.rb|*.java)
        FILE_TYPE="BE"
        ;;
    *.js|*.ts)
        # frontend/ 配下ならFE、それ以外はBE
        case "$FILE_PATH" in
            */frontend/*|*/static/*|*/public/*) FILE_TYPE="FE" ;;
            *) FILE_TYPE="BE" ;;
        esac
        ;;
esac

if [ -f "$PENDING_FILE" ]; then
    # 既存のpendingを更新（edit_count + file_types のみ）
    EDIT_COUNT=$(python3 -c "
import json, sys
try:
    with open('$PENDING_FILE') as f:
        data = json.load(f)
    data['edit_count'] = data.get('edit_count', 0) + 1
    types = set(data.get('file_types', []))
    types.add('$FILE_TYPE')
    data['file_types'] = list(types)
    if '$FILE_TYPE' == 'FE':
        data['fe_verify_required'] = True
    with open('$PENDING_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print(data['edit_count'])
except Exception as e:
    print(0, file=sys.stderr)
    print(0)
" 2>/dev/null)
else
    # 新規pending作成（files[] なし）
    python3 -c "
import json
from datetime import datetime
data = {
    'created_at': datetime.now().isoformat(),
    'file_types': ['$FILE_TYPE'],
    'edit_count': 1,
    'fe_verify_required': '$FILE_TYPE' == 'FE'
}
with open('$PENDING_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
    EDIT_COUNT=1
fi

# 編集回数が閾値に達したら警告（ブロックはguard側で行う）
# FE: ブロック閾値2のため、1回目で警告（次でブロック予告）
# BE: ブロック閾値4のため、3回目で警告（従来通り）
WARN_THRESHOLD=3
if [ "$FILE_TYPE" = "FE" ] && [ "$EDIT_COUNT" -ge 1 ] 2>/dev/null; then
    echo "⚡ FE VERIFY WARNING: FE変更${EDIT_COUNT}回目。次の編集でブロックされます。Playwright MCPでブラウザ検証を実行してください（browser_navigate → console_messages → snapshot/click）。"
elif [ "$EDIT_COUNT" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
    echo "⚡ VERIFY-STEP REMINDER: ${EDIT_COUNT}回のコード編集が未検証です。次の編集前に検証を実行してください（BE: curl/テスト、FE: ブラウザ確認）。"
fi

# 3-Fix Limit: 同一ファイルへの連続修正回数を追跡
FIX_COUNT_FILE="$STATE_DIR/fix-retry-count"
FIX_LAST_FILE="$STATE_DIR/fix-last-file"
if [ -f "$FIX_LAST_FILE" ]; then
    LAST_FILE=$(cat "$FIX_LAST_FILE" 2>/dev/null)
    if [ "$LAST_FILE" = "$FILE_PATH" ]; then
        # 同一ファイルへの連続修正 → カウント増加
        CURRENT_COUNT=$(cat "$FIX_COUNT_FILE" 2>/dev/null || echo 0)
        echo $((CURRENT_COUNT + 1)) > "$FIX_COUNT_FILE"
    else
        # 別ファイルに移った → リセット
        echo 1 > "$FIX_COUNT_FILE"
    fi
else
    echo 1 > "$FIX_COUNT_FILE"
fi
echo "$FILE_PATH" > "$FIX_LAST_FILE"

exit 0
