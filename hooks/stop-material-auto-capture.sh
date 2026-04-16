#!/bin/bash
# Stop hook: セッション終了時に会話から X素材を自動抽出
# 非ブロック: background で scanner を fork し即 exit 0
# stdout 出力禁止（decision JSON として解釈されるため）

INPUT=$(cat)

STATE_DIR="$HOME/.claude/state"
SCRIPTS_DIR="$HOME/.claude/hooks/scripts"
SCANNER="$SCRIPTS_DIR/transcript-scanner.py"
RATE_LIMITER="$STATE_DIR/auto-capture-last-run"
LOG="$STATE_DIR/auto-capture.log"

# scanner が存在しなければ即終了
[ ! -f "$SCANNER" ] && exit 0

# transcript_path と cwd を抽出
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

# transcript が存在しなければ終了
[ -z "$TRANSCRIPT_PATH" ] && exit 0
[ ! -f "$TRANSCRIPT_PATH" ] && exit 0

# stop_hook_active チェック（再入防止）
STOP_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active',False))" 2>/dev/null)
[ "$STOP_ACTIVE" = "True" ] && exit 0

# レートリミッター: 60秒以内の再実行を防止
if [ -f "$RATE_LIMITER" ]; then
    LAST_RUN=$(stat -f %m "$RATE_LIMITER" 2>/dev/null || stat -c %Y "$RATE_LIMITER" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    if [ $((NOW - LAST_RUN)) -lt 60 ]; then
        exit 0
    fi
fi

# レートリミッター更新
mkdir -p "$STATE_DIR"
touch "$RATE_LIMITER"

# Background で scanner を fork（stdout は log へリダイレクト、stderr も）
nohup python3 "$SCANNER" "$TRANSCRIPT_PATH" "$CWD" >> "$LOG" 2>&1 &
disown

exit 0
