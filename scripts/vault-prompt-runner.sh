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

notify() {  # $1=message
  osascript -e "display notification \"$1\" with title \"Claude 定期実行\"" 2>/dev/null || true
}

# --- 読取自己診断 (✅1a fail-fast 2026-07-08) ---
# TCC 下では [ -f ] が通るのに read できない (stat 可・read 不可) — 7/7・7/8 の
# wiki-daily-ingest 実障害。読めない prompt で既定値のまま走らせない (silent fallback 廃止)。
if ! head -c1 "$PROMPT_FILE" >/dev/null 2>&1; then
  echo "=== [$(date -Iseconds)] FATAL prompt-unreadable (TCC?): $PROMPT_FILE ===" >> "$LOG"
  notify "🛑 FATAL: prompt読取不能(TCC?) $(basename "$PROMPT_FILE") — Full Disk Access を確認"
  exit 3
fi

# --- frontmatter からオプション抽出 (--- ... --- の最初のブロックのみ) ---
fm_get() {
  awk -v key="$1" '
    /^---$/{c++; if(c==2) exit; next}
    c==1 && $0 ~ "^"key":" { sub("^"key":[ \t]*",""); gsub(/^"|"$/,""); print; exit }
  ' "$PROMPT_FILE" 2>/dev/null
}

SLUG="${2:-$(basename "$PROMPT_FILE" .md)}"
TOOLS="$(fm_get runner_tools)";   TOOLS="${TOOLS:-Read Grep Glob WebSearch}"
WORKDIR="${3:-$(fm_get runner_workdir)}"
EXTRA_DIR="$(fm_get runner_extra_dir)"   # 任意: WORKDIR 外の追加読取許可 (例 vault の公式ルールブック)
OUT_DIR="$(fm_get runner_out_dir)"
# fail-fast (✅1a 2026-07-08): runner_out_dir 必須化・既定値フォールバック廃止。
# 旧: 未取得時に AIads/reports へ既定 → wiki ジョブの生成物が広告プロジェクトへ混入する
# 誤配置経路が実在した (7/7-7/8 runner log)。全 scheduled prompt は宣言済みを確認済み。
if [ -z "$OUT_DIR" ]; then
  echo "=== [$(date -Iseconds)] FATAL frontmatter-unreadable (runner_out_dir なし): $PROMPT_FILE ===" >> "$LOG"
  notify "🛑 FATAL: frontmatter解析不能 $(basename "$PROMPT_FILE") — runner_out_dir が読めません"
  exit 2
fi
# workdir も既定値フォールバック全廃 (Codex 4255acd レビュー指摘): 未宣言なら $HOME で走らず停止
if [ -z "$WORKDIR" ]; then
  echo "=== [$(date -Iseconds)] FATAL frontmatter-unreadable (runner_workdir なし): $PROMPT_FILE ===" >> "$LOG"
  notify "🛑 FATAL: runner_workdir 未宣言 $(basename "$PROMPT_FILE") — 既定値では実行しません"
  exit 2
fi
# ~ 展開 (2026-07-08): 2台Mac運用でユーザー名が違うため、prompt frontmatter は "~/..." で書き
# ここで実行機の $HOME に展開する (旧: 絶対パス直書き → 別Macで [ -d ] が落ち silent fallback)
WORKDIR="${WORKDIR/#\~/$HOME}"; EXTRA_DIR="${EXTRA_DIR/#\~/$HOME}"; OUT_DIR="${OUT_DIR/#\~/$HOME}"
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
# 出力先の作成・書込可能性も fail-fast (Codex 4255acd レビュー指摘: silent success 防止)
if ! mkdir -p "$OUT_DIR" 2>>"$LOG" || [ ! -w "$OUT_DIR" ]; then
  echo "=== [$(date -Iseconds)] FATAL out-dir-unwritable: $OUT_DIR ($PROMPT_FILE) ===" >> "$LOG"
  notify "🛑 FATAL: 出力先に書けません $(basename "$OUT_DIR") ($SLUG)"
  exit 2
fi

# fail-fast (✅1a 2026-07-08): 宣言された WORKDIR が実在しなければ $HOME で走らず停止。
# 旧: silent fallback → 別Macで誤った cwd のまま生成される事故経路だった。
if [ ! -d "$WORKDIR" ]; then
  echo "=== [$(date -Iseconds)] FATAL workdir-missing: $WORKDIR ($PROMPT_FILE) ===" >> "$LOG"
  notify "🛑 FATAL: workdir 不在 $(basename "$WORKDIR") ($SLUG) — このMacでは実行できません"
  exit 2
fi

# --- 手修正✍️検知 (✅1c 2026-07-08・Codex裁定: 毎回アーカイブでなく停止+通知) ---
# 前回書込完了時の hash と現物が違う = 人が手を入れた。無警告で上書きして消さない。
# 解除手順: 手修正を契約/ボードへ反映したら state/vault-runner-hashes/<name>.sha256 を削除。
HASH_DIR="$STATE_DIR/vault-runner-hashes"; mkdir -p "$HASH_DIR"
HASH_FILE="$HASH_DIR/$(basename "$OUT_MD").sha256"
if [ -f "$OUT_MD" ] && [ -f "$HASH_FILE" ]; then
  CUR_HASH="$(shasum -a 256 "$OUT_MD" 2>/dev/null | awk '{print $1}')"
  SAVED_HASH="$(cat "$HASH_FILE" 2>/dev/null)"
  if [ -n "$SAVED_HASH" ] && [ -n "$CUR_HASH" ] && [ "$CUR_HASH" != "$SAVED_HASH" ]; then
    echo "=== [$(date -Iseconds)] HALT hand-edit detected: $OUT_MD (hash mismatch) — 契約反映後に $HASH_FILE を削除で再開 ===" >> "$LOG"
    notify "✍️ 手修正検知: $(basename "$OUT_MD") — 上書き中止。契約反映→hashファイル削除で再開"
    exit 4
  fi
fi

MODEL_ARGS=()
[ -n "$MODEL" ] && MODEL_ARGS=(--model "$MODEL")

# runner_extra_dir があり実在ディレクトリなら 2 本目の --add-dir として渡す (vault 等 WORKDIR 外の読取)
EXTRA_DIR_ARGS=()
[ -n "$EXTRA_DIR" ] && [ -d "$EXTRA_DIR" ] && EXTRA_DIR_ARGS=(--add-dir "$EXTRA_DIR")

{
  echo "=== [$TS] vault-prompt-runner start ==="
  echo "    prompt=$PROMPT_FILE slug=$SLUG workdir=$WORKDIR tools=[$TOOLS] -> $OUT_MD"
} >> "$LOG"

# --allowedTools の渡し方 (2026-07-04): frontmatter がカンマ区切りなら 1 引数で渡す
# — `Bash(git log:*)` のようなスペース入りパターンに対応。従来のスペース区切りは word-split で後方互換。
if [[ "$TOOLS" == *,* ]]; then
  TOOLS_ARGS=(--allowedTools "$TOOLS")
else
  # shellcheck disable=SC2206
  TOOLS_ARGS=(--allowedTools $TOOLS)
fi

# --- headless 実行: プロンプト本文を stdin で渡し、テキスト出力を取得 ---
# shellcheck disable=SC2086
export VAULT_PROMPT_RUNNER=1  # headless: 対話用 Stop 関所(obs/evidence/dup)を無効化(2026-07-03 本文消失バグ対策)
RESULT="$(cd "$WORKDIR" && "$CLAUDE_BIN" -p \
  --output-format text \
  "${TOOLS_ARGS[@]}" \
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
# 一時ファイル経由 (Codex 4255acd 再指摘): 既存 OUT_MD が非空のまま書込に失敗すると
# [ -s OUT_MD ] が旧成果物で通過し silent success になるため、tmp へ書いて検査後 mv。
OUT_TMP="$OUT_MD.tmp.$$"
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
  # generated_host: 実走ホスト機を記録 (2 台重複実行の検知材料・sb2 T1)。LLM 非依存で確実に埋める
  echo "generated_host: $(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || hostname)"
  # runner_rev: runner 自身の版を刻印 (✅1a 2026-07-08・2台Macの版ズレを result を見るだけで検知)
  echo "runner_rev: $(git -C "$HOME/.claude" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  # window_end: 本文の機械可読行 `window_end: YYYY-MM-DD` を frontmatter へ転記 (✅1c 鮮度の正本)
  WINDOW_END="$(printf '%s\n' "$RESULT" | grep -m1 -oE '^window_end:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')"
  [ -n "$WINDOW_END" ] && echo "window_end: $WINDOW_END"
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
  # 鮮度行 (✅1c 2026-07-08): 生成時に初期値を書き、毎朝の鮮度スタンパ (update_claudeenv.py) が上書き更新
  _WDAYS=""
  if [ -n "$WINDOW_END" ]; then
    _WSEC="$(date -jf %Y-%m-%d "$WINDOW_END" +%s 2>/dev/null || true)"
    _TSEC="$(date -jf %Y-%m-%d "$DATE" +%s 2>/dev/null || true)"
    [ -n "$_WSEC" ] && [ -n "$_TSEC" ] && _WDAYS=$(( (_TSEC - _WSEC) / 86400 ))
  fi
  echo ""   # 空行必須: 直前の引用行に lazy continuation で吸い込まれない (2026-07-08 表示修理)
  if [ -n "$_WDAYS" ]; then
    _WARN=""; [ "$_WDAYS" -gt 10 ] && _WARN=" ⚠️10日超"
    echo "🕐 鮮度（毎朝8:00自動更新）: データ窓終端 ${WINDOW_END}＝${_WDAYS}日前${_WARN} ／ 更新 ${DATE}＝0日前 %%freshness%%"
  else
    echo "🕐 鮮度（毎朝8:00自動更新）: データ窓終端 未記載 ／ 更新 ${DATE}＝0日前 %%freshness%%"
  fi
  echo ""
  printf '%s\n' "$RESULT"
} > "$OUT_TMP"

# 書込成功の確認 (Codex 4255acd レビュー指摘: silent success 遮断)。tmp が空/欠損 or mv 失敗 = exit 5
if [ ! -s "$OUT_TMP" ] || ! mv -f "$OUT_TMP" "$OUT_MD" 2>>"$LOG"; then
  rm -f "$OUT_TMP" 2>/dev/null
  echo "=== [$(date -Iseconds)] FATAL write-failed: $OUT_MD ===" >> "$LOG"
  notify "🛑 FATAL: レポート書込失敗 $(basename "$OUT_MD")"
  exit 5
fi

# --- 品質ゲート (存在検査・fail-open・opt-in: runner_quality_gate) 2026-07-08 ---
# 施策節の各アクションに「なぜ(放置コスト)語 + 実在する理由資料リンク」が揃っているかの存在検査。
# 内容の妥当性は保証しない (presence gate)。NG でも書き戻しは止めない (成果物消失防止・警告バナー追記のみ)。
QGATE="$(fm_get runner_quality_gate)"
GATE_PY="$HOME/.claude/scripts/report_action_presence_gate.py"
if [ "$QGATE" = "action-evidence" ]; then
  if [ ! -f "$GATE_PY" ]; then
    # 無言スキップ廃止 (✅1a 2026-07-08): script 不在は SKIPPED として OK と区別する
    echo "=== [$(date -Iseconds)] quality-gate SKIPPED (script missing: $GATE_PY) ===" >> "$LOG"
    notify "⚠️ 品質ゲート SKIPPED: gate script 不在 ($SLUG) — ~/.claude を git pull"
  elif ! GATE_OUT="$(/usr/bin/python3 "$GATE_PY" --annotate "$OUT_MD" 2>>"$LOG")"; then
    echo "=== [$(date -Iseconds)] quality-gate NG: ${GATE_OUT:0:300} ===" >> "$LOG"
    notify "🚦品質ゲートNG: ${SLUG}（なぜ/理由資料の欠落）"
  elif printf '%s' "$GATE_OUT" | grep -q '"gate_status": *"error"'; then
    # fail-open (exit 0) と fail-silent の分離: gate 自身の故障を OK と偽装しない
    echo "=== [$(date -Iseconds)] quality-gate ERROR (fail-open・gate自身の故障): ${GATE_OUT:0:300} ===" >> "$LOG"
    notify "⚠️ 品質ゲート ERROR(fail-open): $SLUG — gate が故障しています"
  else
    echo "=== [$(date -Iseconds)] quality-gate OK ===" >> "$LOG"
  fi
fi

# --- 📡embed 断線検査 (✅1c 2026-07-08・warn-only) ---
# runner_embed_watch (カンマ区切り・~可) のノート内 ![[note#anchor]] が生成直後の実体に
# 解決できるかを検査。7/13 型の「窓が静かに壊れる」を生成の直後に検知する。
EMBED_WATCH="$(fm_get runner_embed_watch)"
if [ -n "$EMBED_WATCH" ] && [ -f "$GATE_PY" ]; then
  EMBED_FILES=()
  IFS=',' read -ra _EW <<< "$EMBED_WATCH"
  for _e in "${_EW[@]}"; do
    _e="$(echo "$_e" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"; _e="${_e/#\~/$HOME}"
    [ -f "$_e" ] && EMBED_FILES+=("$_e")
  done
  if [ "${#EMBED_FILES[@]}" -gt 0 ]; then
    if ! EMB_OUT="$(/usr/bin/python3 "$GATE_PY" --embeds "${EMBED_FILES[@]}" 2>>"$LOG")"; then
      echo "=== [$(date -Iseconds)] embed-check NG: ${EMB_OUT:0:300} ===" >> "$LOG"
      notify "📡 embed断線: $SLUG の窓が壊れています（見出し不一致）"
    elif printf '%s' "$EMB_OUT" | grep -q '"gate_status": *"error"'; then
      # embed 検査自身の故障も OK と区別 (Codex 4255acd レビュー指摘)
      echo "=== [$(date -Iseconds)] embed-check ERROR (fail-open): ${EMB_OUT:0:300} ===" >> "$LOG"
      notify "⚠️ embed検査 ERROR(fail-open): $SLUG — 検査が故障しています"
    fi
  fi
fi

# --- CP章の構造検査 (✅金標準恒久化 2026-07-08・warn-only・書込なし=evergreenボード保護) ---
# runner_cp_gate (~可・カンマ区切り) のボードに gate --cp-sections を当て、金標準の骨格
# (⏱/窓/原因|狙い/判定/①〜④/状態タグ/やること/なぜ/折りたたみ) の欠落を生成直後に検知。
CP_GATE="$(fm_get runner_cp_gate)"
if [ -n "$CP_GATE" ] && [ -f "$GATE_PY" ]; then
  CPG_FILES=()
  IFS=',' read -ra _CG <<< "$CP_GATE"
  for _c in "${_CG[@]}"; do
    _c="$(echo "$_c" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"; _c="${_c/#\~/$HOME}"
    [ -f "$_c" ] && CPG_FILES+=("$_c")
  done
  if [ "${#CPG_FILES[@]}" -gt 0 ]; then
    if ! CPG_OUT="$(/usr/bin/python3 "$GATE_PY" --cp-sections "${CPG_FILES[@]}" 2>>"$LOG")"; then
      echo "=== [$(date -Iseconds)] cp-sections NG: ${CPG_OUT:0:300} ===" >> "$LOG"
      notify "📐 CP章の骨格欠落: $SLUG（ボードの金標準要素が欠けています）"
    elif printf '%s' "$CPG_OUT" | grep -q '"gate_status": *"error"'; then
      echo "=== [$(date -Iseconds)] cp-sections ERROR (fail-open): ${CPG_OUT:0:300} ===" >> "$LOG"
      notify "⚠️ CP章検査 ERROR(fail-open): $SLUG"
    fi
  fi
fi

# 手修正検知用 hash 保存 (gate --annotate の追記後の最終形を記録)
shasum -a 256 "$OUT_MD" 2>/dev/null | awk '{print $1}' > "$HASH_FILE" || true

echo "=== [$(date -Iseconds)] OK -> $OUT_MD ($(wc -l < "$OUT_MD") lines) ===" >> "$LOG"
# 成功も通知 (2026-07-04): 成果物が「書かれたが誰も読まない」状態の解消 (失敗時通知と対)
osascript -e "display notification \"$SLUG 完了 → $(basename "$OUT_MD")\" with title \"Claude 定期実行\"" 2>/dev/null || true
echo "$OUT_MD"
exit 0
