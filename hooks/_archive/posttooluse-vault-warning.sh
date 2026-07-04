#!/bin/bash
# ~/.claude/hooks/posttooluse-vault-warning.sh
#
# AI_adscrm/ group 配下の MOC (*_ope.md) や subproject ディレクトリへの Edit/Write 検知時に
# rules/41 と vault ガイドの追従確認 warning を出す。
#
# 設計根拠: Agent adversarial review (2026-05-16) リスク #2 mitigation
# 「実装 → rules/41 → guide」の同セッション内追従を促す

# stdin から tool use の JSON を読む
input=$(cat 2>/dev/null)
[ -n "$input" ] || exit 0

# AI_adscrm/ group 配下の MOC (*_ope.md) または旧 AIads/AIcrm/ サブディレクトリへの編集を検出
if echo "$input" | grep -qE '02_Ai/AI_adscrm/((AIads|AIcrm)/|[A-Za-z0-9_-]+_ope\.md)'; then
  RULES41="$HOME/.claude/rules/41-vault-project-structure.md"
  GUIDE="$HOME/Documents/Obsidian Vault/02_Ai/_vault-project-structure-guide.md"

  # 最終更新日比較
  RULES41_DATE=$(stat -f '%Sm' -t '%Y-%m-%d' "$RULES41" 2>/dev/null || echo "unknown")
  GUIDE_DATE=$(stat -f '%Sm' -t '%Y-%m-%d' "$GUIDE" 2>/dev/null || echo "unknown")
  TODAY=$(date '+%Y-%m-%d')

  if [ "$RULES41_DATE" != "$TODAY" ] || [ "$GUIDE_DATE" != "$TODAY" ]; then
    echo "=== ⚠️ AI_adscrm 編集検出 (rules/41 / guide 追従確認推奨) ==="
    echo "rules/41 last_updated: $RULES41_DATE | guide: $GUIDE_DATE | today: $TODAY"
    echo "実装変更が規範に影響するなら同セッション内で追従を (Agent review リスク #2)"
  fi
fi

exit 0
