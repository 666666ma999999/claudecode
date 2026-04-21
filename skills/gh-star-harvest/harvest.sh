#!/usr/bin/env bash
# gh-star-harvest — 直近N日間でstarを集めたGitHubリポを収集
#
# Usage:
#   harvest.sh [days] [topic] [min_stars]
#
# Examples:
#   harvest.sh                          # 直近7日, topic=claude-code, stars>50
#   harvest.sh 14 mcp 100               # 直近14日, topic=mcp, stars>100
#   harvest.sh 30 anthropic-claude 30

set -uo pipefail

DAYS=${1:-7}
TOPIC=${2:-claude-code}
MIN_STARS=${3:-50}

# 日付計算（macOS / Linux 両対応）
if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
  SINCE=$(date -v-${DAYS}d +%Y-%m-%d)
else
  SINCE=$(date -d "${DAYS} days ago" +%Y-%m-%d)
fi

OUTDIR="$HOME/.claude/metrics/gh-stars"
mkdir -p "$OUTDIR"
TODAY=$(date +%Y-%m-%d)
OUTFILE="$OUTDIR/${TODAY}_${TOPIC}.jsonl"

echo "==== gh-star-harvest ===="
echo "Period   : since ${SINCE} (${DAYS} days)"
echo "Topic    : ${TOPIC}"
echo "MinStars : ${MIN_STARS}"
echo "Output   : ${OUTFILE}"
echo ""

# API呼出（per_page=100が上限）
gh api -X GET "search/repositories" \
  -f q="topic:${TOPIC} created:>${SINCE} stars:>${MIN_STARS}" \
  -f sort=stars -f order=desc -f per_page=100 \
  --jq '.items[] | {
    full_name,
    stargazers_count,
    description,
    pushed_at,
    created_at,
    html_url,
    topics,
    language
  }' > "$OUTFILE"

COUNT=$(wc -l < "$OUTFILE" | tr -d ' ')
echo "✅ Collected: ${COUNT} repos"
echo ""

if [ "$COUNT" -eq 0 ]; then
  echo "⚠️  該当リポなし。topic か star 閾値を緩めて再実行を推奨。"
  exit 0
fi

echo "=== Top 10 by stars ==="
head -10 "$OUTFILE" | python3 -c "
import json, sys
for i, line in enumerate(sys.stdin, 1):
    d = json.loads(line)
    desc = (d.get('description') or '')[:60]
    print(f'{i:2d}. {d[\"stargazers_count\"]:6d}★  {d[\"full_name\"]}')
    print(f'     {desc}')
    print(f'     last-push: {d[\"pushed_at\"][:10]}  lang: {d.get(\"language\") or \"-\"}')
    print()
"

echo "=== 言語分布 ==="
python3 -c "
import json
from collections import Counter
c = Counter()
with open('$OUTFILE') as f:
    for line in f:
        d = json.loads(line)
        c[d.get('language') or '(none)'] += 1
for lang, n in c.most_common(10):
    print(f'  {n:3d}  {lang}')
"

echo ""
echo "次のアクション:"
echo "  - Material Bank 追加候補を抽出: Top 10 で description に記事テーマ該当"
echo "  - 前週比較: diff $OUTDIR/\$(date -v-7d +%Y-%m-%d)_${TOPIC}.jsonl $OUTFILE"
echo "  - X側でも収集: /fetch-engagement --urls-from-candidates"
