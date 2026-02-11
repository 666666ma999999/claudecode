#!/bin/bash
# Firecrawl Docker auto-start (SessionStart hook)
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
