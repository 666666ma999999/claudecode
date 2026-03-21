#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したら verify-step pending を積む
# implementation-checklist.pending（最終ゲート）とは別の中間検証用state
# edit_count が閾値を超えたら次の Write/Edit をブロックするための情報を蓄積

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
    # 既存のpendingに追記
    EDIT_COUNT=$(python3 -c "
import json, sys
try:
    with open('$PENDING_FILE') as f:
        data = json.load(f)
    # ファイル追加
    if '$FILE_PATH' not in data.get('files', []):
        data['files'].append('$FILE_PATH')
    data['edit_count'] = data.get('edit_count', 0) + 1
    # FE/BE種別を蓄積
    types = set(data.get('file_types', []))
    types.add('$FILE_TYPE')
    data['file_types'] = list(types)
    with open('$PENDING_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print(data['edit_count'])
except Exception as e:
    print(0, file=sys.stderr)
    print(0)
" 2>/dev/null)
else
    # 新規pending作成
    python3 -c "
import json
from datetime import datetime
data = {
    'created_at': datetime.now().isoformat(),
    'files': ['$FILE_PATH'],
    'file_types': ['$FILE_TYPE'],
    'edit_count': 1
}
with open('$PENDING_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
    EDIT_COUNT=1
fi

# 編集回数が閾値に達したら警告（ブロックはguard側で行う）
if [ "$EDIT_COUNT" -ge 3 ] 2>/dev/null; then
    echo "⚡ VERIFY-STEP REMINDER: ${EDIT_COUNT}回のコード編集が未検証です。次の編集前に検証を実行してください（BE: curl/テスト、FE: ブラウザ確認）。"
fi

exit 0
