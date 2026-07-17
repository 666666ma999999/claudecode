#!/bin/bash
# build-vaultjobs-app.sh — VaultJobs.app（wiki-daily-ingest / eng-vocab-weekly の TCC ラッパー）を再生成
#
# 方式は build-chatcards-app.sh と同じ（app bundle + NSDocumentsFolderUsageDescription +
# AppleScript native read でダイアログ発火）。ジョブ本体は vault-job-dispatch.sh が
# CLAUDE_JOB 環境変数（launchd plist の EnvironmentVariables）で分岐する。
# ⚠️ 再ビルドすると code 署名が変わり TCC 許可が無効化される（許可ダイアログの再クリックが必要）。
set -euo pipefail

APP="/Applications/VaultJobs.app"

osacompile -o "$APP" -e 'try
	read (POSIX file "/Users/masaaki/Documents/Obsidian Vault/00_General/prompts/scheduled/wiki-daily-ingest.md") as «class utf8»
end try
do shell script "exec $HOME/.claude/scripts/vault-job-dispatch.sh"'

/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :NSDocumentsFolderUsageDescription string "wiki自動取り込みと週次英単語帳がObsidian vault（書類フォルダ内）を読み書きします"' "$APP/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c 'Set :NSDocumentsFolderUsageDescription "wiki自動取り込みと週次英単語帳がObsidian vault（書類フォルダ内）を読み書きします"' "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"

echo "[ok] $APP を再生成（次回実行時に許可ダイアログが再表示される — ユーザーの「許可」が必要）"
