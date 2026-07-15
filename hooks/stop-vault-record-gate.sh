#!/usr/bin/env bash
# stop-vault-record-gate.sh — Stop hook（warn-only 試験導入 2026-07-15）
#
# 目的: 「repo 側の分析成果物 (reports/metrics/findings) に書いたのに、vault へ一切
#       記録しないままセッションが終わる」を検知して想起を促す（診断 2026-07-15:
#       ルール不履行の真因①=保存ゲート不在。Fable5+Codex 敵対レビューの生存形）。
#
# 設計（敵対レビューの縮小条件を遵守）:
# - block しない（systemMessage のみ・stop-evidence-footer.sh には相乗りしない=Tier連鎖回避）
# - 1 セッション 1 回（state で自己制限）/ stop_hook_active 即 exit / headless(runner) 除外
# - 判定はキーワードでなく edit-history.jsonl の実績ベース（stop-vault-summary-suggest 転用）
# - fail-open: いかなるエラーでも exit 0
# - 試験: 発火を state/vault-record-gate.log に記録。2 週間の誤検知率で block 昇格を判断
#   （昇格判断の期日 = 2026-07-29・判断材料はこのログ）
set -u

INPUT=$(cat 2>/dev/null || true)

# headless / 定期 runner は対象外
[ -n "${VAULT_PROMPT_RUNNER:-}" ] && exit 0

# 再入防止
STOP_ACTIVE=$(echo "$INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('stop_hook_active',False))
except: print('False')" 2>/dev/null)
[ "$STOP_ACTIVE" = "True" ] && exit 0

SESSION=$(echo "$INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except: print('')" 2>/dev/null)
[ -z "$SESSION" ] && exit 0

# 1 セッション 1 回
STATE_DIR="$HOME/.claude/state"
NOTIFIED="$STATE_DIR/vault-record-gate.notified"
if [ -f "$NOTIFIED" ] && grep -qF "$SESSION" "$NOTIFIED" 2>/dev/null; then
  exit 0
fi

# 実績ベース判定: repo 分析成果物への Write/Edit あり ∧ vault への Write/Edit ゼロ
EDIT_LOG="${VAULT_RECORD_GATE_EDITLOG:-$STATE_DIR/edit-history.jsonl}"
VERDICT=$(python3 - "$SESSION" "$EDIT_LOG" <<'PY'
import json, sys, re
from pathlib import Path
session, log = sys.argv[1], Path(sys.argv[2])
# repo 側の「分析成果物」: reports/ metrics/ tasks/findings/ 配下の md/csv
REPO_PAT = re.compile(r"/(reports|metrics|tasks/findings)/[^ ]*\.(md|csv)$")
VAULT_PAT = re.compile(r"/Obsidian Vault/")
repo_hits, vault_hits = [], 0
if log.exists():
    for line in log.read_text().splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("session") != session:
            continue
        f = d.get("file", "")
        if VAULT_PAT.search(f):
            vault_hits += 1
        elif REPO_PAT.search(f):
            repo_hits.append(f)
if repo_hits and vault_hits == 0:
    print("FIRE\t" + str(len(repo_hits)) + "\t" + repo_hits[-1])
else:
    print("PASS")
PY
) || exit 0

case "$VERDICT" in
  FIRE*)
    n=$(printf '%s' "$VERDICT" | cut -f2)
    sample=$(printf '%s' "$VERDICT" | cut -f3)
    # 試験ログ（block 昇格判断の材料・2026-07-29 に評価）
    printf '%s\t%s\tfired\trepo_writes=%s\tsample=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$n" "$sample" \
      >> "$STATE_DIR/vault-record-gate.log" 2>/dev/null
    echo "$SESSION" >> "$NOTIFIED" 2>/dev/null
    # block しない・ユーザー/AI への想起のみ
    printf '{"systemMessage": "📌 vault 未記録の可能性: このセッションは repo の分析成果物 %s 件に書きましたが vault への記録が 0 です。ユーザーが見る成果なら research 台帳へ 1 行 or reports/ へ清書を（不要なら無視して OK・warn 試験中 2026-07-29 まで）"}\n' "$n"
    ;;
esac

exit 0
