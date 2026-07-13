#!/usr/bin/env bash
# claude-mem worker/observer の定期掃除 — observer 増殖 bound（2026-07-13 軽量化・1日4回）
# worker は次のセッション活動時に plugin hook が自動再起動する（lazy restart）
set -u
LOG="$HOME/.claude/logs/claude-mem-cleanup.log"
mkdir -p "$(dirname "$LOG")"
BEFORE=$(ps -eo command | grep -c "[s]tream-json.*disallowedTools Bash,Read,Write,Edit" || true)
# 1) worker の子（observer）を先に停止
PIDFILE="$HOME/.claude-mem/worker.pid"
[ -f "$PIDFILE" ] && pkill -P "$(cat "$PIDFILE")" 2>/dev/null
# 2) 公式 stop → daemon 残骸 → 孤児 observer（observer 固有の disallowedTools 全列挙パターンのみ・通常 subagent は殺さない）
WS=$(ls -d "$HOME"/.claude/plugins/cache/thedotmack/claude-mem/*/scripts/worker-service.cjs 2>/dev/null | tail -1)
[ -n "${WS:-}" ] && "$HOME/.bun/bin/bun" "$WS" stop >/dev/null 2>&1
sleep 2
pkill -f "worker-service.cjs --daemon" 2>/dev/null
pkill -f "disallowedTools Bash,Read,Write,Edit,Grep,Glob,WebFetch,WebSearch,Task,NotebookEdit" 2>/dev/null
AFTER=$(ps -eo command | grep -c "[s]tream-json.*disallowedTools Bash,Read,Write,Edit" || true)
echo "$(date '+%Y-%m-%dT%H:%M:%S%z') cleaned observers ${BEFORE}->${AFTER}" >> "$LOG"
tail -400 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"   # ログ上限キャップ
exit 0
