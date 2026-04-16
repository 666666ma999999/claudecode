#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したら verify-step pending を積む
# implementation-checklist.pending（最終ゲート）とは別の中間検証用state
# edit_count が閾値を超えたら次の Write/Edit をブロックするための情報を蓄積
# v2: cwd スコーピング + TTL + 環境変数経由Python（quote injection対策）

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

# hook入力からcwdを取得
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json,os; print(os.path.realpath(json.load(sys.stdin).get('cwd','')))" 2>/dev/null)

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

# pending作成/更新（環境変数経由でPythonに値を渡す — quote injection対策）
EDIT_COUNT=$(PENDING_FILE="$PENDING_FILE" HOOK_CWD="$HOOK_CWD" FILE_TYPE="$FILE_TYPE" python3 -c "
import json, os, sys, tempfile
from datetime import datetime, timedelta

pending_path = os.environ.get('PENDING_FILE', '')
hook_cwd = os.environ.get('HOOK_CWD', '')
file_type = os.environ.get('FILE_TYPE', 'unknown')
ttl_minutes = 30

def write_atomic(path, data):
    \"\"\"原子的書き込み: tmp → os.replace\"\"\"
    dir_name = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, path)
    except:
        try: os.unlink(tmp)
        except: pass
        raise

now = datetime.now()

if os.path.isfile(pending_path):
    try:
        with open(pending_path) as f:
            data = json.load(f)
    except:
        data = {}

    # cwd不一致 → 別プロジェクトの古い状態。リセットして新規作成
    stored_cwd = data.get('cwd', '')
    if stored_cwd and hook_cwd and os.path.realpath(stored_cwd) != os.path.realpath(hook_cwd):
        data = {
            'created_at': now.isoformat(),
            'cwd': hook_cwd,
            'ttl_expires_at': (now + timedelta(minutes=ttl_minutes)).isoformat(),
            'file_types': [file_type],
            'edit_count': 1,
            'fe_verify_required': file_type == 'FE'
        }
        write_atomic(pending_path, data)
        print(1)
        sys.exit(0)

    # 同一プロジェクト → edit_count インクリメント + TTL更新
    data['edit_count'] = data.get('edit_count', 0) + 1
    types = set(data.get('file_types', []))
    types.add(file_type)
    data['file_types'] = list(types)
    if file_type == 'FE':
        data['fe_verify_required'] = True
    # cwd が無い古い形式のファイル → cwd追加
    if not data.get('cwd'):
        data['cwd'] = hook_cwd
    # TTLをローリング更新
    data['ttl_expires_at'] = (now + timedelta(minutes=ttl_minutes)).isoformat()
    write_atomic(pending_path, data)
    print(data['edit_count'])
else:
    # 新規pending作成
    data = {
        'created_at': now.isoformat(),
        'cwd': hook_cwd,
        'ttl_expires_at': (now + timedelta(minutes=ttl_minutes)).isoformat(),
        'file_types': [file_type],
        'edit_count': 1,
        'fe_verify_required': file_type == 'FE'
    }
    write_atomic(pending_path, data)
    print(1)
" 2>/dev/null)

# 編集回数が閾値に達したら警告（ブロックはguard側で行う）
# FE: ブロック閾値3のため、2回目で警告
# BE: ブロック閾値4のため、3回目で警告
if [ "$FILE_TYPE" = "FE" ] && [ "$EDIT_COUNT" -ge 2 ] 2>/dev/null; then
    echo "⚡ FE VERIFY WARNING: FE変更${EDIT_COUNT}回目。次の編集でブロックされます。Playwright MCPでブラウザ検証を実行してください（browser_navigate → console_messages → snapshot/click）。"
elif [ "$EDIT_COUNT" -ge 3 ] 2>/dev/null; then
    echo "⚡ VERIFY-STEP REMINDER: ${EDIT_COUNT}回のコード編集が未検証です。次の編集前に検証を実行してください（BE: curl/テスト、FE: ブラウザ確認）。"
fi

# 3-Fix Limit: 同一ファイルへの連続修正回数を追跡
FIX_COUNT_FILE="$STATE_DIR/fix-retry-count"
FIX_LAST_FILE="$STATE_DIR/fix-last-file"
if [ -f "$FIX_LAST_FILE" ]; then
    LAST_FILE=$(cat "$FIX_LAST_FILE" 2>/dev/null)
    if [ "$LAST_FILE" = "$FILE_PATH" ]; then
        CURRENT_COUNT=$(cat "$FIX_COUNT_FILE" 2>/dev/null || echo 0)
        echo $((CURRENT_COUNT + 1)) > "$FIX_COUNT_FILE"
    else
        echo 1 > "$FIX_COUNT_FILE"
    fi
else
    echo 1 > "$FIX_COUNT_FILE"
fi
echo "$FILE_PATH" > "$FIX_LAST_FILE"

exit 0
