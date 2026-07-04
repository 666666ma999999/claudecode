#!/bin/bash
# ~/.claude/hooks/sessionstart-project-registry.sh
#
# SessionStart hook: cwd 配下のプロジェクトを vault 住所録から特定し、該当セクションを
# context に注入する。「vault=管制塔、repo=倉庫」のハイブリッドモデルの連結機構。
#
# Feature flag:
#   ~/.claude/state/vault-cc-enabled が存在しなければ即 exit (休眠・完全無害)。
#
# 設計:
#   - 住所録: ~/Documents/Obsidian Vault/wiki/meta/project-registry.md
#   - 各プロジェクトは `## <name>` 見出しで開始、`- **root**: \`<path>\`` 行を 1 つ持つ
#   - cwd が root 以下なら該当セクションを出力（subpath 含む）
#   - 複数 root が match する場合は **最長 prefix** を採用（registry 拡張時の入れ子安全性）
#   - 比較は `pwd -P` で symlink 解決後の物理パス同士
#   - 出力: header 1 行 + 本文最大 25 行
#
# Revert: rm ~/.claude/state/vault-cc-enabled (即休眠)

# SessionStart hook の stdin (JSON) を読み捨てる
cat > /dev/null 2>&1

# ─── SPEC 起点 (Specification Layer・2026-07-04) ───
# vault-cc flag と無関係の普遍動作のため flag gate の手前に置く:
# cwd の git root に plan.md / tasks/*.md があれば「Session Handoff を読んでから着手」の
# 起点リマインダーを注入する (本文は注入しない = トークン最小・CLAUDE.md step 0 の act-time 化)。
SPEC_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P 2>/dev/null)"
if [ -n "$SPEC_ROOT" ]; then
  spec_plan=""
  [ -f "$SPEC_ROOT/plan.md" ] && spec_plan="yes"
  latest_task="$(ls -t "$SPEC_ROOT"/tasks/*.md 2>/dev/null | head -1)"
  if [ -n "$spec_plan" ] || [ -n "$latest_task" ]; then
    echo "=== 📐 SPEC起点 (${SPEC_ROOT##*/}) ==="
    [ -n "$spec_plan" ] && echo "- 設計SSoT: $SPEC_ROOT/plan.md を起点に作業する"
    [ -n "$latest_task" ] && echo "- 最新task: $latest_task → Session Handoff を読んでから着手する"
  fi
fi

# Feature flag gate (デフォルト OFF = 休眠 = 何もしない)
[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

REGISTRY="$HOME/Documents/Obsidian Vault/wiki/meta/project-registry.md"
[ -f "$REGISTRY" ] || exit 0

# cwd を symlink 解決した物理パスに正規化
CWD="$(pwd -P 2>/dev/null)"
[ -z "$CWD" ] && exit 0

# `**root**:` 行の正規表現（行頭・行末を anchor して誤検出を防ぐ）
ROOT_RE='^[[:space:]-]*\*\*root\*\*:[[:space:]]*`([^`]+)`[[:space:]]*$'

# 全セクションを走査し、cwd と match する最長 root を持つセクションを採用
best_section=""
best_root_len=0
current_section=""
current_root_raw=""

eval_section() {
  # 現在のセクションを評価し、match していれば best 候補と長さ比較
  [ -z "$current_root_raw" ] && return
  [ -z "$current_section" ] && return

  # root を物理パス化（存在しなければそのセクションは無視）
  local normalized_root=""
  if [ -d "$current_root_raw" ]; then
    normalized_root="$(cd "$current_root_raw" 2>/dev/null && pwd -P)"
  fi
  [ -z "$normalized_root" ] && return

  # cwd が root 以下か（prefix 一致 or exact 一致・macOS case-insensitive FS 対応）
  local cwd_lower="$(echo "$CWD" | tr '[:upper:]' '[:lower:]')"
  local root_lower="$(echo "$normalized_root" | tr '[:upper:]' '[:lower:]')"
  if [[ "$cwd_lower/" == "$root_lower/"* ]] || [[ "$cwd_lower" == "$root_lower" ]]; then
    if [ ${#normalized_root} -gt $best_root_len ]; then
      best_section="$current_section"
      best_root_len=${#normalized_root}
    fi
  fi
}

while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^##[[:space:]] ]]; then
    eval_section
    current_section="$line"
    current_root_raw=""
  else
    if [ -n "$current_section" ]; then
      current_section="${current_section}"$'\n'"${line}"
      if [[ "$line" =~ $ROOT_RE ]]; then
        raw="${BASH_REMATCH[1]}"
        raw="${raw/#\~/$HOME}"
        current_root_raw="$raw"
      fi
    fi
  fi
done < "$REGISTRY"

# 最終セクションの救済（次の `## ` が無いので eval_section が未呼出）
eval_section

# match なしなら silent exit
[ -z "$best_section" ] && exit 0

# header の cwd 表示（制御文字を除去して 1 行保証）
cwd_label="$(basename "$CWD" | tr -d '\n\r\t')"

# 出力: header + 本体（最大 25 行）
{
  echo "=== 📋 PROJECT REGISTRY (cwd: $cwd_label) ==="
  echo "$best_section" | head -25
}

# ─── playbook 注入 (該当 section に playbook 絶対パスがあれば Must Remember を出力) ───
# registry の playbook 行に書かれた `~/Documents/...-playbook.md` を抽出し、
# その `## Must Remember` section を context 注入する (= project ごと運用知の自動想起)。
# playbook 行が無いプロジェクトでは何も出ない (= 既存動作に影響なし・安全)
playbook_path="$(echo "$best_section" | grep -oE '~/Documents/[^`]*-playbook\.md' | head -1)"
playbook_path="${playbook_path/#\~/$HOME}"
if [ -n "$playbook_path" ] && [ -f "$playbook_path" ]; then
  # `## Must Remember` section から箇条書き行 (- or *) のみ抽出 (説明文/HTMLコメント/空行除外・最大 15 行)
  must_remember="$(awk '/^## Must Remember/{f=1;next} /^## /{f=0} f' "$playbook_path" | grep -E '^[[:space:]]*[-*] ' | head -15)"
  if [ -n "$must_remember" ]; then
    echo ""
    echo "=== 📒 $(basename "$playbook_path" .md) Must Remember (運用知・自動想起) ==="
    echo "$must_remember"
  fi
fi

exit 0
