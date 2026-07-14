#!/bin/bash
# sessionstart-prompt-history-reflect.sh — SessionStart hook
# prompt-history の日次反映 (launchd でなく SessionStart 起動 = vault への TCC/FDA 問題を回避)。
# 設計: docs/prompt-history-design.md / 実行本体: scripts/prompt-history-reflect.py
# hook-development-guide 準拠: headless ガード・日次スタンプ・fail-open・出力は警告時のみ。

# headless (vault-prompt-runner 等) では実行しない
[ -n "$VAULT_PROMPT_RUNNER" ] && exit 0

BASE="$HOME/.claude/state/prompt-history"
STAMP="$BASE/reflect-last-run"
LOG="$BASE/reflect.log"
mkdir -p "$BASE" 2>/dev/null || exit 0

now=$(date +%s)

# writer 死活の相互監視 (Codex 条件7): writer-last-success が 48h 超なら警告
# (スタンプは vault 内 = 両 Mac に同期されるため、非 writer 機でも検知できる)
WRITER_STAMP="$HOME/Documents/Obsidian Vault/03_ClaudeEnv/prompts/.queue/writer-last-success"
if [ -f "$WRITER_STAMP" ]; then
  ws=$(stat -f %m "$WRITER_STAMP" 2>/dev/null || stat -c %Y "$WRITER_STAMP" 2>/dev/null)
  if [ -n "$ws" ] && [ $((now - ws)) -gt 172800 ]; then
    echo "⚠️ prompt-history: INBOX 反映が 48h 以上成功していません (writer 停止 or Obsidian Git 同期停止の疑い)。tail $LOG で確認"
  fi
fi

# 日次スタンプ (20h 未満なら skip・weekly-metrics-archive.sh の型)
if [ -f "$STAMP" ]; then
  last=$(stat -f %m "$STAMP" 2>/dev/null || stat -c %Y "$STAMP" 2>/dev/null)
  [ -n "$last" ] && [ $((now - last)) -lt 72000 ] && exit 0
fi
touch "$STAMP"

# バックグラウンドで反映 (セッション起動をブロックしない・fail-open)
( /usr/bin/python3 "$HOME/.claude/scripts/prompt-history-reflect.py" >> "$LOG" 2>&1 ) &

exit 0
