#!/bin/bash
set -uo pipefail
# PreToolUse hook: 変更禁止ファイルへの Write/Edit を auto-block (exit 2)
# plan-forbidden.txt (plan-quality-check.sh が ExitPlanMode 時に生成) に含まれるパスへの
# 編集を末尾2セグメント一致でブロックする。
# 比較ロジックは plan-drift-warn.sh と同じ (偽陰性/偽陽性回避のため tail2 採用)。

INPUT=$(cat)
FILE_PATH=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" <<<"$INPUT" 2>/dev/null | tr -d '\n')

[ -z "$FILE_PATH" ] && exit 0

STATE_DIR="$HOME/.claude/state"
FORBIDDEN="$STATE_DIR/plan-forbidden.txt"

[ ! -s "$FORBIDDEN" ] && exit 0

# ~/.claude/ 配下は除外 (設定/スキル編集は常に許可)
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# パス末尾2セグメント抽出
TAIL2=$(python3 -c "
import sys
p = sys.argv[1]
parts = p.strip('/').split('/')
print('/'.join(parts[-2:]) if len(parts) >= 2 else parts[-1])
" "$FILE_PATH" 2>/dev/null)

[ -z "$TAIL2" ] && exit 0

MATCHED=$(python3 - "$TAIL2" "$FORBIDDEN" <<'PY' 2>/dev/null
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

if [ "$MATCHED" = "YES" ]; then
    echo "PLAN FORBIDDEN: 変更禁止ファイルへの編集が拒否されました ($FILE_PATH)。プランの「変更禁止ファイル」セクションに記載されています。プランを更新するか、編集が必要なら再計画してください。" >&2
    exit 2
fi

exit 0
