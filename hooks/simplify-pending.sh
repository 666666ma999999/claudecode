#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイル変更時に simplify 要フラグを更新
# カウンタをインクリメントし、Stop hook の収束検知に使用する
# NOTE: stdout 出力なし（implementation-checklist-pending.sh が警告を担当）

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Write/Edit 以外は無視
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# ファイルパスがない場合は無視
[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下は除外（設定・スキル・フック等の編集は simplify 対象外）
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルのみ（config/data ファイルは simplify 対象外）
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.go|*.rs|*.rb|*.java|*.html|*.css) ;;
    *) exit 0 ;;
esac

STATE_DIR="$HOME/.claude/state"
PENDING="$STATE_DIR/needs-simplify.pending"

# カウンタインクリメント
COUNT=0
[ -f "$PENDING" ] && COUNT=$(cat "$PENDING" 2>/dev/null | tr -d '[:space:]')
COUNT=$((COUNT + 1))
echo "$COUNT" > "$PENDING"

exit 0
