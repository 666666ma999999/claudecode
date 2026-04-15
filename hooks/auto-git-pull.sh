#!/bin/bash
# セッション開始時に git リポジトリを pull

# 1. カレントディレクトリがgitリポジトリの場合、BG で pull
# SessionStart をブロックしないよう、条件判定もサブシェル内で実行
if [ -d ".git" ]; then
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        echo "info: skipping pull (no upstream tracking branch)"
    elif ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "info: skipping pull (unstaged/staged changes present)"
    else
        (git pull --ff-only &>/dev/null) &
    fi
fi

# 2. ~/.claude/ を pull（バックグラウンド）
(cd ~/.claude 2>/dev/null && git pull --ff-only &>/dev/null) &

exit 0
