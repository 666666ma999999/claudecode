#!/bin/bash
# PreToolUse (Read|Edit|Glob|Grep) フック
# ~/.claude/ 配下のファイル操作前に自動 git pull を実行する

INPUT=$(cat)

# JSON解析: file_path or path を抽出
FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    fp = ti.get('file_path', '') or ti.get('path', '') or ti.get('pattern', '')
    print(fp)
except:
    print('')
" 2>/dev/null)"

# ~/.claude/ 配下でなければスキップ
CLAUDE_DIR="$HOME/.claude"
case "$FILE_PATH" in
  "$CLAUDE_DIR"/*|"$HOME/.claude/"*) ;;
  *) echo '{"decision":"approve"}'; exit 0 ;;
esac

# クールダウン: 30秒以内に前回pullしていればスキップ
TIMESTAMP_FILE="/tmp/.claude-git-pull-timestamp"
if [[ -f "$TIMESTAMP_FILE" ]]; then
  LAST_PULL=$(cat "$TIMESTAMP_FILE" 2>/dev/null)
  NOW=$(date +%s)
  ELAPSED=$(( NOW - ${LAST_PULL:-0} ))
  if [[ $ELAPSED -lt 30 ]]; then
    echo '{"decision":"approve"}'
    exit 0
  fi
fi

# mkdirによるアトミックロック（macOS互換、flockの代替）
LOCK_DIR="/tmp/.claude-git-pull-lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # 既にロック中 → スキップ
  echo '{"decision":"approve"}'
  exit 0
fi
# ロック解放用トラップ
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# git pull --rebase（3秒タイムアウト、macOS互換）
(
  cd "$CLAUDE_DIR" || exit 1
  # バックグラウンドでgit pull実行
  git pull --rebase --no-edit &
  GIT_PID=$!
  # 3秒タイムアウト
  (sleep 3 && kill $GIT_PID 2>/dev/null) &
  TIMER_PID=$!
  wait $GIT_PID 2>/dev/null
  kill $TIMER_PID 2>/dev/null
) &>/dev/null

# タイムスタンプ更新
date +%s > "$TIMESTAMP_FILE"

# 常にapprove（失敗してもブロックしない）
echo '{"decision":"approve"}'
exit 0
