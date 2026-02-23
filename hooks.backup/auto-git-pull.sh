#!/bin/bash
# セッション開始時に git リポジトリを pull

# 1. カレントディレクトリがgitリポジトリの場合、pull
if [ -d ".git" ]; then
    git pull --rebase --no-edit 2>&1 | head -5
fi

# 2. ~/.claude/ を pull（バックグラウンド）
(cd ~/.claude 2>/dev/null && git pull --rebase --no-edit &>/dev/null) &

exit 0
