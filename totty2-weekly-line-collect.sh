#!/bin/bash
# totty2 週次 LINE トーク履歴 増分収集 (TCC-safe / docker run 方式)
#
# ★なぜ ~/.claude に置くか: repo は ~/Desktop 配下(macOS TCC 保護領域)にあり、launchd から起動した
#   /bin/bash は Desktop 配下のファイルを読めない(rohan-weekly-collect.sh と同じ教訓)。そこで
#   スクリプト本体は非TCC領域(~/.claude)に置き、Desktop へのファイルアクセスは全て Docker daemon
#   (ファイル共有許可済み)にやらせる: `docker run -v <repo>:/work` はパス文字列を渡すだけで
#   bash 自身は Desktop を読まない。ログも ~/.claude/state 配下(非TCC)に出す。
#
# 仕組み:
#   ① 日付窓の増分取得: 前回成功時の終了日(state)〜昨日 を --start-date/--end-date で取得
#      (index は requestId で union マージ・取得済みセッションは checkpoint で自動スキップ・
#       consult-log は全ページ取得・完了後 conversations.jsonl 再生成)
#   ② 自己修復: --refill-pages でページ欠落(取得時に会話が進行中だった等)を再走査
#   失敗時(JWT失効等)は gog gmail で通知し、state を更新しない(翌週同じ窓で再試行)。
#
# 正本ドキュメント: <repo>/tasks/counsel-mvp.md / メモリ: line-talkstudio-export.md
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="/Users/masaaki/Desktop/prm/totty2"   # bash からは触らない(docker への文字列引数のみ)
IMAGE="python:3.11-slim"                    # ツールは標準ライブラリのみ・3.10+ 必須(str|None 注釈)
NOTIFY_TO="masaaki@mkb.ne.jp"
STATEDIR="$HOME/.claude/state/totty2-weekly"
mkdir -p "$STATEDIR"
LOG="$STATEDIR/weekly_$(date +%Y%m%d_%H%M%S).log"
exec >>"$LOG" 2>&1

echo "=== totty2 weekly line collect start $(date) ==="
command -v docker >/dev/null || { echo "FATAL: docker not found in PATH"; exit 127; }
docker info >/dev/null 2>&1 || { echo "docker daemon not running — skip(来週再試行)"; exit 0; }

# 二重起動ガード: ホスト直走行の export/chain(大規模バックフィル等) と衝突させない
if pgrep -f "line_api_export.py" >/dev/null || pgrep -f "chain_backfill.sh" >/dev/null; then
  echo "別の export がホストで走行中 — skip(来週再試行)"
  echo "=== end (skipped) $(date) ==="
  exit 0
fi
# 前回の週次コンテナが残っていないか(名前ベース・Desktop 不参照)
if docker ps --format '{{.Names}}' | grep -q '^totty2-weekly-collect$'; then
  echo "前回の週次コンテナが稼働中 — skip"
  echo "=== end (skipped) $(date) ==="
  exit 0
fi

# 取得窓: 前回成功の終了日(初期値=バックフィル網羅済みの 2026-06-18)〜昨日
#   昨日までにすることで「取得時点でまだ進行中の会話」を掴まない(境界日は翌週の窓と重なるが
#   requestId 重複は index マージ+checkpoint で無害)
START=$(cat "$STATEDIR/.last_end" 2>/dev/null || echo "2026-06-18")
END=$(date -v-1d +%Y-%m-%d)
echo "window: $START .. $END"
if [ "$START" = "$END" ]; then
  echo "窓が空(前回と同日) — skip"
  echo "=== end $(date) ==="
  exit 0
fi

run_tool() {
  docker run --rm --name totty2-weekly-collect \
    -v "$REPO":/work -w /work "$IMAGE" \
    python3 backend/tools/line_api_export.py "$@"
}

# ① 日付窓の増分取得(gentle 既定ペース 5〜15秒間隔・全ページ取得)
run_tool --start-date "$START" --end-date "$END"
RC=$?
echo "window fetch rc=$RC"

OK=0
if [ "$RC" -eq 0 ] && grep -q "✅ consult-log" "$LOG"; then
  OK=1
  echo "$END" > "$STATEDIR/.last_end"
  # ② 自己修復パス: ページ欠落(totalElements > 保存数)を再走査・再取得
  run_tool --refill-pages
  echo "refill rc=$?"
fi

if [ "$OK" -ne 1 ]; then
  SUB="[totty2] 週次LINE収集 失敗 (window $START..$END rc=$RC)"
  BODY="週次のLINEトーク履歴収集が失敗しました。JWT失効の可能性が高いです。Cookie-Editor で fortune-manager.line.me の Cookie を再エクスポート(.secrets/line_cookies.json)して、次セッションで Claude に『週次LINE収集を再実行して』と伝えてください。state は未更新のため翌週も同じ窓で再試行します。ログ: $LOG"
  if command -v gog >/dev/null && gog gmail send --to "$NOTIFY_TO" --subject "$SUB" --body "$BODY" --force 2>&1; then
    echo "notify email sent"
  else
    echo "WARN: notify email failed"
  fi
fi

echo "=== totty2 weekly line collect end $(date) ==="
