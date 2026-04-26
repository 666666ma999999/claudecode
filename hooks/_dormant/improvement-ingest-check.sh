#!/bin/bash
# SessionStart: 取込待ち件数を通知

DB="$HOME/.claude/state/improvement.db"
QUEUE="$HOME/.claude/state/improvement-queue.jsonl"

# SQLite 1コマンド: 無効DB/テーブル欠損/プロセス失敗は空文字→数値ガードでJSONL fallback
PENDING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM improvements WHERE status='pending_ingest';" 2>/dev/null)

if ! [[ "$PENDING" =~ ^[0-9]+$ ]]; then
    # JSONL fallback
    if [ -f "$QUEUE" ] && [ -s "$QUEUE" ]; then
        PENDING=$(grep -cE '"status"\s*:\s*"pending_ingest"' "$QUEUE" 2>/dev/null)
        PENDING=${PENDING:-0}
    else
        PENDING=0
    fi
fi

if [ "$PENDING" -gt 0 ]; then
    echo "Material Bank取込待ち: ${PENDING}件の改善素材があります。/ingest-improvements で取り込み、記事候補を提案します。"
fi

exit 0
