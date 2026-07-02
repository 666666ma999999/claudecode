#!/usr/bin/env bash
# 恒久ホーム版 arm。worktree 非依存。
# 実行: ! bash ~/.claude/rohan-selfimprove/arm_watch.sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
LA="$HOME/Library/LaunchAgents/com.masa.rohan-selfimprove-watch.plist"
LOGDIR="/Users/masaaki/Desktop/prm/rohan/logs"
mkdir -p "$HOME/Library/LaunchAgents" "$LOGDIR"
cat > "$LA" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.masa.rohan-selfimprove-watch</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/python3</string><string>${DIR}/watch_activate.py</string><string>--check</string>
  </array>
  <key>StartCalendarInterval</key><dict><key>Minute</key><integer>37</integer></dict>
  <key>StandardOutPath</key><string>${LOGDIR}/selfimprove-watch.log</string>
  <key>StandardErrorPath</key><string>${LOGDIR}/selfimprove-watch.err</string>
  <key>RunAtLoad</key><true/>
</dict></plist>
PLIST
launchctl unload "$LA" 2>/dev/null || true
launchctl load "$LA"
[ -f "${DIR}/_corpus/_activation_marker.json" ] || python3 "${DIR}/watch_activate.py" --install
echo "=== re-armed (恒久ホーム: ${DIR}) ==="
launchctl list | grep rohan-selfimprove-watch || echo "(未登録=load失敗)"
python3 "${DIR}/watch_activate.py" --status
