#!/bin/bash
# vault-spot-runner.sh — 単発(1回きり)プロンプトを headless 実行し、結果を reports/ に書き、
# 実行記録を <project>/prompts/_INBOX.md の `## 📒 記録` セクションへ「全文＋いつ＋なぜ＋結果」で追記する。
#
# 新モデル (2026-06-26・wiki/meta/decisions.md):
#   旧版の「実行済みプロンプトを spot/done/ へ移動」は廃止。spot/ 別ファイルは作らない。
#   実行したプロンプトは全文＋実行メタを _INBOX.md の記録セクションに残す(消さない=IP遺産)。
#
# 流れ: <prompt.md> → vault-prompt-runner.sh で headless 実行 → reports/<slug>-result-YYYY-MM-DD.md
#        → _INBOX.md `## 📒 記録` の先頭(既存エントリの上)へ記録エントリ(全文)を追記。
#
# 記録先 _INBOX の決定順:
#   1. prompt frontmatter の `record_inbox: <path>` があればそれ。
#   2. 無ければ結果MD(reports/)の親ディレクトリ隣の `prompts/_INBOX.md` を自動導出。
#   3. それでも見つからなければ記録はスキップ(結果は reports/ に残る・警告を出す)。
#
# 任意 frontmatter: `purpose: <この実行の目的>`（無ければ本文の最初の `# 見出し`、それも無ければ「(目的未記入)」）。
#
# 使い方: vault-spot-runner.sh <prompt.md>
# テスト用: SPOT_RUNNER_DELEGATE=<stub> で委譲先(vault-prompt-runner.sh)を差し替え可能。
set -uo pipefail

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "usage: vault-spot-runner.sh <prompt.md>" >&2
  echo "  (prompt file not found: '$PROMPT_FILE')" >&2
  exit 2
fi

RUNNER="${SPOT_RUNNER_DELEGATE:-$HOME/.claude/scripts/vault-prompt-runner.sh}"
if [ ! -x "$RUNNER" ]; then
  echo "delegate runner not found/executable: $RUNNER" >&2
  exit 2
fi

STATE_DIR="$HOME/.claude/state"
LOG="$STATE_DIR/vault-spot-runner.log"
mkdir -p "$STATE_DIR"

# --- frontmatter getter (最初の --- ... --- ブロックのみ) ---
fm_get() {
  awk -v key="$1" '
    /^---$/{c++; if(c==2) exit; next}
    c==1 && $0 ~ "^"key":" { sub("^"key":[ \t]*",""); gsub(/^"|"$/,""); print; exit }
  ' "$PROMPT_FILE" 2>/dev/null
}

SLUG="$(basename "$PROMPT_FILE" .md)"
DATE="$(date +%Y-%m-%d)"
echo "=== [$(date -Iseconds)] spot-runner start: $PROMPT_FILE (slug=$SLUG) ===" >> "$LOG"

# --- 1. headless 実行 (委譲・stdout 最終行 = 出力 md パス) ---
OUT_MD="$("$RUNNER" "$PROMPT_FILE" 2>>"$LOG")"
RC=$?
if [ $RC -ne 0 ] || [ -z "$OUT_MD" ] || [ ! -f "$OUT_MD" ]; then
  echo "=== [$(date -Iseconds)] FAILED rc=$RC out='$OUT_MD' (記録しない) ===" >> "$LOG"
  echo "spot-runner: 実行に失敗 (rc=$RC)。$LOG を確認。記録は追記しない。" >&2
  exit 1
fi

# --- 2. 記録先 _INBOX.md を決定 ---
INBOX="$(fm_get record_inbox)"
if [ -z "$INBOX" ]; then
  REPORTS_DIR="$(cd "$(dirname "$OUT_MD")" && pwd)"
  CAND="$(dirname "$REPORTS_DIR")/prompts/_INBOX.md"
  [ -f "$CAND" ] && INBOX="$CAND"
fi

OUT_BASE="$(basename "$OUT_MD" .md)"      # wikilink 用 (拡張子なし)
PURPOSE="$(fm_get purpose)"
[ -z "$PURPOSE" ] && PURPOSE="$(awk '/^# /{sub(/^# +/,""); print; exit}' "$PROMPT_FILE")"
[ -z "$PURPOSE" ] && PURPOSE="(目的未記入)"

# プロンプト本文 (先頭が --- の時のみ frontmatter を除去・本文中の --- 罫線は保持) + 先頭空行トリム
BODY_FILE="$(mktemp)"
awk 'NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=2; next} fm!=1{print}' "$PROMPT_FILE" \
  | sed '/./,$!d' > "$BODY_FILE"

if [ -z "$INBOX" ] || [ ! -f "$INBOX" ]; then
  echo "=== [$(date -Iseconds)] OK(記録先 _INBOX 不明) slug=$SLUG result=$OUT_MD ===" >> "$LOG"
  echo "✅ spot 実行完了: $SLUG"
  echo "   結果 : $OUT_MD"
  echo "   ⚠️ 記録先 _INBOX.md が見つからず記録を追記できませんでした (frontmatter record_inbox を指定してください)。"
  rm -f "$BODY_FILE"
  exit 0
fi

# --- 3. 記録エントリを組み立て ---
ENTRY_FILE="$(mktemp)"
{
  echo "### ${DATE} ｜ ${SLUG}"
  echo "- **いつ / 種別**: ${DATE} ・ 単発（spot-runner・headless）"
  echo "- **目的（なぜ）**: ${PURPOSE}"
  echo "- **結果**: [[${OUT_BASE}]]"
  echo ""
  echo '```prompt'
  cat "$BODY_FILE"
  echo '```'
  echo ""
} > "$ENTRY_FILE"
rm -f "$BODY_FILE"

# --- 4. `## 📒 記録` セクション先頭(既存 ### の直前 / 無ければ <details> or --- / 末尾)へ挿入 ---
INS_LINE="$(awk '/^## 📒 記録/{f=1; next} f && /^### /{print NR; exit} f && (/^<details>/||/^---$/){print NR; exit}' "$INBOX")"
TMP_OUT="$(mktemp)"
if [ -n "$INS_LINE" ]; then
  head -n "$((INS_LINE-1))" "$INBOX" > "$TMP_OUT"
  cat "$ENTRY_FILE" >> "$TMP_OUT"
  tail -n "+${INS_LINE}" "$INBOX" >> "$TMP_OUT"
else
  cat "$INBOX" > "$TMP_OUT"
  printf '\n## 📒 記録（実行したプロンプト・消さない／新しいものを上に積む）\n\n' >> "$TMP_OUT"
  cat "$ENTRY_FILE" >> "$TMP_OUT"
fi
mv "$TMP_OUT" "$INBOX"
rm -f "$ENTRY_FILE"

echo "=== [$(date -Iseconds)] OK slug=$SLUG result=$OUT_MD recorded-> $INBOX ===" >> "$LOG"
echo "✅ spot 実行完了: $SLUG"
echo "   結果 : $OUT_MD"
echo "   記録 : $INBOX の ## 📒 記録 に全文追記（消さない）"
exit 0
