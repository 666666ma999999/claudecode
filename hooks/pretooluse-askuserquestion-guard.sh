#!/usr/bin/env bash
# PreToolUse hook for AskUserQuestion: 連打ループ防止。
# state ファイルに直前呼び出し時刻を記録し、60 秒以内の連続呼び出しは warning。
# (denyではなくwarn。本当に必要なケースもあるため)

set -eu

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/askuserquestion-last.ts"

NOW=$(date +%s)
if [ -f "$STATE_FILE" ]; then
  LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
  DIFF=$((NOW - LAST))
  if [ "$DIFF" -lt 60 ]; then
    # stderr に出すと Claude の context に警告として返る
    cat >&2 <<MSG
⚠️ AskUserQuestion 連打検知: ${DIFF}s 前にも同ツールを使用しました。

【ルール】recurring-mistakes.md#askuserquestion-loop
- 空応答 (answers: {}) の場合、再質問せず文脈推測で進む
- 続けて確認が必要なら地の文 (普通のテキスト) で聞く
- このまま実行するならユーザーから明示的に「もう一度質問して」と言われた場合のみ

本当に必要か再考してください。
MSG
  fi
fi

echo "$NOW" > "$STATE_FILE"
exit 0
