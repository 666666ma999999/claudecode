#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイル変更時に simplify 要フラグを更新
# カウンタをインクリメントし、Stop hook の収束検知に使用する
# NOTE: stdout 出力なし（implementation-checklist-pending.sh が警告を担当）

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Write/Edit 以外は無視
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# ファイルパスがない場合は無視
[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下は除外（設定・スキル・フック等の編集は simplify 対象外）
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルのみ（config/data ファイルは simplify 対象外）
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.rs|*.rb|*.java|*.html|*.css) ;;
    *) exit 0 ;;
esac

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/needs-simplify.pending"

# hook入力からcwdを取得
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json,os; print(os.path.realpath(json.load(sys.stdin).get('cwd','')))" 2>/dev/null)

# JSON形式でカウンタ+cwd+TTL を記録（stop hookのcwd/TTLチェック対応）
PENDING_FILE="$PENDING" HOOK_CWD="$HOOK_CWD" python3 -c "
import json, os, sys
from datetime import datetime, timedelta

pending = os.environ.get('PENDING_FILE', '')
hook_cwd = os.environ.get('HOOK_CWD', '')
ttl_hours = 24
count = 0

if os.path.isfile(pending):
    try:
        raw = open(pending).read().strip()
        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                stored_cwd = data.get('cwd', '')
                if stored_cwd and hook_cwd and os.path.realpath(stored_cwd) != os.path.realpath(hook_cwd):
                    count = 0  # 別プロジェクト → リセット
                else:
                    count = data.get('count', 0)
        except json.JSONDecodeError:
            count = int(raw) if raw.isdigit() else 0  # 旧形式互換
    except:
        count = 0

count += 1
now = datetime.now()
with open(pending, 'w') as f:
    json.dump({
        'count': count,
        'cwd': hook_cwd,
        'ttl_expires_at': (now + timedelta(hours=ttl_hours)).isoformat(),
    }, f)
" 2>/dev/null

exit 0
