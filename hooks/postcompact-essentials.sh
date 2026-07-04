#!/usr/bin/env bash
# SessionStart(matcher=compact) — auto-compact 直後に context-essentials.md を再注入する。
# 目的: compact で失われやすい「冒頭の重要事項」を即座に context へ戻す。

set -eu

ESSENTIALS="${HOME}/.claude/context-essentials.md"

if [ ! -f "${ESSENTIALS}" ]; then
  exit 0
fi

# stdout は SessionStart hook で context に注入される
echo "## [auto-compact 後 自動再注入] context-essentials.md"
echo ""
cat "${ESSENTIALS}"
echo ""
echo "---"
echo "_above injected by ~/.claude/hooks/postcompact-essentials.sh on $(date '+%Y-%m-%d %H:%M:%S')_"
