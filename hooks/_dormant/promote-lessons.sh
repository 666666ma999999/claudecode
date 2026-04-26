#!/bin/bash
# PreCompact hook: task.mdから学びを抽出し、lessons.mdとmemoryに昇格候補を生成
# stdout出力なし（圧縮を妨げない）

INPUT=$(cat)

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
PROMOTE_LOG="$STATE_DIR/promote-lessons.log"

# タイムスタンプ
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# --- task.md から学びセクションを抽出 ---
LESSONS_FOUND=""

for candidate in tasks/*.md task.md; do
  [ -f "$candidate" ] || continue

  # Decision Log セクション抽出
  DECISIONS=$(sed -n '/## Decision Log/,/^## [^D]/{/^## [^D]/d;p;}' "$candidate" 2>/dev/null | grep -v '^\s*$' | head -10)

  # Failures / Stuck Context セクション抽出
  FAILURES=$(sed -n '/## Failures/,/^## [^F]/{/^## [^F]/d;p;}' "$candidate" 2>/dev/null | grep -v '^\s*$' | head -10)
  [ -z "$FAILURES" ] && FAILURES=$(sed -n '/## Stuck/,/^## [^S]/{/^## [^S]/d;p;}' "$candidate" 2>/dev/null | grep -v '^\s*$' | head -10)

  # Feedback セクション抽出
  FEEDBACK=$(sed -n '/## Feedback/,/^## [^F]/{/^## [^F]/d;p;}' "$candidate" 2>/dev/null | grep -v '^\s*$' | head -10)

  if [ -n "$DECISIONS" ] || [ -n "$FAILURES" ] || [ -n "$FEEDBACK" ]; then
    LESSONS_FOUND="yes"

    # tasks/lessons.md に追記候補を生成
    LESSONS_DIR="tasks"
    [ -d "$LESSONS_DIR" ] || LESSONS_DIR="."
    LESSONS_FILE="$LESSONS_DIR/lessons.md"

    # 重複チェック: 既にlessons.mdに同内容があればスキップ
    NEEDS_APPEND=""

    if [ -n "$DECISIONS" ]; then
      FIRST_LINE=$(echo "$DECISIONS" | head -1 | sed 's/^[[:space:]-]*//' | cut -c1-40)
      if [ -f "$LESSONS_FILE" ] && grep -qF "$FIRST_LINE" "$LESSONS_FILE" 2>/dev/null; then
        : # already exists
      else
        NEEDS_APPEND="yes"
      fi
    fi

    if [ -n "$FAILURES" ]; then
      FIRST_LINE=$(echo "$FAILURES" | head -1 | sed 's/^[[:space:]-]*//' | cut -c1-40)
      if [ -f "$LESSONS_FILE" ] && grep -qF "$FIRST_LINE" "$LESSONS_FILE" 2>/dev/null; then
        : # already exists
      else
        NEEDS_APPEND="yes"
      fi
    fi

    if [ -n "$NEEDS_APPEND" ]; then
      {
        echo ""
        echo "## Session: $TIMESTAMP (from: $candidate)"
        [ -n "$DECISIONS" ] && echo "### Decisions" && echo "$DECISIONS"
        [ -n "$FAILURES" ] && echo "### Failures/Stuck" && echo "$FAILURES"
        [ -n "$FEEDBACK" ] && echo "### Feedback" && echo "$FEEDBACK"
      } >> "$LESSONS_FILE" 2>/dev/null

      echo "[$TIMESTAMP] Promoted lessons from $candidate to $LESSONS_FILE" >> "$PROMOTE_LOG"
    fi
  fi
done

if [ -z "$LESSONS_FOUND" ]; then
  echo "[$TIMESTAMP] No lessons found in task files" >> "$PROMOTE_LOG"
fi

# stdout出力なし
exit 0
