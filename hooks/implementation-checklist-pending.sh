#!/bin/bash
# PostToolUse hook: Write/Edit でコードファイルを変更したらpending状態を作成
# implementation-checklist スキル実行前にユーザーへ報告することを防止する警告を出す

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"

# Write/Edit以外は無視
case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# ファイルパスがない場合は無視
[ -z "$FILE_PATH" ] && exit 0

# ~/.claude/ 配下（memory, settings, skills, hooks, rules）は除外
case "$FILE_PATH" in
    */.claude/*) exit 0 ;;
esac

# コードファイルかどうか判定（実行コードのみ対象）
case "$FILE_PATH" in
    *.py|*.js|*.ts|*.tsx|*.jsx|*.html|*.css|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini)
        ;;
    *)
        # コードファイル以外（.md等）は除外
        exit 0
        ;;
esac

# ドキュメントファイルは除外
case "$FILE_PATH" in
    *.md|*.rst|*.txt)
        exit 0
        ;;
esac

# state ディレクトリ確保
STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

PENDING_FILE="$STATE_DIR/implementation-checklist.pending"

# pending ファイルに変更ファイルを追記（重複排除）
if [ -f "$PENDING_FILE" ]; then
    if ! grep -qF "$FILE_PATH" "$PENDING_FILE" 2>/dev/null; then
        echo "$FILE_PATH" >> "$PENDING_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$PENDING_FILE"
    echo "$FILE_PATH" >> "$PENDING_FILE"
fi

# 警告を出力（Claude の会話コンテキストに入る）
echo "⚠️ IMPLEMENTATION CHECKLIST PENDING: コード変更検出 ($FILE_PATH)。ユーザーへの報告前に implementation-checklist スキルを実行すること。"
