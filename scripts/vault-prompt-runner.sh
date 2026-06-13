#!/bin/bash
# vault-prompt-runner.sh — 1 つの vault プロンプトファイルを headless `claude -p` に渡し、
# 出力テキストを <group>/reports/<slug>-result-YYYY-MM-DD.md として書き戻す。
#
# 使い方:
#   vault-prompt-runner.sh <prompt-file.md> [out-slug] [work-dir]
#     <prompt-file.md> : 実行するプロンプト (例 .../prompts/adscrm-weekly-ops-review.md)
#     [out-slug]       : レポート名 slug (省略時 = プロンプト basename)
#     [work-dir]       : claude の作業ディレクトリ (省略時 = frontmatter runner_workdir または $HOME)
#
# 設計 (2026-06-13・案1 launchd + bash -lc + claude -p):
#   - claude には READ-ONLY ツールのみ許可 (Read/Grep/Glob/WebSearch)。Write/Bash は渡さない。
#     レポートのファイル書き込みは本 wrapper が担当する (headless claude に書込権限を与えない)。
#   - settings.json の permissions.deny は headless でも有効 (多層防御)。
#   - launchd は最小 PATH なので nvm の claude を明示。secrets が要る場合は plist が /bin/bash -lc で起動。
#   - 出力先は <group>/reports/ (rules/41 §③ / rules/42・2026-06-13 K-3 解体後)。
#
# プロンプト frontmatter で上書き可能なキー (任意):
#   runner_tools:   "Read Grep Glob WebSearch"        # 許可ツール (空白区切り)
#   runner_workdir: "/Users/.../Desktop/prm/prime_suite/prime_ad"  # データ参照用 cwd
#   runner_out_dir: "/Users/.../02_Ai/AI_adscrm/reports"           # 出力先
#   runner_model:   "claude-opus-4-8"                 # モデル上書き
set -uo pipefail

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "usage: vault-prompt-runner.sh <prompt-file.md> [out-slug] [work-dir]" >&2
  echo "  (prompt file not found: '$PROMPT_FILE')" >&2
  exit 2
fi

# nvm の claude を明示 (launchd 最小 PATH 対策)
NODE_BIN="$HOME/.nvm/versions/node/v22.18.0/bin"
export PATH="$NODE_BIN:$PATH"
CLAUDE_BIN="$(command -v claude || echo "$NODE_BIN/claude")"

STATE_DIR="$HOME/.claude/state"
LOG="$STATE_DIR/vault-prompt-runner.log"
mkdir -p "$STATE_DIR"

# --- frontmatter からオプション抽出 (--- ... --- の最初のブロックのみ) ---
fm_get() {
  awk -v key="$1" '
    /^---$/{c++; if(c==2) exit; next}
    c==1 && $0 ~ "^"key":" { sub("^"key":[ \t]*",""); gsub(/^"|"$/,""); print; exit }
  ' "$PROMPT_FILE" 2>/dev/null
}

SLUG="${2:-$(basename "$PROMPT_FILE" .md)}"
TOOLS="$(fm_get runner_tools)";   TOOLS="${TOOLS:-Read Grep Glob WebSearch}"
WORKDIR="${3:-$(fm_get runner_workdir)}"; WORKDIR="${WORKDIR:-$HOME}"
OUT_DIR="$(fm_get runner_out_dir)"; OUT_DIR="${OUT_DIR:-$HOME/Documents/Obsidian Vault/02_Ai/AI_adscrm/reports}"
MODEL="$(fm_get runner_model)"

DATE="$(date +%Y-%m-%d)"
TS="$(date -Iseconds)"
OUT_MD="$OUT_DIR/${SLUG}-result-${DATE}.md"
mkdir -p "$OUT_DIR"

[ -d "$WORKDIR" ] || WORKDIR="$HOME"

MODEL_ARGS=()
[ -n "$MODEL" ] && MODEL_ARGS=(--model "$MODEL")

{
  echo "=== [$TS] vault-prompt-runner start ==="
  echo "    prompt=$PROMPT_FILE slug=$SLUG workdir=$WORKDIR tools=[$TOOLS] -> $OUT_MD"
} >> "$LOG"

# --- headless 実行: プロンプト本文を stdin で渡し、テキスト出力を取得 ---
# shellcheck disable=SC2086
RESULT="$(cd "$WORKDIR" && claude -p \
  --output-format text \
  --allowedTools $TOOLS \
  --add-dir "$WORKDIR" \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  < "$PROMPT_FILE" 2>>"$LOG")"
RC=$?

if [ $RC -ne 0 ] || [ -z "$RESULT" ]; then
  echo "=== [$(date -Iseconds)] FAILED rc=$RC (result empty=$([ -z "$RESULT" ] && echo yes || echo no)) ===" >> "$LOG"
  exit 1
fi

# --- レポート書き戻し (wrapper が書く・claude には Write 不要) ---
{
  echo "---"
  echo "project: prime_ad"
  echo "type: analysis"
  echo 'folder: "02_Ai/AI_adscrm/reports/"'
  echo "categories:"
  echo '  - "[[AIads_ope]]"'
  echo "source_prompt: \"${PROMPT_FILE/#$HOME/~}\""
  echo "generated_at: $DATE"
  echo "last_updated: $DATE"
  echo "tags:"
  echo "  - project/prime_ad"
  echo "  - type/analysis"
  echo "  - auto-generated"
  echo "---"
  echo ""
  echo "# $SLUG — $DATE (auto: vault-prompt-runner)"
  echo ""
  echo "> 元プロンプト: \`${PROMPT_FILE/#$HOME/~}\` / 実行: headless \`claude -p\` / tools: $TOOLS / workdir: \`${WORKDIR/#$HOME/~}\`"
  echo "> ⚠️ 自動生成。人間レビュー前提（数値は repo 一次ソースで要確認）。"
  echo ""
  printf '%s\n' "$RESULT"
} > "$OUT_MD"

echo "=== [$(date -Iseconds)] OK -> $OUT_MD ($(wc -l < "$OUT_MD") lines) ===" >> "$LOG"
echo "$OUT_MD"
exit 0
