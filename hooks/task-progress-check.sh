#!/bin/bash
# ~/.claude/hooks/task-progress-check.sh
# SessionStart フック: 未完了タスクの検出とSession Handoff要約を表示

# stdin を消費（SessionStartフックの規約）
cat > /dev/null

# タスクファイルを検索
TASK_FILES=()

# tasks/*.md を検索
if [ -d "tasks" ]; then
  for f in tasks/*.md; do
    [ -f "$f" ] && TASK_FILES+=("$f")
  done
fi

# ルートの task.md を検索
[ -f "task.md" ] && TASK_FILES+=("task.md")

# タスクファイルがなければ終了
if [ ${#TASK_FILES[@]} -eq 0 ]; then
  exit 0
fi

OUTPUT=""
WARNINGS=""

for file in "${TASK_FILES[@]}"; do
  # Status行を取得
  STATUS=$(grep -A1 '| Status' "$file" 2>/dev/null | tail -1 | sed 's/.*| *\([a-z]*\).*/\1/' | tr -d ' ')

  # done なら スキップ
  if [ "$STATUS" = "done" ]; then
    continue
  fi

  # Session Handoff セクションを抽出
  START_HERE=$(sed -n '/### Start Here/,/### Avoid Repeating/{/### Start Here/d;/### Avoid Repeating/d;p;}' "$file" 2>/dev/null | head -3 | sed 's/^/  /')
  AVOID_REPEATING=$(sed -n '/### Avoid Repeating/,/### Key Evidence/{/### Avoid Repeating/d;/### Key Evidence/d;p;}' "$file" 2>/dev/null | head -3 | sed 's/^/  /')

  if [ -n "$STATUS" ]; then
    OUTPUT="${OUTPUT}📋 ${file} (Status: ${STATUS})\n"
    if [ -n "$START_HERE" ] && [ "$START_HERE" != "  " ]; then
      OUTPUT="${OUTPUT}  ▶ Start Here:\n${START_HERE}\n"
    fi
    if [ -n "$AVOID_REPEATING" ] && [ "$AVOID_REPEATING" != "  " ]; then
      OUTPUT="${OUTPUT}  ⚠ Avoid Repeating:\n${AVOID_REPEATING}\n"
    fi
  fi

  # Failures/Stuck Context が空かチェック
  FAILURES_CONTENT=$(sed -n '/## Failures.*Stuck/,/^## /{/## Failures/d;/^## /d;/^$/d;/^|.*---|/d;/^| #/d;p;}' "$file" 2>/dev/null | grep -v '^$' | head -1)

  if [ -z "$FAILURES_CONTENT" ] && [ "$STATUS" != "done" ] && [ -n "$STATUS" ]; then
    WARNINGS="${WARNINGS}⚠️  ${file}: Failures/Stuck Context が空です。前回の中断理由を記録してください\n"
  fi
done

# 出力
if [ -n "$OUTPUT" ] || [ -n "$WARNINGS" ]; then
  echo ""
  echo "=== 未完了タスク検出 ==="
  if [ -n "$OUTPUT" ]; then
    echo -e "$OUTPUT"
  fi
  if [ -n "$WARNINGS" ]; then
    echo -e "$WARNINGS"
  fi
  echo "========================"
fi

exit 0
