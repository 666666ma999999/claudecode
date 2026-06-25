#!/bin/bash
# vault-spot-runner.sh — スポット(1回きり)プロンプトを実行し、終わったら done/ へ移すだけのシンプル版。
#
# 流れ: 書く(prompts/spot/<name>.md) → 実行 → 結果(reports/) → プロンプトを spot/done/ へ移動
#   1. vault-prompt-runner.sh に委譲して headless 実行 → reports/<slug>-result-YYYY-MM-DD.md
#   2. 実行済みプロンプトを <spot>/done/ へ移動 (= 完了の印。元プロンプトはこのファイルがそのまま残る)
#
# 設計方針 (2026-06-15 ユーザー指示で簡素化):
#   スポットは「1 ファイルで充分・終わったら done へ移すだけ」。
#   refs/ への複製や NOW.md ## Done への行追記はしない (台帳化は /done の手動フローに任せる)。
#
# 定期プロンプトには使わない:
#   定期 = launchd + vault-prompt-runner.sh を直接呼ぶ (繰り返すレポート・done なし)。
#   スポット = 本スクリプト (1 回きり・実行後 done/ へ)。
#
# 使い方:
#   vault-spot-runner.sh <spot-prompt.md>
set -uo pipefail

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "usage: vault-spot-runner.sh <spot-prompt.md>" >&2
  echo "  (prompt file not found: '$PROMPT_FILE')" >&2
  exit 2
fi

RUNNER="$HOME/.claude/scripts/vault-prompt-runner.sh"
if [ ! -x "$RUNNER" ]; then
  echo "vault-prompt-runner.sh not found/executable: $RUNNER" >&2
  exit 2
fi

STATE_DIR="$HOME/.claude/state"
LOG="$STATE_DIR/vault-spot-runner.log"
mkdir -p "$STATE_DIR"

SLUG="$(basename "$PROMPT_FILE" .md)"
DATE="$(date +%Y-%m-%d)"
echo "=== [$(date -Iseconds)] spot-runner start: $PROMPT_FILE (slug=$SLUG) ===" >> "$LOG"

# --- 1. headless 実行 (委譲・stdout の最終行 = 出力 md パス) ---
OUT_MD="$("$RUNNER" "$PROMPT_FILE" 2>>"$LOG")"
RC=$?
if [ $RC -ne 0 ] || [ -z "$OUT_MD" ] || [ ! -f "$OUT_MD" ]; then
  echo "=== [$(date -Iseconds)] FAILED rc=$RC out='$OUT_MD' (プロンプトは移動しない) ===" >> "$LOG"
  echo "spot-runner: 実行に失敗 (rc=$RC)。$LOG を確認。プロンプトはそのまま (done へ移さない)。" >&2
  exit 1
fi

# --- 2. 実行済みプロンプトを done/ へ移動 (= 完了の印) ---
SPOT_DIR="$(cd "$(dirname "$PROMPT_FILE")" && pwd)"
DONE_DIR="$SPOT_DIR/done"
mkdir -p "$DONE_DIR"
DONE_DEST="$DONE_DIR/$(basename "$PROMPT_FILE")"
[ -e "$DONE_DEST" ] && DONE_DEST="$DONE_DIR/${SLUG}-${DATE}.md"   # 同名衝突時は日付サフィックス
mv "$PROMPT_FILE" "$DONE_DEST"

echo "=== [$(date -Iseconds)] OK slug=$SLUG result=$OUT_MD done=$DONE_DEST ===" >> "$LOG"

# 人間向けサマリ (stdout)
echo "✅ spot 実行完了: $SLUG"
echo "   結果 : $OUT_MD"
echo "   done : $DONE_DEST （プロンプトをここへ移動）"
exit 0
