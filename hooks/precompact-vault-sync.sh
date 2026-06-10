#!/usr/bin/env bash
# precompact-vault-sync.sh — PreCompact hook (rules/42 Phase 2 改善・案 A' 採用 2026-05-27)
#
# 目的: PreCompact 時に同 session の rules/42 対象編集を検出し、
#       Claude に /sync-vault-summary 起動 directive を context として注入する。
#
# Why PreCompact (Stop ではない):
# - 同一 session 内発火 → session_id 断絶なし (Codex 指摘の致命的欠陥 1 解消)
# - Claude の context が残っているうちに LLM 要約を生成できる
# - Stop hook stdout は次セッションに伝播しない (能動 capture 怠慢 drift 直撃)
# - 3-reviewer 合意 (Codex 敵対 + Builder + Scope Challenger) 2026-05-27
#
# 安全機構:
# - flag gate: ~/.claude/state/vault-cc-enabled 不在で完全休眠
# - 候補 0 件で何も出力しない (compact の context を汚さない)
set -u

INPUT=$(cat 2>/dev/null || true)

# flag check
[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

SESSION=$(echo "$INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except: print('')" 2>/dev/null)
[ -z "$SESSION" ] && exit 0

# edit-history.jsonl から同 session の rules/42 対象を抽出
# (stop-vault-summary-suggest.sh と同一 PAT・drift 防止)
CANDIDATES=$(python3 - "$SESSION" <<'PY'
import json, sys, re
from pathlib import Path
session = sys.argv[1]
log = Path.home() / ".claude/state/edit-history.jsonl"
PAT = re.compile(
    r"/(plan|measures-detail|measure-impact-table|spec|analysis|"
    r"data-sources|data_lineage|schema-|glossary|README|CLAUDE|"
    r"SECURITY|setup-runbook|rationales/).*\.(md|ya?ml)$"
    r"|/tasks/phase-tracker\.md$"
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
for f, ts in sorted(seen.items(), key=lambda x: x[1])[-10:]:
    print(f)
PY
)

[ -z "$CANDIDATES" ] && exit 0

COUNT=$(echo "$CANDIDATES" | wc -l | tr -d ' ')

# stdout に directive を出力 (PreCompact stdout は Claude の context として認識される)
echo ""
echo "=== 📝 VAULT_SYNC_REQUIRED (PreCompact directive) ==="
echo ""
echo "本セッションで rules/42 対象 ${COUNT} 件が編集されました。context 圧縮前に vault MOC への要約 append を完了してください。"
echo ""
echo "**次のアクション (必須・最優先)**:"
echo "1. \`/sync-vault-summary\` を起動"
echo "2. 各候補について Read + git diff → 1-3 行要約生成 → MOC \`## 🔁 最新更新ログ\` に prepend"
echo ""
echo "**候補ファイル**:"
echo "$CANDIDATES" | sed 's|^|- |'
echo ""
echo "(不要なら \`~/.claude/state/vault-cc-enabled\` flag を rm すると hook 完全停止)"
exit 0
