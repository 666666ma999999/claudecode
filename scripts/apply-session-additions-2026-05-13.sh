#!/usr/bin/env bash
# 2026-05-13 セッション追加分の 2 台目 PC 適用スクリプト
# 詳細: ~/.claude/docs/handoff-2026-05-13.md

set -euo pipefail
echo "=== 2026-05-13 session additions setup ==="

USER_HOME="$HOME"
PLIST_DIR="$USER_HOME/Library/LaunchAgents"
PLIST_NAME="com.masa.weekly-env-pulse.plist"
PLIST_PATH="$PLIST_DIR/$PLIST_NAME"

# Step 1: plist を生成 (~/Library/LaunchAgents/ は git 管理外のため毎回生成)
mkdir -p "$PLIST_DIR"
cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.masa.weekly-env-pulse</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${USER_HOME}/.claude/scripts/weekly_env_pulse.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${USER_HOME}/.claude</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>1</integer>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>5</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${USER_HOME}/.claude/state/weekly_env_pulse.out.log</string>
  <key>StandardErrorPath</key>
  <string>${USER_HOME}/.claude/state/weekly_env_pulse.err.log</string>
</dict>
</plist>
PLIST_EOF
plutil -lint "$PLIST_PATH" || { echo "plist 構文エラー"; exit 1; }
echo "[1/4] plist 生成 OK: $PLIST_PATH"

# Step 2: launchctl 登録 (既に登録済なら一旦 unload して再登録)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "[2/4] launchctl 登録 OK"
launchctl list | grep com.masa.weekly-env-pulse || { echo "登録失敗"; exit 1; }

# Step 3: hook script 実行権限 + version state 初期化
chmod +x "$USER_HOME/.claude/hooks/sessionstart-version-diff.sh"
chmod +x "$USER_HOME/.claude/scripts/weekly_env_pulse.sh"
mkdir -p "$USER_HOME/.claude/state"
if [ ! -f "$USER_HOME/.claude/state/claude-version.last" ]; then
  CURRENT=$(claude --version 2>/dev/null | awk '{print $1}')
  if [ -n "$CURRENT" ]; then
    echo "$CURRENT" > "$USER_HOME/.claude/state/claude-version.last"
    echo "[3/4] version state 初期化: $CURRENT"
  else
    echo "[3/4] WARN: claude --version が取れず、state 未初期化"
  fi
else
  echo "[3/4] version state 既存: $(cat "$USER_HOME/.claude/state/claude-version.last")"
fi

# Step 4: dry-run 動作確認
echo "[4/4] weekly_env_pulse dry-run..."
bash "$USER_HOME/.claude/scripts/weekly_env_pulse.sh"
echo "--- 最新 env_pulse ---"
tail -1 "$USER_HOME/.claude/state/env_pulse.jsonl"
echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "確認方法:"
echo "  launchctl list | grep com.masa"
echo "  tail -4 ~/.claude/state/env_pulse.jsonl"
echo ""
echo "次回 weekly 自動実行: 月曜 08:05"
