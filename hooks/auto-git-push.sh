#!/bin/bash
# ~/.claude/ 配下のファイル変更時に自動commit & push
# PostToolUse (Write|Edit|Bash) フックから呼ばれる

INPUT=$(cat)

# python3でJSON解析（jq不要）
eval "$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tn = d.get('tool_name', '')
    ti = d.get('tool_input', {})
    fp = ti.get('file_path', '') or ti.get('path', '')
    print(f'TOOL_NAME=\"{tn}\"')
    print(f'FILE_PATH=\"{fp}\"')
except:
    print('TOOL_NAME=\"\"')
    print('FILE_PATH=\"\"')
" 2>/dev/null)"

# Write/Edit: ファイルパスで判定
if [[ "$TOOL_NAME" != "Bash" ]]; then
  [[ "$FILE_PATH" != $HOME/.claude/* ]] && exit 0
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
