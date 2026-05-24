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
#   - 住所録: ~/Documents/Obsidian Vault/02_Ai/AI_adscrm/project-registry.md
#   - 各プロジェクトは `## <name>` 見出しで開始、`- **root**: \`<path>\`` 行を 1 つ持つ
#   - cwd が root 以下なら該当セクションを出力（subpath 含む）
#   - 複数 root が match する場合は **最長 prefix** を採用（registry 拡張時の入れ子安全性）
#   - 比較は `pwd -P` で symlink 解決後の物理パス同士
#   - 出力: header 1 行 + 本文最大 25 行
#
# Revert: rm ~/.claude/state/vault-cc-enabled (即休眠)

# SessionStart hook の stdin (JSON) を読み捨てる
cat > /dev/null 2>&1

# Feature flag gate (デフォルト OFF = 休眠 = 何もしない)
[ -f "$HOME/.claude/state/vault-cc-enabled" ] || exit 0

REGISTRY="$HOME/Documents/Obsidian Vault/02_Ai/AI_adscrm/project-registry.md"
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

exit 0
