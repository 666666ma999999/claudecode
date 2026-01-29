#!/bin/bash
# PostToolUse: 自動フォーマットフック
# ファイル編集後に適切なフォーマッターを実行

FILE_PATH="$CLAUDE_FILE_PATH"

# ファイルが存在しない場合は終了
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# 拡張子を取得
EXT="${FILE_PATH##*.}"

# 拡張子に応じたフォーマッター実行
case "$EXT" in
    js|jsx|ts|tsx|json|css|scss|md|html|yaml|yml)
        if command -v prettier &> /dev/null; then
            prettier --write "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    py)
        if command -v black &> /dev/null; then
            black --quiet "$FILE_PATH" 2>/dev/null || true
        elif command -v autopep8 &> /dev/null; then
            autopep8 --in-place "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    go)
        if command -v gofmt &> /dev/null; then
            gofmt -w "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
    rs)
        if command -v rustfmt &> /dev/null; then
            rustfmt "$FILE_PATH" 2>/dev/null || true
        fi
        ;;
esac

exit 0
