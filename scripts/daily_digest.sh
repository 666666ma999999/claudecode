#!/usr/bin/env bash
# Daily digest: collect_news.py を実行後、03_ClaudeEnv の official/drift catalog を再生成。
# launchd com.masa.claude-news-collect から呼ばれる (毎朝 08:00)。
#
# 注意: PATH を継がない環境で実行されるため絶対パス + python3 のフルパスを使う。

set -eu

PY=/usr/bin/python3
HOME_DIR="$HOME"
LOG_DIR="$HOME_DIR/.claude/state"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/daily_digest.log"
TS=$(date -Iseconds)

{
  echo "=== [$TS] daily_digest start ==="

  echo "--- step 1: collect_news.py ---"
  "$PY" "$HOME_DIR/.claude/scripts/collect_news.py" \
    --out-dir "$HOME_DIR/Documents/Obsidian Vault/.raw/news" \
    --state-db "$HOME_DIR/.claude/state/news_seen.sqlite" \
    --sources "$HOME_DIR/.claude/data/news_sources.yaml" \
    --health "$HOME_DIR/.claude/state/news_health.json" \
    || echo "[warn] collect_news.py exit=$?"

  # update_claudeenv.py は Vault がある場合のみ
  if [ -d "$HOME_DIR/Documents/Obsidian Vault/03_ClaudeEnv" ]; then
    echo "--- step 2: update_claudeenv.py --target official ---"
    "$PY" "$HOME_DIR/.claude/scripts/update_claudeenv.py" --target official \
      || echo "[warn] update_claudeenv official exit=$?"

    echo "--- step 3: update_claudeenv.py --target drift ---"
    "$PY" "$HOME_DIR/.claude/scripts/update_claudeenv.py" --target drift \
      || echo "[warn] update_claudeenv drift exit=$?"

    echo "--- step 4: update_claudeenv.py --target health ---"
    "$PY" "$HOME_DIR/.claude/scripts/update_claudeenv.py" --target health \
      || echo "[warn] update_claudeenv health exit=$?"

    # step 4b: 定期ジョブ 🔴 の能動通知（2026-07-21・x-buzz計測死活の型を全ジョブへ横展開）
    # 背景: collector-health.md に 🔴 が出ても誰も開かず放置される（prime_ad fetch が
    # 3日 stale で exit1 なのに未対応だった実例）。make_article heartbeat と同じく
    # 能動通知にする。CH_NOTIFY=0 で抑止可（手動再生成時のスパム回避）。
    if [ "${CH_NOTIFY:-1}" = "1" ]; then
      CH="$HOME_DIR/Documents/Obsidian Vault/03_ClaudeEnv/collector-health.md"
      if [ -f "$CH" ]; then
        RED_N=$(grep -oE '定期ジョブ🔴=([0-9]+)件' "$CH" | grep -oE '[0-9]+' | head -1)
        if [ -n "${RED_N:-}" ] && [ "$RED_N" -gt 0 ]; then
          RED_JOBS=$(grep -E '^\| 🔴 \| `com\.' "$CH" | sed -E 's/^\| 🔴 \| `([^`]+)`.*/\1/' | head -5 | tr '\n' ' ')
          osascript -e "display notification \"$RED_JOBS\" with title \"定期ジョブ🔴 ${RED_N}件（collector-health）\"" 2>/dev/null || true
          echo "[notify] 定期ジョブ🔴 ${RED_N}件 通知: $RED_JOBS"
        fi
      fi
    fi
  else
    echo "[skip] 03_ClaudeEnv not found, skip catalog refresh"
  fi

  echo "=== [$(date -Iseconds)] daily_digest end ==="
  echo ""
} >> "$LOG" 2>&1

exit 0
