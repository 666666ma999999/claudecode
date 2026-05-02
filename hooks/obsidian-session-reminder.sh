#!/bin/bash
# ~/.claude/hooks/obsidian-session-reminder.sh
# SessionStart フック: Obsidian Vault 内のDONEエントリで形式違反があればセッション開始時に警告表示
#
# 目的: 元プロンプト保存ルールをセッション開始時にClaudeに再認識させる

# stdin を消費
cat > /dev/null

VAULT="/Users/masaaki/Documents/Obsidian Vault"

if [ ! -d "$VAULT" ]; then
  exit 0
fi

# DONEセクションを持つMDファイルを列挙
md_files=$(grep -rl '^## DONE' "$VAULT" 2>/dev/null | head -20)

if [ -z "$md_files" ]; then
  exit 0
fi

violations_found=0
violation_output=""

while IFS= read -r file; do
  [ -z "$file" ] && continue

  done_section=$(awk '
    /^## DONE/ { in_done=1; next }
    /^## / && in_done { exit }
    in_done { print }
  ' "$file")

  [ -z "$done_section" ] && continue

  # 各 `##### ` エントリが `**結果:**` を持つかチェック
  file_violations=$(echo "$done_section" | awk '
    BEGIN { current=""; has_result=0 }
    /^##### / {
      if (current != "" && !has_result) {
        print current
      }
      current=$0
      has_result=0
      next
    }
    /\*\*結果:\*\*/ { has_result=1 }
    END {
      if (current != "" && !has_result) {
        print current
      }
    }
  ')

  if [ -n "$file_violations" ]; then
    violations_found=1
    violation_count=$(echo "$file_violations" | wc -l | tr -d ' ')
    rel_file=$(echo "$file" | sed "s|$VAULT/||")
    violation_output="${violation_output}  ⚠ ${rel_file}: ${violation_count}件の違反エントリ\n"
  fi
done <<< "$md_files"

# 違反検出時のみ簡潔に通知（ルール本文は ~/.claude/rules/40-obsidian.md 参照）
if [ "$violations_found" = "1" ]; then
  echo "Obsidian DONE形式違反あり（h5 + refs/ 分離・40-obsidian.md 参照）:"
  echo -e "$violation_output" | head -5
fi

exit 0
