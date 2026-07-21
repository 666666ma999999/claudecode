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

  # step 1b: 検索履歴 index.db の増分取込み（冪等・2026-07-21 追加: 18日stale＋未スケジュールが検索棚卸し不能の真因だった）
  echo "--- step 1b: ingest-jsonl-to-sqlite.py ---"
  "$PY" "$HOME_DIR/.claude/scripts/ingest-jsonl-to-sqlite.py" \
    || echo "[warn] ingest-jsonl-to-sqlite exit=$?"

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
        # (a)節はホスト別ブロック `<!-- jobhost:<host> -->` に分かれている（2026-07-21）。
        # 自機ブロックだけを見て通知する＝他機の🔴で叩き起こされない。旧書式（ブロック無し）の
        # ファイルが残っている間は、従来どおり H1 の「定期ジョブ🔴=N件 @host」で判定する。
        ME=$(hostname)
        OWN=$(awk -v h="$ME" 'index($0,"<!-- jobhost:"h" -->"){f=1;next} index($0,"<!-- /jobhost:"h" -->"){f=0} f' "$CH")
        NOTIFY=1
        if [ -n "${OWN:-}" ]; then
          RED_N=$(printf '%s\n' "$OWN" | grep -cE '^\| 🔴 ' | head -1)
          RED_JOBS=$(printf '%s\n' "$OWN" | grep -E '^\| 🔴 \| `com\.' | sed -E 's/^\| 🔴 \| `([^`]+)`.*/\1/' | head -5 | tr '\n' ' ')
          SCOPE="このMac"
        else
          RED_N=$(grep -oE '定期ジョブ🔴=([0-9]+)件' "$CH" | grep -oE '[0-9]+' | head -1)
          RED_JOBS=$(grep -E '^\| 🔴 \| `com\.' "$CH" | sed -E 's/^\| 🔴 \| `([^`]+)`.*/\1/' | head -5 | tr '\n' ' ')
          CH_HOST=$(grep -oE '定期ジョブ🔴=[0-9]+件 @[^)]+' "$CH" | sed -E 's/.*@//' | head -1)
          # 他機分はデスクトップ通知しない（2026-07-21 ユーザー判断: 自機から対処不可能な
          # 通知はノイズ）。ただし握り潰さず、ログには必ず1行残す（fail-loud 維持）。
          # 生成ホストが読めない場合は「他機と断定できない」ので通知する側に倒す。
          # CH_NOTIFY_OTHER=1 で他機分も通知する運用に戻せる。
          if [ -z "${CH_HOST:-}" ]; then
            SCOPE="生成ホスト不明(旧書式)"
          elif [ "$CH_HOST" = "$ME" ]; then
            SCOPE="このMac(旧書式)"
          else
            SCOPE="他機 $CH_HOST — 自機では対処不可"
            [ "${CH_NOTIFY_OTHER:-0}" = "1" ] || NOTIFY=0
          fi
        fi
        if [ -n "${RED_N:-}" ] && [ "$RED_N" -gt 0 ]; then
          if [ "$NOTIFY" = "1" ]; then
            osascript -e "display notification \"$RED_JOBS\" with title \"定期ジョブ🔴 ${RED_N}件（${SCOPE}）\"" 2>/dev/null || true
            echo "[notify] 定期ジョブ🔴 ${RED_N}件 (${SCOPE}) 通知: $RED_JOBS"
          else
            echo "[notify-skip] 定期ジョブ🔴 ${RED_N}件 (${SCOPE}) 通知抑止(CH_NOTIFY_OTHER=1 で有効化): $RED_JOBS"
          fi
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
