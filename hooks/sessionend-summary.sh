#!/usr/bin/env bash
# SessionEnd hook: セッション終了時にメトリクスをログ。
# 目的: env-factcheck スキルと連携し、セッション単位の集計を後で取れるようにする。
# stdoutは出さない（ユーザ可視性は低くてよい、監査用）。

set -euo pipefail

input=$(cat 2>/dev/null || echo "{}")

LOG_DIR="$HOME/.claude/state"
LOG="$LOG_DIR/session-ends.jsonl"
mkdir -p "$LOG_DIR" 2>/dev/null || true

session_id=$(echo "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get("session_id",""))
except Exception:
    print("")' 2>/dev/null || echo "")

cwd=$(echo "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get("cwd",""))
except Exception:
    print("")' 2>/dev/null || echo "")

ts=$(date -Iseconds 2>/dev/null || date)

# JSONLレコード（1行1レコード）
printf '{"ts":"%s","event":"session_end","session_id":"%s","cwd":"%s"}\n' \
  "$ts" "$session_id" "$cwd" >> "$LOG" 2>/dev/null || true

exit 0
