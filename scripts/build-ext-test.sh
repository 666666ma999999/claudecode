#!/bin/bash
# claude-ext テスト + ビルド + 状態確認
set -euo pipefail

echo "=== テスト ==="
cd /Users/masaaki_nagasawa/.claude/extensions/_build_tool
/tmp/claude-ext-venv/bin/pytest --tb=no -q 2>&1

echo ""
echo "=== ビルド ==="
/tmp/claude-ext-venv/bin/claude-ext build --force 2>&1 | grep -E "^\(Build|  \+\)"

echo ""
echo "=== CLAUDE.md ==="
wc -l /Users/masaaki_nagasawa/.claude/CLAUDE.md

echo ""
echo "=== 生成ルール ==="
ls -1 /Users/masaaki_nagasawa/.claude/rules/*.md
