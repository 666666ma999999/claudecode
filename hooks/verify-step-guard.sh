#!/bin/bash
# PreToolUse hook: verify-step.pending の edit_count が閾値超なら Write/Edit をブロック
# 「書く→検証→書く」のバッチサイクルを強制する

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Write/Edit以外は無視（Bash等の検証コマンドは通す）
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

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
PENDING_FILE="$STATE_DIR/verify-step.pending"

# pending がなければ通過
[ ! -f "$PENDING_FILE" ] && exit 0

# edit_count と file情報を読み取り
RESULT=$(python3 -c "
import json, sys
try:
    with open('$PENDING_FILE') as f:
        data = json.load(f)
    edit_count = data.get('edit_count', 0)
    files = data.get('files', [])
    file_types = data.get('file_types', [])
    print(f'{edit_count}|{len(files)}|{\",\".join(file_types)}')
except:
    print('0|0|')
" 2>/dev/null)

EDIT_COUNT=$(echo "$RESULT" | cut -d'|' -f1)
FILE_COUNT=$(echo "$RESULT" | cut -d'|' -f2)
FILE_TYPES=$(echo "$RESULT" | cut -d'|' -f3)

# ブロック閾値: 4回以上の編集（3タスクバッチ相当）
THRESHOLD=4

if [ "$EDIT_COUNT" -ge "$THRESHOLD" ] 2>/dev/null; then
    # 検証方法を種別に応じて提案
    VERIFY_HINT=""
    case "$FILE_TYPES" in
        *FE*)
            VERIFY_HINT="FE: ブラウザでページリロード → コンソールエラーゼロ確認 → 変更操作を1回実行"
            ;;
        *BE*)
            VERIFY_HINT="BE: サーバー再起動 → ヘルスチェック → 変更影響APIを1本以上実行"
            ;;
    esac
    [ -z "$VERIFY_HINT" ] && VERIFY_HINT="変更に応じた最短検証を実行"

    # deny応答を返してWrite/Editをブロック
    REASON="🛑 VERIFY-STEP REQUIRED: ${EDIT_COUNT}回のコード編集（${FILE_COUNT}ファイル）が未検証です。次の編集に進む前に中間検証を実行してください。${VERIFY_HINT} 検証完了後: rm ~/.claude/state/verify-step.pending"
    python3 -c "
import json
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': '''$REASON'''
    }
}))
"
    exit 0
fi

exit 0
