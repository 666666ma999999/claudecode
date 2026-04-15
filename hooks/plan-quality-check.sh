#!/bin/bash
set -uo pipefail
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
    TMP_PLAN=$(mktemp) || { echo "PLAN QUALITY: 一時ファイル作成失敗。検査をスキップします。"; exit 0; }
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

# 3) セクション検査 + Strategy 抽出 + パス抽出 (snapshot/forbidden)
# MVP 必須セクション: 成功基準 / 影響範囲 / 変更禁止ファイル (常に必須・Strategy 非依存)
# パス抽出元:
#   - plan-files-snapshot.txt ← 影響範囲セクション (drift-warn.sh が参照)
#   - plan-forbidden.txt      ← 変更禁止ファイルセクション (plan-forbidden-block.sh が参照)
RESULT=$(python3 - "$PLAN_FILE" "$STATE_DIR" <<'PY' 2>"$STATE_DIR/plan-quality-check-err.log"
import re, sys, json, os, datetime

plan_path = sys.argv[1]
state_dir = sys.argv[2]
with open(plan_path, encoding='utf-8') as f:
    content = f.read()

# Strategy 抽出 (state 保存は readiness-check が参照)
m = re.search(r'Execution\s*Strategy\s*[::]\s*(Delivery|Prototype|Clarify)', content, re.I)
strategy = m.group(1).capitalize() if m else None
if strategy:
    with open(os.path.join(state_dir, 'plan-strategy.json'), 'w') as sf:
        json.dump({
            'strategy': strategy,
            'selected_at': datetime.datetime.now().isoformat(timespec='seconds'),
        }, sf)

# MVP 必須セクション (常に必須)
required = {
    '成功基準':         bool(re.search(r'##\s*(成功基準|Success\s*Criteria)', content, re.I)),
    '影響範囲':         bool(re.search(r'##\s*(影響範囲|Impact|Scope|変更ファイル|Tasks)', content, re.I)),
    '変更禁止ファイル': bool(re.search(r'##\s*(変更禁止ファイル|Forbidden|変更禁止)', content, re.I)),
}
missing = [k for k, v in required.items() if not v]

# セクション本文を抽出してパス収集
def section_body(headers):
    # 終了条件: 任意の見出し (##, ###, ...) または末尾
    pattern = r'##\s*(?:' + '|'.join(headers) + r')[^\n]*\n(.*?)(?=\n#{1,6}\s|\Z)'
    mm = re.search(pattern, content, re.S | re.I)
    return mm.group(1) if mm else ''

PATH_RE = r'[A-Za-z0-9_./\-*]+\.(?:py|js|ts|tsx|jsx|go|rs|html|css|json|yaml|yml|sh|md)'

scope_body = section_body(['影響範囲', 'Impact', 'Scope', '変更ファイル', 'Tasks'])
forbidden_body = section_body(['変更禁止ファイル', 'Forbidden', '変更禁止'])

scope_paths = sorted(set(re.findall(PATH_RE, scope_body)))
forbidden_paths = sorted(set(re.findall(PATH_RE, forbidden_body)))

with open(os.path.join(state_dir, 'plan-files-snapshot.txt'), 'w') as f:
    f.write('\n'.join(scope_paths))
with open(os.path.join(state_dir, 'plan-forbidden.txt'), 'w') as f:
    f.write('\n'.join(forbidden_paths))

if missing:
    print('MISSING=' + ','.join(missing))
else:
    print('OK')
PY
)

case "$RESULT" in
    OK)
        ;;
    MISSING=*)
        SECTIONS=$(echo "$RESULT" | cut -d= -f2)
        echo "PLAN QUALITY: プランに以下の必須セクションがありません: ${SECTIONS}。追加してください (~/.claude/templates/plan.md 参照)。"
        ;;
    *)
        echo "PLAN QUALITY: プランファイルの検証に失敗しました。"
        ;;
esac

exit 0
