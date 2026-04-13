#!/bin/bash
set -uo pipefail
# PostToolUse hook: プラン外ファイルへの Write/Edit を警告
# plan-files-snapshot.txt（ExitPlanMode時に作成）に含まれないファイルへの書き込みを検知。
# 判定はパス末尾2セグメント（dir/file.ext）の一致で行う。basenameのみの部分一致は
# 偽陰性・偽陽性を生むため廃止。

INPUT=$(cat)
FILE_PATH=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" <<<"$INPUT" 2>/dev/null | tr -d '\n')

[ -z "$FILE_PATH" ] && exit 0

STATE_DIR="$HOME/.claude/state"
SNAPSHOT="$STATE_DIR/plan-files-snapshot.txt"

[ ! -s "$SNAPSHOT" ] && exit 0

# ~/.claude/ 配下は除外（設定ファイル編集は常に許可）
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルのみチェック
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.rs|*.html|*.css) ;;
    *) exit 0 ;;
esac

# パス末尾2セグメント抽出（例: /a/b/c/d.py → c/d.py）
TAIL2=$(python3 -c "
import sys, os
p = sys.argv[1]
parts = p.strip('/').split('/')
print('/'.join(parts[-2:]) if len(parts) >= 2 else parts[-1])
" "$FILE_PATH" 2>/dev/null)

if [ -z "$TAIL2" ]; then
    exit 0
fi

# スナップショット側も末尾2セグメントで比較
MATCHED=$(python3 - "$TAIL2" "$SNAPSHOT" <<'PY' 2>/dev/null
import sys
tail = sys.argv[1]
try:
    with open(sys.argv[2]) as f:
        lines = [l.strip() for l in f if l.strip()]
except Exception:
    print('NO'); sys.exit(0)

def tail2(p):
    parts = p.strip('/').split('/')
    return '/'.join(parts[-2:]) if len(parts) >= 2 else parts[-1]

for line in lines:
    if tail2(line) == tail:
        print('YES'); sys.exit(0)
print('NO')
PY
)

if [ "$MATCHED" != "YES" ]; then
    echo "PLAN DRIFT: プラン外ファイルへの変更を検出 ($FILE_PATH)。プランの更新が必要な場合は再計画を検討してください。"
fi

exit 0
