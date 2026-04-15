#!/bin/bash
# セッション開始時に git リポジトリを pull (BG 実行でブロッキング回避)
# エラーはログに記録、多重起動は flock で防止

LOG_DIR="$HOME/.claude/state"
LOG_FILE="$LOG_DIR/auto-git-pull.log"
LOCK_FILE="$LOG_DIR/auto-git-pull.lock"
mkdir -p "$LOG_DIR"

# 前回エラーログがあれば冒頭で表示 (成功時は書き込まないので、残っている=実エラー)
if [ -s "$LOG_FILE" ]; then
    echo "warn: 前回 pull でエラー発生:"
    tail -3 "$LOG_FILE"
    rm -f "$LOG_FILE"
fi

# ロック取得ヘルパ: mkdir はクロスプラットフォームでアトミック
# (macOS に flock がないため mkdir-based lock を採用)
# .git/index.lock も事前チェックして二重防御
# pull 成功時はログに書かず、エラー時のみ LOG_FILE に記録する
acquire_lock_and_pull() {
    local lock_dir="$1"
    local git_dir="$2"  # .git のパス
    if [ -f "$git_dir/index.lock" ]; then
        return 0  # 他 git 操作が進行中、skip
    fi
    if ! mkdir "$lock_dir" 2>/dev/null; then
        return 0  # 他 Claude セッションがロック中、skip
    fi
    trap "rmdir '$lock_dir' 2>/dev/null" EXIT
    local tmp_out; tmp_out=$(mktemp)
    if git pull --ff-only >"$tmp_out" 2>&1; then
        rm -f "$tmp_out"  # 成功時はログを残さない
    else
        cat "$tmp_out" >>"$LOG_FILE"
        rm -f "$tmp_out"
    fi
}

# 1. カレントディレクトリがgitリポジトリの場合、BG で pull
if [ -d ".git" ]; then
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        echo "info: skipping pull (no upstream tracking branch)"
    elif ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo "info: skipping pull (unstaged/staged changes present)"
    else
        echo "info: git pull running in background (log: ~/.claude/state/auto-git-pull.log)"
        (acquire_lock_and_pull "$LOCK_FILE.cwd.d" ".git") &
    fi
fi

# 2. ~/.claude/ を pull（バックグラウンド）
echo "info: ~/.claude pull running in background"
(
    cd ~/.claude 2>/dev/null || exit 0
    acquire_lock_and_pull "$LOCK_FILE.claude.d" ".git"
) &

exit 0
