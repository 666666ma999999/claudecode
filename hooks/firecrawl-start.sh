#!/bin/bash
# Firecrawl Docker auto-start (SessionStart hook)
# disabledMcpjsonServersに含まれていればスキップ
SETTINGS="${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"
if python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS'))
    if 'firecrawl' in d.get('disabledMcpjsonServers', []):
        sys.exit(0)
    sys.exit(1)
except: sys.exit(1)
" 2>/dev/null; then
  exit 0
fi

# Docker 判定・compose 判定・起動をすべて BG で実行
# (同期実行だと SessionStart が ~712ms 遅延するため)
(
  if ! docker info >/dev/null 2>&1; then
    exit 0
  fi
  cd ~/.claude/firecrawl 2>/dev/null || exit 0
  if docker compose ps --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
    exit 0
  fi
  docker compose up -d >/dev/null 2>&1
) &
