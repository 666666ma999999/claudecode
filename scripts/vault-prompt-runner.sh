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
#   runner_out_dir: "/Users/.../02_Ai/AI_adscrm/AIads/reports"           # 出力先
#   runner_model:   "claude-opus-4-8"                 # モデル上書き
#   runner_out_mode: "overwrite"        # 出力命名: dated(既定)=…-result-YYYY-MM-DD.md 累積 / overwrite=…-result.md 固定名で毎回上書き(履歴は git)
#   runner_project: "prime_ad"          # 出力 frontmatter の project / tag (全プロジェクト対応・既定 unknown)
#   runner_moc:     "AIads_ope"         # 出力の categories wikilink [[<MOC>]] (空なら categories 省略)
#   runner_folder:  "02_Ai/AI_adscrm/AIads/reports/"  # 出力 frontmatter の folder (空なら runner_out_dir から vault 相対で自動導出)
#   runner_extra_dir: "/Users/.../Documents/Obsidian Vault"  # 任意: WORKDIR 外の追加読取許可 (--add-dir 2本目・例 vault の公式ルールブック)
set -uo pipefail

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "usage: vault-prompt-runner.sh <prompt-file.md> [out-slug] [work-dir]" >&2
  echo "  (prompt file not found: '$PROMPT_FILE')" >&2
  exit 2
fi

# claude 実体を解決 (launchd 最小 PATH 対策 + nvm node バージョン変動に強く)
# 旧版は node バージョンをハードコード (v22.18.0) し、かつ実行は素の `claude` を呼んでいたため、
# claude/node の自動アップグレードでパスが変わると launchd 実行が rc=127
# 'claude: command not found' で落ちた (2026-06-22 実障害)。バージョン非依存で解決する。
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
[ -z "$CLAUDE_BIN" ] && CLAUDE_BIN="$(ls -t "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | head -1)"
[ -z "$CLAUDE_BIN" ] && CLAUDE_BIN="claude"
[ -x "$CLAUDE_BIN" ] && export PATH="$(dirname "$CLAUDE_BIN"):$PATH"

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
EXTRA_DIR="$(fm_get runner_extra_dir)"   # 任意: WORKDIR 外の追加読取許可 (例 vault の公式ルールブック)
OUT_DIR="$(fm_get runner_out_dir)"; OUT_DIR="${OUT_DIR:-$HOME/Documents/Obsidian Vault/02_Ai/AI_adscrm/AIads/reports}"
MODEL="$(fm_get runner_model)"
OUT_MODE="$(fm_get runner_out_mode)"; OUT_MODE="${OUT_MODE:-dated}"   # dated(既定・累積) | overwrite(固定名)

# --- 出力 identity (全プロジェクト対応・prime_ad ハードコード解消 2026-06-14) ---
PROJECT="$(fm_get runner_project)"; PROJECT="${PROJECT:-unknown-project}"
MOC="$(fm_get runner_moc)"; MOC="${MOC#\[\[}"; MOC="${MOC%\]\]}"   # [[X]] が来ても X に正規化
VAULT_ROOT="$HOME/Documents/Obsidian Vault"
FOLDER="$(fm_get runner_folder)"
if [ -z "$FOLDER" ]; then
  FOLDER="${OUT_DIR#"$VAULT_ROOT"/}"   # vault 相対へ (vault 外なら絶対のまま)
fi
case "$FOLDER" in */) ;; *) FOLDER="$FOLDER/" ;; esac   # 末尾スラッシュ保証

DATE="$(date +%Y-%m-%d)"
TS="$(date -Iseconds)"
# 出力命名: overwrite=固定名で毎回上書き(vault に最新1枚・履歴は git) / dated(既定)=日付付きで累積
if [ "$OUT_MODE" = "overwrite" ]; then
  OUT_MD="$OUT_DIR/${SLUG}-result.md"
else
  OUT_MD="$OUT_DIR/${SLUG}-result-${DATE}.md"
fi
mkdir -p "$OUT_DIR"

[ -d "$WORKDIR" ] || WORKDIR="$HOME"

MODEL_ARGS=()
[ -n "$MODEL" ] && MODEL_ARGS=(--model "$MODEL")

# runner_extra_dir があり実在ディレクトリなら 2 本目の --add-dir として渡す (vault 等 WORKDIR 外の読取)
EXTRA_DIR_ARGS=()
[ -n "$EXTRA_DIR" ] && [ -d "$EXTRA_DIR" ] && EXTRA_DIR_ARGS=(--add-dir "$EXTRA_DIR")

{
  echo "=== [$TS] vault-prompt-runner start ==="
  echo "    prompt=$PROMPT_FILE slug=$SLUG workdir=$WORKDIR tools=[$TOOLS] -> $OUT_MD"
} >> "$LOG"

# --- headless 実行: プロンプト本文を stdin で渡し、テキスト出力を取得 ---
# shellcheck disable=SC2086
RESULT="$(cd "$WORKDIR" && "$CLAUDE_BIN" -p \
  --output-format text \
  --allowedTools $TOOLS \
  --add-dir "$WORKDIR" \
  ${EXTRA_DIR_ARGS[@]+"${EXTRA_DIR_ARGS[@]}"} \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  < "$PROMPT_FILE" 2>>"$LOG")"
RC=$?

if [ $RC -ne 0 ] || [ -z "$RESULT" ]; then
  echo "=== [$(date -Iseconds)] FAILED rc=$RC (result empty=$([ -z "$RESULT" ] && echo yes || echo no)) ===" >> "$LOG"
  # bunshin v1 Phase 0 / T5 2026-07-02: 無人経路の silent 失敗を可視化 (6/22 rc=127 再発防止)
  osascript -e "display notification \"vault-prompt-runner FAILED rc=$RC ($SLUG)\" with title \"Claude 定期実行\"" 2>/dev/null || true
  exit 1
fi

# --- レポート書き戻し (wrapper が書く・claude には Write 不要) ---
{
  echo "---"
  echo "project: $PROJECT"
  echo "type: analysis"
  echo "folder: \"$FOLDER\""
  if [ -n "$MOC" ]; then
    echo "categories:"
    echo "  - \"[[$MOC]]\""
  fi
  echo "source_prompt: \"${PROMPT_FILE/#$HOME/~}\""
  echo "generated_at: $DATE"
  echo "last_updated: $DATE"
  echo "tags:"
  echo "  - project/$PROJECT"
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
