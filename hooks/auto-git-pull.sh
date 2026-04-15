#!/bin/bash
# セッション開始時に git リポジトリを pull (BG 実行でブロッキング回避)
# エラーはログに記録、多重起動は flock で防止

LOG_DIR="$HOME/.claude/state"
LOG_FILE="$LOG_DIR/auto-git-pull.log"
LOCK_FILE="$LOG_DIR/auto-git-pull.lock"
mkdir -p "$LOG_DIR"

# 前回失敗ログがあれば冒頭で表示 (古いログは自動削除)
if [ -s "$LOG_FILE" ]; then
    echo "warn: 前回 pull でエラー発生:"
    tail -3 "$LOG_FILE"
    rm -f "$LOG_FILE"
fi

# 1. カレントディレクトリがgitリポジトリの場合、BG で pull
if [ -d ".git" ]; then
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        echo "info: skipping pull (no upstream tracking branch)"
    elif ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "info: skipping pull (unstaged/staged changes present)"
    else
        (
            exec 9>"$LOCK_FILE.cwd"
            if command -v flock >/dev/null 2>&1; then
                flock -n 9 || exit 0
            fi
            git pull --ff-only >>"$LOG_FILE" 2>&1
        ) &
    fi
fi

# 2. ~/.claude/ を pull（バックグラウンド）
(
    exec 9>"$LOCK_FILE.claude"
    if command -v flock >/dev/null 2>&1; then
        flock -n 9 || exit 0
    fi
    cd ~/.claude 2>/dev/null && git pull --ff-only >>"$LOG_FILE" 2>&1
) &

exit 0
