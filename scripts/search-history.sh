#!/bin/bash
# search-history.sh — Search Claude Code JSONL history via SQLite FTS5.
#
# Usage:
#   search-history.sh "query text"               # FTS5 text search
#   search-history.sh --tool <name>              # tool_use frequency
#   search-history.sh --stats                    # daily message stats
#   search-history.sh --project <proj> <query>   # project-scoped

set -euo pipefail
DB="${HOME}/.claude/archives/index.db"
[ ! -f "$DB" ] && { echo "DB not found: $DB" >&2; echo "Run: python3 ~/.claude/scripts/ingest-jsonl-to-sqlite.py" >&2; exit 1; }

mode="${1:-}"
case "$mode" in
    --tool)
        tool="${2:?Usage: search-history.sh --tool <name>}"
        sqlite3 "$DB" -column -header \
            "SELECT date, COUNT(*) AS calls FROM messages WHERE tool_name='$tool' GROUP BY date ORDER BY date DESC LIMIT 30;"
        ;;
    --stats)
        sqlite3 "$DB" -column -header \
            "SELECT date, SUM(CASE WHEN role='user' THEN 1 ELSE 0 END) AS user_msgs, SUM(CASE WHEN role='assistant' THEN 1 ELSE 0 END) AS asst_msgs FROM messages GROUP BY date ORDER BY date DESC LIMIT 30;"
        ;;
    --project)
        proj="${2:?Usage: search-history.sh --project <proj> <query>}"
        query="${3:?}"
        sqlite3 "$DB" -column -header \
            "SELECT date, role, substr(content, 1, 80) AS snippet FROM messages WHERE project LIKE '%$proj%' AND id IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH '$query') ORDER BY date DESC LIMIT 20;"
        ;;
    --help|-h|"")
        grep '^#' "$0" | head -15
        ;;
    *)
        # FTS5 search
        query="$*"
        sqlite3 "$DB" -column -header \
            "SELECT date, project, substr(content, 1, 80) AS snippet FROM messages WHERE id IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH '$query') ORDER BY date DESC LIMIT 20;"
        ;;
esac
