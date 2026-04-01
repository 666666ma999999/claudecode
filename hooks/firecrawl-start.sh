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

# Dockerが起動していなければスキップ
if ! docker info >/dev/null 2>&1; then
  exit 0
fi

cd ~/.claude/firecrawl 2>/dev/null || exit 0

# 既に起動中ならスキップ
if docker compose ps --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
  exit 0
fi

# バックグラウンドで起動（Claude Code起動を遅延させない）
docker compose up -d >/dev/null 2>&1 &
