#!/bin/bash
# PreToolUse hook: verify-step.pending の edit_count が閾値超なら Write/Edit をブロック
# 「書く→検証→書く」のバッチサイクルを強制する
# v2: cwd スコーピング + TTL 有効期限対応

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

# hook入力からcwdを取得
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json,os; print(os.path.realpath(json.load(sys.stdin).get('cwd','')))" 2>/dev/null)

# 単一Python呼び出しで TTL + cwd + edit_count/file_types を一括チェック
RESULT=$(PENDING_FILE="$PENDING_FILE" HOOK_CWD="$HOOK_CWD" python3 -c "
import json, os, sys
from datetime import datetime

pending_path = os.environ.get('PENDING_FILE', '')
hook_cwd = os.environ.get('HOOK_CWD', '')

try:
    with open(pending_path) as f:
        data = json.load(f)
except:
    print('pass|0|')
    sys.exit(0)

# TTL check: 期限切れなら削除して通過
ttl = data.get('ttl_expires_at', '')
if ttl:
    try:
        if datetime.fromisoformat(ttl) < datetime.now():
            os.remove(pending_path)
            print('expired|0|')
            sys.exit(0)
    except ValueError:
        pass

# CWD scope check: 別プロジェクトなら通過（ブロックしない）
stored_cwd = data.get('cwd', '')
if stored_cwd and hook_cwd:
    if os.path.realpath(stored_cwd) != os.path.realpath(hook_cwd):
        print('cwd_mismatch|0|')
        sys.exit(0)

edit_count = data.get('edit_count', 0)
file_types = ','.join(data.get('file_types', []))
print(f'check|{edit_count}|{file_types}')
" 2>/dev/null)

STATUS=$(echo "$RESULT" | cut -d'|' -f1)
EDIT_COUNT=$(echo "$RESULT" | cut -d'|' -f2)
FILE_TYPES=$(echo "$RESULT" | cut -d'|' -f3)

# TTL期限切れ or cwd不一致 or エラー → 通過
case "$STATUS" in
    expired|cwd_mismatch|pass)
        exit 0
        ;;
esac

# ブロック閾値: FE=3回、BE=4回
THRESHOLD=4
case "$FILE_TYPES" in
    *FE*)
        THRESHOLD=3
        ;;
esac

if [ "$EDIT_COUNT" -ge "$THRESHOLD" ] 2>/dev/null; then
    # 検証方法を種別に応じて提案
    VERIFY_HINT=""
    case "$FILE_TYPES" in
        *FE*)
            VERIFY_HINT="FE: Playwright MCPで検証必須 → (1) browser_navigate でページを開く (2) browser_console_messages でエラーゼロ確認 (3) browser_snapshot or browser_click で変更操作を1回実行。※ Playwright実行で自動リセットされます。curl/pytest ではFE検証としてリセットされません。"
            ;;
        *BE*)
            VERIFY_HINT="BE: サーバー再起動 → ヘルスチェック → 変更影響APIを1本以上実行"
            ;;
    esac
    [ -z "$VERIFY_HINT" ] && VERIFY_HINT="変更に応じた最短検証を実行"

    # deny応答を返してWrite/Editをブロック（環境変数経由でPythonに渡す）
    export VS_REASON="🛑 VERIFY-STEP REQUIRED: ${EDIT_COUNT}回のコード編集が未検証です。次の編集に進む前に中間検証を実行してください。${VERIFY_HINT} BE検証コマンド（curl, pytest, npm test等）はBash実行で自動リセットされます。"
    python3 -c "
import json, os
reason = os.environ.get('VS_REASON', 'Verification required')
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}))
"
    exit 0
fi

exit 0
