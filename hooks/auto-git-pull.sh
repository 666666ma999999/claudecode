#!/bin/bash
# セッション開始時に git リポジトリを pull

# 1. カレントディレクトリがgitリポジトリの場合、pull
if [ -d ".git" ]; then
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        echo "info: skipping pull (no upstream tracking branch)"
    elif ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "info: skipping pull (unstaged/staged changes present)"
    else
        git pull --rebase --no-edit 2>&1 | head -5
    fi
fi

# 2. ~/.claude/ を pull（バックグラウンド）
(cd ~/.claude 2>/dev/null && git pull --rebase --no-edit &>/dev/null) &

exit 0
