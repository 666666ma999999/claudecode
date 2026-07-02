#!/usr/bin/env bash
# collect-reply-posts: 今週分の X advanced search URL を生成する。
# reply（返信）が多い親投稿だけを直接絞り込む `min_replies:` クエリを、
# AI / Claude Code の論点別・日英別に出力する。
# 使い方: bash ~/.claude/skills/collect-reply-posts/gen-queries.sh
# 出力された URL を「ログイン済みブラウザ」で開き、reply の多い親投稿を目視で拾う。
#
# このクエリ群は自己改善ループ（references/refine-loop.md）で運用改善する恒久資産。
# 変更は analyze-feedback.py の採用率を根拠に、人間承認した上で下記 CHANGELOG に1行残す。
#
# CHANGELOG（新しい変更を上に・日付 / 変更 / 根拠採用率）:
#   2026-06-19  初版（6クエリ: JA×3 / EN×3）。運用データなし・採用率は未測定。

set -euo pipefail

# ---- 調整ポイント（ノイズ/件数を見て手で変える）----
SINCE_DAYS=7          # 直近何日ぶんを探すか（少なければ伸ばす）
MIN_REPLIES_JA=10     # 日本語: reply 下限（少なければ下げる / ノイズ多ければ上げる）
MIN_REPLIES_EN=25     # 英語: 母数が多いので高め
MIN_REPLIES_HOT=8     # 賛否が割れる系: やや低め
# MIN_FAVES=20        # bot/無風投稿を切りたい時は各クエリ末尾に " min_faves:${MIN_FAVES}" を足す
# WATCHLIST="(from:user1 OR from:user2)"  # 特定アカウント限定版を使う時に編集
# ----------------------------------------------------

# since 日付（macOS BSD date / Linux GNU date 両対応）
if SINCE=$(date -v-"${SINCE_DAYS}"d +%Y-%m-%d 2>/dev/null); then :; else
  SINCE=$(date -d "${SINCE_DAYS} days ago" +%Y-%m-%d)
fi

# 純 bash URL エンコード（依存なし）
# LC_ALL=C でバイト単位に処理し、マルチバイト(UTF-8)を正しく %XX 列にする。
urlencode() {
  local LC_ALL=C
  local s="$1" out="" i c hex
  for ((i=0; i<${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v hex '%02X' "'$c"; out+="%${hex: -2}" ;;  # 末尾2桁=符号拡張対策
    esac
  done
  printf '%s' "$out"
}

emit() {
  # $1 = ラベル, $2 = 検索クエリ（since は自動付与）
  local label="$1" q="$2 since:${SINCE}"
  printf '\n# %s\n#   q: %s\n' "$label" "$q"
  printf 'https://x.com/search?q=%s&src=typed_query&f=live\n' "$(urlencode "$q")"
}

COMMON="-filter:replies -filter:retweets"

echo "==== collect-reply-posts: $(date +%Y-%m-%d) 生成 / since:${SINCE} ===="
echo "# 各 URL をログイン済みブラウザで開き、reply の多い親投稿を目視で拾う"

emit "JA / Claude Code・AIエージェント中心の議論" \
  "(\"Claude Code\" OR Claude OR MCP OR Cursor OR Anthropic OR \"AIエージェント\" OR LLM) min_replies:${MIN_REPLIES_JA} ${COMMON} lang:ja"

emit "JA / 生成AI全般で会話が起きている投稿" \
  "(生成AI OR \"AI活用\" OR ChatGPT OR Gemini OR Copilot) min_replies:${MIN_REPLIES_JA} ${COMMON} lang:ja"

emit "JA / 賛否が割れている・物議系（reply 誘発語）" \
  "(AI OR LLM OR \"Claude Code\") (賛否 OR 物議 OR \"正直\" OR \"異論\" OR \"これ違う\") min_replies:${MIN_REPLIES_HOT} ${COMMON} lang:ja"

emit "EN / Claude Code・Anthropic・MCP の議論" \
  "(\"Claude Code\" OR Anthropic OR MCP OR \"AI agent\") min_replies:${MIN_REPLIES_EN} ${COMMON} lang:en"

emit "EN / AI coding tools 比較・論争" \
  "(Cursor OR Copilot OR \"Claude Code\" OR Codex OR Windsurf) min_replies:${MIN_REPLIES_EN} ${COMMON} lang:en"

emit "EN / hot take / unpopular opinion 系（議論誘発）" \
  "(AI OR LLM OR agents) (\"hot take\" OR \"unpopular opinion\" OR \"controversial\" OR \"actually\") min_replies:${MIN_REPLIES_HOT} ${COMMON} lang:en"

# 特定アカウント限定版を使いたい時は WATCHLIST を編集して以下を有効化:
# emit "Watchlist 限定 / reply の多い投稿" \
#   "${WATCHLIST} min_replies:${MIN_REPLIES_HOT} ${COMMON}"

echo
echo "# 件数が少ない→ MIN_REPLIES_* を下げる / SINCE_DAYS を伸ばす"
echo "# ノイズが多い→ MIN_REPLIES_* を上げる / min_faves 行を有効化する"
