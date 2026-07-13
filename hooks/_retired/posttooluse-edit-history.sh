#!/usr/bin/env bash
# posttooluse-edit-history.sh — PostToolUse hook
#
# 目的: Claude が触ったファイル (Edit/Write/MultiEdit/Read) を session 単位で記録
#       後段 userpromptsubmit-edit-recheck-warn.sh が参照し、
#       「自編集ファイル言及 + Read 履歴なし」を warning として注入する。
#
# 設計理由 (wiki/meta/mistakes.md「自編集ファイルの記憶過信」再発防止 (b) 改修):
# - 自分で Write/Edit したファイルを Read せず推測回答するパターンを機械検出するため
# - jsonl は session_id + tool + file_path のみ記録 (低コスト)

set -u

INPUT=$(cat 2>/dev/null || echo '{}')

TOOL=$(echo "$INPUT" | python3 -c "import json,sys
try: d=json.loads(sys.stdin.read())
except: d={}
print(d.get('tool_name',''))" 2>/dev/null)

FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys
try: d=json.loads(sys.stdin.read())
except: d={}
ti=d.get('tool_input',{}) or {}
print(ti.get('file_path','') or ti.get('notebook_path',''))" 2>/dev/null)

SESSION_ID=$(echo "$INPUT" | python3 -c "import json,sys
try: d=json.loads(sys.stdin.read())
except: d={}
print(d.get('session_id',''))" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

# Edit/Write 系 vs Read 系で別ファイルに記録
case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit)
    HISTORY_FILE="$STATE_DIR/edit-history.jsonl"
    ;;
  Read|NotebookRead)
    HISTORY_FILE="$STATE_DIR/read-history.jsonl"
    ;;
  *)
    exit 0
    ;;
esac

TIMESTAMP=$(python3 -c "from datetime import datetime; print(datetime.now().astimezone().isoformat(timespec='microseconds'))" 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')

# JSONL escape (file_path に " や \ が含まれる可能性に備える)
ESCAPED_FILE=$(printf '%s' "$FILE_PATH" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
ESCAPED_SESSION=$(printf '%s' "$SESSION_ID" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" 2>/dev/null)

echo "{\"ts\":\"$TIMESTAMP\",\"session\":$ESCAPED_SESSION,\"tool\":\"$TOOL\",\"file\":$ESCAPED_FILE}" >> "$HISTORY_FILE"

# rotate: 1000 行超なら直近 1000 行に切り詰め (低コスト・週次 cron 等不要)
LINES=$(wc -l < "$HISTORY_FILE" 2>/dev/null | tr -d ' ')
if [ "${LINES:-0}" -gt 1000 ]; then
  tail -1000 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
fi

exit 0
