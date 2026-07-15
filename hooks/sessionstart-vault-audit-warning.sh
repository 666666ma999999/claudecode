#!/bin/bash
# ~/.claude/hooks/sessionstart-vault-audit-warning.sh
#
# weekly-vault-audit.sh の検出結果を SessionStart で warning 注入する。
# 違反 0 件なら silent exit。
#
# 設計根拠: Agent adversarial review (2026-05-16) リスク #1#4#7 mitigation
# 「文書だけ増やして実装伴わない」を hook で機械的に検知する

# 多バイト安全（feedback 2026-07-14: C ロケール+変数直後の全角による文字化け対策）
export LC_ALL=en_US.UTF-8

# SessionStart hook の stdin (JSON) を読み捨てる
cat > /dev/null 2>&1

STATE_FILE="$HOME/.claude/state/vault-audit-violations"
[ -f "$STATE_FILE" ] || exit 0

violations=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
[ "$violations" -gt 0 ] || exit 0

timestamp=$(cat "${STATE_FILE}.timestamp" 2>/dev/null || echo "unknown")
AUDIT_FILE="$HOME/Documents/Obsidian Vault/wiki/meta/_audit/AI_adscrm.md"

# 同一監査 run は 1 回だけ通知（毎セッションの nag 化を防ぐ・次回の週次実行で復活）
# 2026-07-15 改善（敵対レビュー縮小版）: 件数のみ→先頭1件の内容を人間語で・実コマンドは注入しない
NOTIFIED_FILE="${STATE_FILE}.notified"
[ "$(cat "$NOTIFIED_FILE" 2>/dev/null)" = "$timestamp" ] && exit 0

first_violation=$(awk -v ts="$timestamp" '
  index($0, "## " ts) == 1 { insec=1; next }
  insec && /^## /          { exit }
  insec && /^- ❌/         { print; exit }
' "$AUDIT_FILE" 2>/dev/null | sed 's/ → 退避は人間✅で:.*$//' | cut -c1-220)

echo "=== ⚠️ vault audit: ${violations} 件未解決 (${timestamp} / この監査 run の通知は今回のみ) ==="
[ -n "$first_violation" ] && echo "最優先: $first_violation"
echo "今の作業を優先してよい。区切りで「vault監査の未解決を見せて」と言えば全件+対処案を出す"

echo "$timestamp" > "$NOTIFIED_FILE" 2>/dev/null

exit 0
