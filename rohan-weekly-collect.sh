#!/bin/bash
# 週次 collect (TCC-safe 版) — rohan before/after 学習コーパスの human_after 再収集 + diff 生成、
#   diff ペアが閾値(30=初回精査/120=本格精査)到達でメール自動通知。
#
# ★なぜ ~/.claude に置くか: repo は ~/Desktop 配下(macOS TCC 保護領域)にあり、launchd から起動した
#   /bin/bash は Desktop 配下のファイルを読めない(Operation not permitted / exit 126)。そこで
#   スクリプト本体は非TCC領域(~/.claude)に置き、Desktop を bash で直接触らない設計にする:
#     - collect は `docker exec <コンテナ名>` で実行(compose ファイルを読まない=Desktop 不参照)。
#       corpus データはコンテナがマウント経由で書く(Docker Desktop のファイル共有=別途許可済)。
#     - ログは ~/.claude/state 配下(非TCC)に出す。
#   注: corpus の git commit/push は launchd(TCC)から Desktop を触れないため本ジョブでは行わない。
#       データはディスクに蓄積される。版管理は手動 or Claude 関与時(通知を受けた次セッション)に実施。
# 設計: <repo>/tasks/p-2026-06-27-correction-learning-system.md / owner: services.teacher_corpus
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CONTAINER="rohan-backend-1"
NOTIFY_TO="masaaki@mkb.ne.jp"
LOGDIR="$HOME/.claude/state/rohan-weekly"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/weekly_collect_$(date +%Y%m%d_%H%M%S).log"
exec >>"$LOG" 2>&1

echo "=== weekly_collect start $(date) ==="
command -v docker >/dev/null || { echo "FATAL: docker not found in PATH"; exit 127; }

# backend コンテナ稼働確認(名前ベース・compose 不要=Desktop 不参照)
if ! docker ps --filter "name=^${CONTAINER}$" --filter "status=running" --format '{{.Names}}' | grep -q "$CONTAINER"; then
  echo "backend container ($CONTAINER) not running — skip"
  echo "=== weekly_collect end (skipped) $(date) ==="
  exit 0
fi

# human_after 再収集 + (ai_after があれば)diff。PAIRS 数を通知判定に使う
OUT=$(docker exec -i "$CONTAINER" python -c \
  "import asyncio,json; from services.teacher_corpus import collect, corpus_report; \
print('COLLECT:', json.dumps(asyncio.run(collect(build_diffs=True)), ensure_ascii=False)); \
r=corpus_report(); print('PAIRS:%d' % r['pairs']); print('STATS:', json.dumps(r.get('edit_size_stats'), ensure_ascii=False))")
RC=$?
printf '%s\n' "$OUT"
echo "collect rc=$RC"
PAIRS=$(printf '%s\n' "$OUT" | grep -oE 'PAIRS:[0-9]+' | head -1 | cut -d: -f2)
PAIRS=${PAIRS:-0}
echo "pairs=$PAIRS"

# 精査時期の自動通知(忘れ対策) — 閾値ごと1回・メール成功時のみ state 更新(失敗は翌週再試行)
NOTIFY_STATE="$LOGDIR/.notified_pairs"
NOTIFIED=$(cat "$NOTIFY_STATE" 2>/dev/null || echo 0)
TARGET=0
for TH in 30 120; do
  if [ "${PAIRS:-0}" -ge "$TH" ] && [ "$NOTIFIED" -lt "$TH" ]; then TARGET=$TH; fi
done
if [ "$TARGET" -gt 0 ]; then
  if [ "$TARGET" -ge 120 ]; then MILE="本格精査"; else MILE="初回精査"; fi
  SUB="[rohan] 校正学習 diff ${PAIRS}件 到達（${MILE}・閾値${TARGET}）"
  BODY="diff ペアが ${PAIRS} 件たまりました（${MILE}の目安 ${TARGET} 到達）。精査するには次セッションで Claude に『correction-learning の Phase C/D を回して』と伝えてください。正本: tasks/p-2026-06-27-correction-learning-system.md"
  if command -v gog >/dev/null && gog gmail send --to "$NOTIFY_TO" --subject "$SUB" --body "$BODY" --force 2>&1; then
    echo "notify email sent (th=$TARGET pairs=$PAIRS)"
    echo "$TARGET" > "$NOTIFY_STATE"
  else
    echo "WARN: notify email failed (state未更新=翌週再試行)"
  fi
fi

echo "=== weekly_collect end $(date) ==="
