#!/bin/bash
# ~/.claude/hooks/obsidian-now-done-guard.sh
# PostToolUse hook: Obsidian Vault MDファイルのDONEエントリが元プロンプト保存形式を守っているか検証する
#
# ルール（CLAUDE.md Obsidian連携）:
#   NOW→DONE移動時、元プロンプトを一字一句残し、**結果:** を追記する。
#   見出しは h5（#####）固定。
#
# 動作:
#   1. DONEセクション内の ##### エントリに **結果:** マーカーがないものを検出
#   2. 許容リスト（.obsidian-done-legacy）に記載された既知の違反エントリはスキップ
#   3. 新規追加の違反エントリのみ exit 2 でブロック
#
# 許容リスト:
#   各MDファイルと同じディレクトリに .obsidian-done-legacy ファイルがあれば、
#   そこに記載された見出し行（完全一致）は検証対象外とする。
#   元プロンプトが既に失われており修復不可能な過去エントリ用。

input=$(cat 2>/dev/null || true)

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$file_path" ]; then
  exit 0
fi

case "$file_path" in
  */Obsidian\ Vault/*.md) ;;
  *) exit 0 ;;
esac

if [ ! -f "$file_path" ]; then
  exit 0
fi

if ! grep -q '^## DONE' "$file_path"; then
  exit 0
fi

# DONE セクションを抽出
done_section=$(awk '
  /^## DONE/ { in_done=1; next }
  /^## / && in_done { exit }
  in_done { print }
' "$file_path")

if [ -z "$done_section" ]; then
  exit 0
fi

# 許容リストを読み込み（同ディレクトリの .obsidian-done-legacy）
dir_path=$(dirname "$file_path")
base_name=$(basename "$file_path" .md)
legacy_file="${dir_path}/.obsidian-done-legacy-${base_name}"

legacy_entries=""
if [ -f "$legacy_file" ]; then
  legacy_entries=$(cat "$legacy_file")
fi

# 各 ##### エントリを検証（許容リストに含まれるものはスキップ）
violations=$(echo "$done_section" | awk -v legacy="$legacy_entries" '
  BEGIN {
    split(legacy, arr, "\n")
    for (i in arr) known[arr[i]] = 1
    current=""; has_result=0; body_lines=0
  }
  /^##### / {
    if (current != "") {
      if (!has_result || body_lines < 2) {
        if (!(current in known)) {
          print current
        }
      }
    }
    current=$0
    has_result=0
    body_lines=0
    next
  }
  /\*\*結果:\*\*/ { has_result=1 }
  /^./ && !/^##### / { body_lines++ }
  END {
    if (current != "") {
      if (!has_result || body_lines < 2) {
        if (!(current in known)) {
          print current
        }
      }
    }
  }
')

if [ -n "$violations" ]; then
  cat >&2 <<EOF
[OBSIDIAN NOW→DONE FORMAT VIOLATION]
File: $file_path

以下の新規DONEエントリに \`**結果:**\` マーカーが無い、または本文が不足しています。
NOW→DONE移動時は元プロンプト全文を残し、その後に \`**結果:**\` を追記する必要があります（~/.claude/CLAUDE.md「Obsidian連携」参照）。

違反エントリ:
$violations

正しい形式（見出しは h5 = ##### 固定）:
  ##### タスク名 (完了日)
  （NOWの元プロンプト全文を一字一句そのまま維持）

  **結果:** （実行結果のサマリー）

元プロンプトがある場合は直ちに該当エントリを修正してください。
EOF
  exit 2
fi

exit 0
