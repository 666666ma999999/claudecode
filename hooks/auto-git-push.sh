#!/bin/bash
# ~/.claude/ 配下のファイル変更時に自動commit & push
# PostToolUse (Write|Edit) フックから呼ばれる

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# ~/.claude/ 配下のファイルでなければ何もしない
[[ "$FILE_PATH" != /Users/masaaki/.claude/* ]] && exit 0

# .gitignoreで除外されるファイルは無視
cd ~/.claude || exit 0
git check-ignore -q "$FILE_PATH" 2>/dev/null && exit 0

# 変更があればcommit & push（バックグラウンドで実行）
(
  cd ~/.claude
  git add -A
  git diff --cached --quiet && exit 0
  git commit -m "auto: update $(date '+%Y-%m-%d %H:%M')" --no-verify
  git pull --rebase --no-edit 2>/dev/null
  git push 2>/dev/null
) &>/dev/null &

exit 0
