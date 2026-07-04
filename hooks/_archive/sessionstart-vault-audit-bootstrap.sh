#!/bin/bash
# ~/.claude/hooks/sessionstart-vault-audit-bootstrap.sh
#
# SessionStart 時に LaunchAgent を所定位置へ配置し未 load なら bootstrap する。
# 初回起動時に 1 回だけ実行され、以降は launchd が独立して週次 audit を実行する。
#
# 設計根拠:
# - ~/.claude/plan.md L9 「動く hook 1 個＋使われる住所録」を満たす実動線
# - Codex 案 B (2026-05-16) + Agent adversarial review の堅牢化 3 点を反映
#
# 堅牢化:
# - リスク #3: plist 差分時は bootout で reload 強制 (冪等性確保)
# - リスク #4: bootstrap gui/$UID を一次・load をフォールバック (macOS Big Sur+ 仕様)
# - リスク #5: launchctl print で死活確認・失敗時 err ログ
#
# 既知の制限:
# - リスク #1 (1 週間以上 Claude Code 未起動なら bootstrap 遅延) は本 hook では解決不能・受容

# SessionStart hook の stdin (JSON) を読み捨てる
cat > /dev/null 2>&1

SRC="$HOME/.claude/state/com.masa.vault-audit.plist"
DST="$HOME/Library/LaunchAgents/com.masa.vault-audit.plist"
LABEL="com.masa.vault-audit"
UID_NUM="$(id -u)"
STATE_FILE="$HOME/.claude/state/vault-audit-loaded"
ERR_FILE="${STATE_FILE}.err"

# plist 正本が存在しなければ silent exit
[ -f "$SRC" ] || exit 0

mkdir -p "$HOME/Library/LaunchAgents"

# 1. plist 差分時は bootout で reload 強制 (リスク #3)
if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
  cp "$SRC" "$DST"
  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
fi

# 2. 未 load なら bootstrap (一次) → load (フォールバック・リスク #4)
if ! launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  launchctl bootstrap "gui/$UID_NUM" "$DST" 2>/dev/null \
    || launchctl load "$DST" 2>/dev/null \
    || true
fi

# 3. 死活確認・成功時 state 記録・失敗時 err ログ (リスク #5)
if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$STATE_FILE"
else
  echo "vault-audit bootstrap failed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$ERR_FILE"
fi

exit 0
