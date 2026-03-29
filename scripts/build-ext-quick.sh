#!/bin/bash
# claude-ext クイックビルド（警告付き）
set -euo pipefail

cd /Users/masaaki_nagasawa/.claude
/tmp/claude-ext-venv/bin/claude-ext build --force 2>&1 | grep -E "^\(Build|WARNING\)" | head -5
echo "..."
/tmp/claude-ext-venv/bin/claude-ext build --force 2>&1 | tail -1
