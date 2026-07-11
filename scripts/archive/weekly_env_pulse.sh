#!/usr/bin/env bash
# Weekly env pulse: ローカル FS 観測のみ。ネット取得しない (news collector と重複回避)
# 設計経緯: Codex + Agent Team 12 ラウンド議論で Skeleton として収束 (2026-05-13)

set -uo pipefail
PULSE="$HOME/.claude/state/env_pulse.jsonl"
mkdir -p "$(dirname "$PULSE")"

WEEK=$(date +%Y-W%V)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 過去 7 日に作成/更新された git repo (Desktop / Documents 配下、深さ 3)
NEW_REPOS=$(find "$HOME/Desktop" "$HOME/Documents" -maxdepth 4 -name ".git" -type d -mtime -7 2>/dev/null \
  | sed 's|/\.git$||' | sort -u)
NEW_REPO_COUNT=$(printf '%s\n' "$NEW_REPOS" | grep -c . || echo 0)

# ~/.claude/projects/ で 7 日内 mtime のセッションディレクトリ数
ACTIVE_SESSIONS=$(find "$HOME/.claude/projects" -maxdepth 1 -type d -mtime -7 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')

# launchctl 死活: masa 系の plist が読み込まれているか
LAUNCHD_OK=$(launchctl list 2>/dev/null | grep -c "com.masa" || echo 0)

# flag 判定: 新 repo 2 件以上 OR launchd 死活変化 (前回値比較は次フェーズ、初回は raw 値のみ)
FLAG="info"
[ "$NEW_REPO_COUNT" -ge 2 ] && FLAG="actionable"

# JSONL 1 行 append
python3 -c "
import json, sys, os
repos = '''$NEW_REPOS'''.strip().split('\n') if '''$NEW_REPOS'''.strip() else []
print(json.dumps({
    'week': '$WEEK',
    'ts': '$TS',
    'new_repos': repos,
    'new_repo_count': $NEW_REPO_COUNT,
    'active_sessions_7d': $ACTIVE_SESSIONS,
    'launchd_masa_count': $LAUNCHD_OK,
    'flag': '$FLAG'
}, ensure_ascii=False))
" >> "$PULSE"

# 過去 4 週超は archive
ARCHIVE="$HOME/.claude/state/env_pulse_archive.jsonl"
if [ "$(wc -l < "$PULSE")" -gt 4 ]; then
  head -n -4 "$PULSE" >> "$ARCHIVE" 2>/dev/null || true
  tail -n 4 "$PULSE" > "${PULSE}.tmp" && mv "${PULSE}.tmp" "$PULSE"
fi
