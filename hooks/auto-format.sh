#!/bin/bash
# PostToolUse: 自動フォーマットフック（Docker-Only対応版）
# ファイル編集後に適切なフォーマッターを実行
# Docker Compose があれば docker exec 経由、なければ no-op

# stdin JSON から file_path を取得（新Hook API対応）
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # tool_input.file_path を優先
    ti = data.get('tool_input', {})
    print(ti.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# フォールバック: 環境変数
[ -z "$FILE_PATH" ] && FILE_PATH="$CLAUDE_FILE_PATH"

# ファイルが存在しない場合は終了
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# 拡張子を取得
EXT="${FILE_PATH##*.}"

# Docker Compose の検出
COMPOSE_CMD=""
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    if command -v docker &> /dev/null; then
        # docker compose (V2) を優先
        if docker compose version &> /dev/null 2>&1; then
            COMPOSE_CMD="docker compose exec -T dev"
        elif command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose exec -T dev"
        fi
    fi
fi

# Docker Compose がなければ no-op（Docker-Only方針に従い、ホストで直接実行しない）
if [ -z "$COMPOSE_CMD" ]; then
    exit 0
fi

# プロジェクトルートからの相対パスを計算
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REL_PATH=$(python3 -c "
import os, sys
try:
    full = os.path.abspath('$FILE_PATH')
    base = os.path.abspath('$PROJECT_ROOT')
    print(os.path.relpath(full, base))
except:
    print('')
" 2>/dev/null)

[ -z "$REL_PATH" ] && exit 0

# 拡張子に応じたフォーマッター実行（Docker内）
case "$EXT" in
    js|jsx|ts|tsx|json|css|scss|html|yaml|yml)
        $COMPOSE_CMD bash -lc "command -v prettier &>/dev/null && prettier --write '$REL_PATH' 2>/dev/null" 2>/dev/null || true
        ;;
    py)
        $COMPOSE_CMD bash -lc "command -v black &>/dev/null && black --quiet '$REL_PATH' 2>/dev/null || command -v autopep8 &>/dev/null && autopep8 --in-place '$REL_PATH' 2>/dev/null" 2>/dev/null || true
        ;;
    go)
        $COMPOSE_CMD bash -lc "command -v gofmt &>/dev/null && gofmt -w '$REL_PATH' 2>/dev/null" 2>/dev/null || true
        ;;
    rs)
        $COMPOSE_CMD bash -lc "command -v rustfmt &>/dev/null && rustfmt '$REL_PATH' 2>/dev/null" 2>/dev/null || true
        ;;
esac

exit 0
