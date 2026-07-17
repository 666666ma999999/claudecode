#!/bin/bash
# build-chatcards-app.sh — ChatCards.app（chat-cards 毎時ジョブの TCC ラッパー）を再生成する
#
# なぜ app bundle 経由か（2026-07-17 実障害の教訓）:
#   launchd の bash 直実行は Documents（Obsidian vault）を TCC に無音拒否され、
#   FDA 付与の GUI 操作も本人には難しかった。app bundle + NSDocumentsFolderUsageDescription
#   なら OS 標準の許可ダイアログが出て「許可」1クリックで済む。
#   さらに: シェル child の read では prompt が発火しない → AppleScript native read を先頭に置く。
#
# ⚠️ 再ビルドすると code 署名が変わり TCC の許可が無効化される（許可ダイアログをもう一度
#    ユーザーがクリックする必要あり）。壊れた時以外は再ビルドしないこと。
set -euo pipefail

APP="/Applications/ChatCards.app"

osacompile -o "$APP" -e 'try
	read (POSIX file "/Users/masaaki/Documents/Obsidian Vault/00_General/prompts/scheduled/chat-cards-hourly.md") as «class utf8»
end try
do shell script "/usr/bin/python3 $HOME/.claude/scripts/chat_card_extract.py && $HOME/.claude/scripts/vault-prompt-runner.sh \"$HOME/Documents/Obsidian Vault/00_General/prompts/scheduled/chat-cards-hourly.md\" && /usr/bin/python3 $HOME/.claude/scripts/chat_card_apply.py \"$HOME/Documents/Obsidian Vault/00_Inbox/chat-reports/chat-cards-hourly-result.md\""'

/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :NSDocumentsFolderUsageDescription string "Chat承認カードをObsidian vault（書類フォルダ内）へ書き込むためにアクセスします"' "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c 'Set :NSDocumentsFolderUsageDescription "Chat承認カードをObsidian vault（書類フォルダ内）へ書き込むためにアクセスします"' "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"

echo "[ok] $APP を再生成（次回実行時に許可ダイアログが再表示される — ユーザーの「許可」が必要）"
