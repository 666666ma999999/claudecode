#!/bin/bash
# 見張り役（applet-reaper）を launchd に登録するワンクリックスクリプト
# （Claude Code の安全設定で AI は launchctl load を実行できないため、本人のダブルクリックで実行する）
echo "見張り役（applet-reaper）を登録します..."
launchctl load "$HOME/Library/LaunchAgents/com.masa.applet-reaper.plist" 2>/dev/null
if launchctl list | grep -q applet-reaper; then
  echo ""
  echo "✅ 登録完了！ これで全ての残作業が終わりです。"
  echo "   このウィンドウは閉じて構いません。"
else
  echo "❌ 登録に失敗しました。Claude に「見張り役の登録に失敗した」と伝えてください。"
fi
echo ""
read -n1 -s -p "何かキーを押すとこのウィンドウを閉じられます"
