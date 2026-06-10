#!/usr/bin/env bash
# stop-vault-summary-suggest.sh — Stop hook (rules/42 Phase 2 β・案 II)
#
# 目的: Stop 時に edit-history.jsonl から「rules/42 要約対象ファイル」候補を抽出し、
#       stdout で /sync-vault-summary 起動を推奨する (warning のみ・block しない)。
#
# 設計理由 (codex + Agent 検証 2026-05-25 結論・両者で案 II 推奨一致):
# - 案 I (decision:"block") は公式 docs 未明文化 + 既存 wiki-auto-capture-on-stop と JSON 衝突
# - 案 III (heuristic 抽出) は LLM 要約品質保証不可
# - 案 II = stdout warning + 人間/Claude が /sync-vault-summary を起動 が唯一の安全パス
#
# 安全機構:
# - flag gate: ~/.claude/state/vault-cc-enabled 不在で完全休眠
# - stop_hook_active=true で即 exit (無限ループ防止)
# - 候補 0 件で何も出力しない
set -u

INPUT=$(cat 2>/dev/null || true)

# flag check
[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

# 再入防止
STOP_ACTIVE=$(echo "$INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('stop_hook_active',False))
except: print('False')" 2>/dev/null)
[ "$STOP_ACTIVE" = "True" ] && exit 0

SESSION=$(echo "$INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except: print('')" 2>/dev/null)
[ -z "$SESSION" ] && exit 0

# edit-history.jsonl から同 session の Edit/Write を抽出、rules/42 PAT でフィルタ
CANDIDATES=$(python3 - "$SESSION" <<'PY'
import json, sys, re
from pathlib import Path
session = sys.argv[1]
log = Path.home() / ".claude/state/edit-history.jsonl"
# rules/42 D-1〜D-5 / C-1〜C-5 / H-1〜H-5 / 0-3 仕様 / 0-4 施策 / 0-5 計画
PAT = re.compile(
    r"/(plan|measures-detail|measure-impact-table|spec|analysis|"
    r"data-sources|data_lineage|schema-|glossary|README|CLAUDE|"
    r"SECURITY|setup-runbook|rationales/).*\.(md|ya?ml)$"
    r"|/tasks/phase-tracker\.md$"
    r"|/02_Ai/[^/]+/(?:[^/]+/)?research/(?:_raw/|_archive/)?[^/]+\.md$"
)
seen = {}
if log.exists():
    for line in log.read_text().splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("session") != session:
            continue
        f = d.get("file", "")
        if PAT.search(f):
            seen[f] = d.get("ts", "")
# 直近 10 件 (古い順 → 新しい順)
for f, ts in sorted(seen.items(), key=lambda x: x[1])[-10:]:
    print(f)
PY
)

[ -z "$CANDIDATES" ] && exit 0

echo ""
echo "📝 VAULT_SUMMARY_SUGGEST: 本セッションで rules/42 対象ファイルが編集されました。"
echo "   vault MOC の「🔁 最新更新ログ」セクションに LLM 生成サマリー (1-3 行) を append 推奨："
echo "$CANDIDATES" | sed 's|^|   - |'
echo "   → /sync-vault-summary を実行 (要約生成 + MOC append + last_updated 更新)"
echo "   ※ 不要なら無視 (このメッセージは ~/.claude/state/vault-cc-enabled flag を rm で消える)"
exit 0
