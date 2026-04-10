#!/bin/bash
# ~/.claude/hooks/obsidian-now-done-guard.sh
# PostToolUse hook: Obsidian Vault MDファイルのDONEエントリが元プロンプト保存形式を守っているか検証する
#
# ルール（CLAUDE.md Obsidian連携）:
#   NOW→DONE移動時、元プロンプトを一字一句残し、**結果:** を追記する。
#
# 検出条件:
#   DONEセクション内の `### タスク名 ...` 見出しエントリに `**結果:**` マーカーが
#   ない場合、違反として警告をexit 2で返す（Claudeにフィードバックを届ける）。

# stdin からフックペイロードを取得
input=$(cat 2>/dev/null || true)

# jq が使えない環境では静かに終了
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# ファイルパス未取得ならスキップ
if [ -z "$file_path" ]; then
  exit 0
fi

# Obsidian Vault 配下の .md のみ対象
case "$file_path" in
  */Obsidian\ Vault/*.md) ;;
  *) exit 0 ;;
esac

# ファイルが存在しなければスキップ
if [ ! -f "$file_path" ]; then
  exit 0
fi

# DONE セクションが存在するかチェック
if ! grep -q '^## DONE' "$file_path"; then
  exit 0
fi

# DONE セクションを抽出 (## DONE から次の ## まで)
done_section=$(awk '
  /^## DONE/ { in_done=1; next }
  /^## / && in_done { exit }
  in_done { print }
' "$file_path")

if [ -z "$done_section" ]; then
  exit 0
fi

# 各 `##### ` エントリに `**結果:**` があるかチェック
# （他MDに貼り付け時の衝突を避けるため見出しレベルはh5を正規とする）
violations=$(echo "$done_section" | awk '
  BEGIN { current=""; has_result=0; body_lines=0 }
  /^##### / {
    if (current != "") {
      # 前エントリの判定
      if (!has_result || body_lines < 2) {
        print current
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
        print current
      }
    }
  }
')

if [ -n "$violations" ]; then
  cat >&2 <<EOF
[OBSIDIAN NOW→DONE FORMAT VIOLATION]
File: $file_path

以下のDONEエントリに \`**結果:**\` マーカーが無い、または本文が不足しています。
NOW→DONE移動時は元プロンプト全文を残し、その後に \`**結果:**\` を追記する必要があります（~/.claude/CLAUDE.md「Obsidian連携」参照）。

違反エントリ:
$violations

正しい形式:
  ### タスク名 (完了日)
  （NOWの元プロンプト全文を一字一句そのまま維持）

  **結果:** （実行結果のサマリー）

元プロンプトが既に失われている場合は、ユーザーに確認してから進めてください。
元プロンプトがある場合は直ちに該当エントリを修正してください。
EOF
  exit 2
fi

exit 0
