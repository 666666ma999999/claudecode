#!/bin/bash
# ~/.claude/hooks/sessionstart-prime-ad-daily-unread.sh
#
# SessionStart hook: cwd が ~/Desktop/prm/prime_suite/ 配下のとき、
# 日次 scripts_export と「最後にレビューした日」の乖離を warning として注入する。
#
# 目的: 5/12 月次データで判断したまま 5/13-17 日次 6 日分を読まずに 5/18 判断する
#       ようなドリフトを SessionStart で必ず目につく形にする (read path 強制)。
#
# 設計 (codex review 推奨案 🥇 「未読検知」採用):
#   - 比較対象: scripts_export 最新日 vs phase-tracker.md mtime (= 最後の review 痕跡)
#   - phase-tracker.md が「日次データを反映した」マーカー代わり
#   - vault MOC は触らない (write path automation でなく read path enforcement)
#   - cwd が prime_suite 配下のみ発火・他プロジェクトでは silent exit

# stdin (JSON) を読み捨て
cat > /dev/null 2>&1

PRIME_DIR="$HOME/Desktop/prm/prime_suite"
SCRIPTS_EXPORT_DIR="$PRIME_DIR/prime_ad/data/raw/google_ads/scripts_export"
REVIEW_MARKER="$PRIME_DIR/prime_ad/tasks/phase-tracker.md"

# cwd を物理パスに正規化
CWD="$(pwd -P 2>/dev/null)"
[ -z "$CWD" ] && exit 0

PRIME_PHYS="$(cd "$PRIME_DIR" 2>/dev/null && pwd -P)"
[ -z "$PRIME_PHYS" ] && exit 0

# cwd が prime_suite 配下か (case-insensitive on macOS)
cwd_lower="$(echo "$CWD" | tr '[:upper:]' '[:lower:]')"
prime_lower="$(echo "$PRIME_PHYS" | tr '[:upper:]' '[:lower:]')"
if [[ "$cwd_lower/" != "$prime_lower/"* ]] && [[ "$cwd_lower" != "$prime_lower" ]]; then
  exit 0
fi

# scripts_export ディレクトリがなければ silent exit (パイプライン未稼働)
[ -d "$SCRIPTS_EXPORT_DIR" ] || exit 0

# 最新の YYYY-MM-DD ディレクトリを取得
LATEST_DATE="$(ls -1 "$SCRIPTS_EXPORT_DIR" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort -r | head -1)"
[ -z "$LATEST_DATE" ] && exit 0

# phase-tracker.md の mtime 日 (YYYY-MM-DD)
REVIEW_DATE=""
if [ -f "$REVIEW_MARKER" ]; then
  REVIEW_DATE="$(stat -f %Sm -t %Y-%m-%d "$REVIEW_MARKER" 2>/dev/null)"
fi

# 比較 (string sort で OK・YYYY-MM-DD)
TODAY="$(date +%Y-%m-%d)"

# 未読日のリスト (review_date より新しい export ディレクトリ)
UNREAD_DATES=""
if [ -n "$REVIEW_DATE" ]; then
  UNREAD_DATES="$(ls -1 "$SCRIPTS_EXPORT_DIR" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | awk -v rd="$REVIEW_DATE" '$0 > rd' | sort)"
else
  UNREAD_DATES="$LATEST_DATE"
fi

if [ -z "$UNREAD_DATES" ]; then
  UNREAD_COUNT=0
else
  UNREAD_COUNT=$(printf '%s\n' "$UNREAD_DATES" | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
fi

# 未読 0 件かつ最新 = 今日なら silent exit (健全状態)
if [ "$UNREAD_COUNT" -eq 0 ] && [ "$LATEST_DATE" = "$TODAY" ]; then
  exit 0
fi

# 出力
{
  echo "=== 📊 prime_ad 日次データ未読チェック ==="
  echo "最新 scripts_export: $LATEST_DATE"
  if [ "$LATEST_DATE" != "$TODAY" ]; then
    echo "⚠️ 本日 ($TODAY) の export なし → Ads Scripts / launchd / Gmail 取得が止まっている可能性"
  fi
  if [ -n "$REVIEW_DATE" ]; then
    echo "phase-tracker.md 最終更新: $REVIEW_DATE"
  fi
  if [ "$UNREAD_COUNT" -gt 0 ]; then
    echo ""
    echo "🔴 未読の日次データ ($UNREAD_COUNT 日分):"
    echo "$UNREAD_DATES" | sed 's/^/  - /'
    echo ""
    echo "👉 アクション: 最新の campaign_*.csv を読んで判断/更新後、phase-tracker.md を touch (= レビュー済マーク)"
    echo "  例: head $SCRIPTS_EXPORT_DIR/$LATEST_DATE/campaign_$LATEST_DATE.csv"
  fi
}

exit 0
