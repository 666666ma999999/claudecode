#!/bin/bash
# ~/.claude/hooks/sessionstart-vault-audit-warning.sh
#
# weekly-vault-audit.sh の検出結果を SessionStart で warning 注入する。
# 違反 0 件なら silent exit。
#
# 設計根拠: Agent adversarial review (2026-05-16) リスク #1#4#7 mitigation
# 「文書だけ増やして実装伴わない」を hook で機械的に検知する

# SessionStart hook の stdin (JSON) を読み捨てる
cat > /dev/null 2>&1

STATE_FILE="$HOME/.claude/state/vault-audit-violations"
[ -f "$STATE_FILE" ] || exit 0

violations=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
[ "$violations" -gt 0 ] || exit 0

timestamp=$(cat "${STATE_FILE}.timestamp" 2>/dev/null || echo "unknown")
AUDIT_FILE="$HOME/Documents/Obsidian Vault/wiki/meta/_audit/AI_adscrm.md"

echo "=== ⚠️ vault audit: $violations violation(s) detected ($timestamp) ==="
echo "詳細: cat \"$AUDIT_FILE\""
echo "rules/41 と AI_adscrm/ 実装の整合確認が必要"

exit 0
