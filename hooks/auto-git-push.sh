#!/bin/bash
# ~/.claude/ 配下のファイル変更時に自動commit & push
# PostToolUse (Write|Edit|Bash) フックから呼ばれる

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Write/Edit: ファイルパスで判定
if [[ "$TOOL_NAME" != "Bash" ]]; then
  [[ "$FILE_PATH" != /Users/masaaki/.claude/* ]] && exit 0
fi

# Bash: ~/.claude/ に未commitの変更があるか確認
if [[ "$TOOL_NAME" == "Bash" ]]; then
  cd ~/.claude || exit 0
  git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ] && exit 0
fi

cd ~/.claude || exit 0

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
