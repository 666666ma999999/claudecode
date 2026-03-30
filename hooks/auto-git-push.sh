#!/bin/bash
# ~/.claude/ 配下のファイル変更時に自動commit & push
# PostToolUse (Write|Edit) フックから呼ばれる

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

# verify-step未完了時はpushをスキップ（commitのみ実行）
SKIP_PUSH=false
if [ -f ~/.claude/state/verify-step.pending ]; then
  SKIP_PUSH=true
fi

# 変更があればcommit & push（バックグラウンドで実行）
# --no-verify: このフック自身による再帰呼び出しを防止するため必須
(
  cd ~/.claude
  # git add -A は禁止（10-git-and-execution-guard.md）。管理対象を明示指定
  git add \
    settings.json \
    .mcp.json \
    CLAUDE.md \
    hooks/ \
    rules/ \
    skills/ \
    memory/ \
    statusline.sh \
    .claude/settings.local.json \
    2>/dev/null
  # git add -u は使わない（意図しないファイルのステージング防止）
  git add \
    agents/ \
    commands/ \
    scripts/ \
    data/ \
    templates/ \
    sessions/ \
    state/ \
    2>/dev/null
  git diff --cached --quiet && exit 0
  git commit -m "auto: update $(date '+%Y-%m-%d %H:%M')" --no-verify
  if [ "$SKIP_PUSH" = "true" ]; then
    exit 0
  fi
  git pull --ff-only 2>/dev/null || true
  if ! git push 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] push failed" >> ~/.claude/state/auto-push-errors.log
  fi
) &>/dev/null &

exit 0
