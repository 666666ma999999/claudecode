#!/bin/bash
# claude-safe-update.sh — Claude Code を「セッションが動いていない時だけ」自動更新する
# 背景: 2026-07-08 セッション実行中の自動更新でバイナリ差し替え → macOS の Documents 権限の
#       紐付けが切れ vault 書込不能になった事故の再発防止。
#       組込みの自動更新は DISABLE_AUTOUPDATER=1 で止め、更新はこのジョブに一本化する。
# 起動: launchd (com.masa.claude-safe-update) が毎朝 5:00 に実行
# 安全弁: claude プロセスが 1 つでも動いていたら更新せずスキップ（翌日再試行）

set -u
LOG="$HOME/.claude/logs/claude-safe-update.log"
mkdir -p "$(dirname "$LOG")"
NPM_BIN="$HOME/.nvm/versions/node/v22.18.0/bin"
export PATH="$NPM_BIN:/usr/local/bin:/usr/bin:/bin"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# 安全弁: 実行中の claude セッションがあれば何もしない
if pgrep -x claude >/dev/null 2>&1; then
    echo "[$(ts)] SKIP: claude セッション実行中（$(pgrep -x claude | wc -l | tr -d ' ') プロセス）" >> "$LOG"
    exit 0
fi

BEFORE=$("$NPM_BIN/npm" ls -g @anthropic-ai/claude-code --depth=0 2>/dev/null | grep -o '@anthropic-ai/claude-code@[0-9.]*' | head -1)
if "$NPM_BIN/npm" install -g @anthropic-ai/claude-code@latest >> "$LOG" 2>&1; then
    AFTER=$("$NPM_BIN/npm" ls -g @anthropic-ai/claude-code --depth=0 2>/dev/null | grep -o '@anthropic-ai/claude-code@[0-9.]*' | head -1)
    if [ "$BEFORE" = "$AFTER" ]; then
        echo "[$(ts)] OK: 最新のまま（$AFTER）" >> "$LOG"
    else
        echo "[$(ts)] UPDATED: $BEFORE → $AFTER" >> "$LOG"
    fi
else
    echo "[$(ts)] FAIL: npm install 失敗（ネットワーク等）。翌日再試行" >> "$LOG"
fi

# ログ肥大防止（最新 500 行だけ残す）
tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
