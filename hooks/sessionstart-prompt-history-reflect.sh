#!/bin/bash
# sessionstart-prompt-history-reflect.sh — SessionStart hook
# prompt-history の日次反映 (launchd でなく SessionStart 起動 = vault への TCC/FDA 問題を回避)。
# 設計: docs/prompt-history-design.md / 実行本体: scripts/prompt-history-reflect.py
# hook-development-guide 準拠: headless ガード・日次スタンプ・fail-open・出力は警告時のみ。

# headless (vault-prompt-runner 等) では実行しない
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

BASE="$HOME/.claude/state/prompt-history"
ATTEMPT="$BASE/reflect-last-attempt"
SUCCESS="$BASE/reflect-last-success"
LOG="$BASE/reflect.log"
mkdir -p "$BASE" 2>/dev/null || exit 0

now=$(date +%s)
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

# writer 死活の相互監視 (Codex 条件7): writer-last-success が 48h 超 or 受領票が
# 溜まっているのに一度も成功していない場合に警告
# (スタンプは vault 内 = 両 Mac に同期されるため、非 writer 機でも検知できる)
WRITER_STAMP="$HOME/Documents/Obsidian Vault/03_ClaudeEnv/prompts/.queue/writer-last-success"
if [ -f "$WRITER_STAMP" ]; then
  ws=$(mtime "$WRITER_STAMP")
  if [ -n "$ws" ] && [ $((now - ws)) -gt 172800 ]; then
    echo "⚠️ prompt-history: INBOX 反映が 48h 以上成功していません (writer 停止 or Obsidian Git 同期停止の疑い)。tail $LOG で確認"
  fi
else
  oldest=$(ls "$BASE/receipts" 2>/dev/null | head -1)
  if [ -n "$oldest" ]; then
    of=$(mtime "$BASE/receipts/$oldest")
    [ -n "$of" ] && [ $((now - of)) -gt 172800 ] && \
      echo "⚠️ prompt-history: 受領票が 48h 以上溜まっていますが INBOX 反映が一度も成功していません。tail $LOG で確認"
  fi
fi

# 成功 20h 未満なら skip / 成功が古くても直近 2h に試行済みなら skip (試行と成功を分離)
if [ -f "$SUCCESS" ]; then
  s=$(mtime "$SUCCESS")
  [ -n "$s" ] && [ $((now - s)) -lt 72000 ] && exit 0
fi
if [ -f "$ATTEMPT" ]; then
  a=$(mtime "$ATTEMPT")
  [ -n "$a" ] && [ $((now - a)) -lt 7200 ] && exit 0
fi
touch "$ATTEMPT"

# バックグラウンドで反映 (セッション起動をブロックしない・fail-open)
( /usr/bin/python3 "$HOME/.claude/scripts/prompt-history-reflect.py" >> "$LOG" 2>&1 ) &

exit 0
