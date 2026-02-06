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
  "$CLAUDE_DIR"/*) ;;
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
# 60秒以上古いロックは孤立とみなして自動削除
LOCK_DIR="/tmp/.claude-git-pull-lock"
if [[ -d "$LOCK_DIR" ]]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
  if [[ $LOCK_AGE -gt 60 ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR"
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # 既にロック中 → スキップ
  echo '{"decision":"approve"}'
  exit 0
fi
# ロック解放用トラップ
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

# git pull --rebase（3秒タイムアウト、macOS互換）
# フォアグラウンドで実行し、完了を保証してからスクリプトを抜ける
cd "$CLAUDE_DIR" || { echo '{"decision":"approve"}'; exit 0; }
git pull --rebase --no-edit &
GIT_PID=$!
(sleep 3 && kill $GIT_PID 2>/dev/null) &
TIMER_PID=$!
wait $GIT_PID 2>/dev/null
GIT_EXIT=$?
kill $TIMER_PID 2>/dev/null
wait $TIMER_PID 2>/dev/null

# 成功時のみタイムスタンプ更新（失敗時は次回即リトライ可能）
if [[ $GIT_EXIT -eq 0 ]]; then
  date +%s > "$TIMESTAMP_FILE"
fi

# 常にapprove（失敗してもブロックしない）
echo '{"decision":"approve"}'
exit 0
