#!/usr/bin/env bash
# SubagentStop hook: SubAgent完了時に main agent への検証リマインダーを出す。
# CLAUDE.md「SubAgent強制ルール: メインは統合・意思決定のみ」の運用担保。
# stdoutは参考情報レベルで最小限に抑える（ノイズ回避）。

set -euo pipefail

input=$(cat 2>/dev/null || echo "{}")

# ログ記録（監査用）
LOG_DIR="$HOME/.claude/state"
LOG="$LOG_DIR/subagent-stops.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

ts=$(date -Iseconds 2>/dev/null || date)
# 入力の先頭 300文字だけログ（PII回避）
snippet=$(echo "$input" | head -c 300 | tr '\n' ' ')
echo "[$ts] $snippet" >> "$LOG" 2>/dev/null || true

# SubAgentがWrite/Editを実行した痕跡があるか判定
if echo "$input" | grep -qE '"(Write|Edit|NotebookEdit)"'; then
  echo "【SubAgent Verify】SubAgentがファイルを編集した形跡あり。Trust-but-verifyに従い、差分を実ファイルで確認してから完了報告すること（CLAUDE.md「動作を証明できるまでタスクを完了とマークしない」）。"
fi

exit 0
