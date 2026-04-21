#!/usr/bin/env bash
# diff.sh — 前週 harvest JSONL と今回の差分を表示
#
# Usage: diff.sh <TOPIC> <CURRENT_JSONL>
#   ex:  diff.sh claude-code ~/.claude/metrics/gh-stars/2026-04-28_claude-code.jsonl

set -uo pipefail

TOPIC="${1:-}"
CURRENT="${2:-}"

if [[ -z "$TOPIC" || -z "$CURRENT" || ! -f "$CURRENT" ]]; then
  echo "[diff] skip (引数不足 or current file missing)" >&2
  exit 0
fi

OUTDIR="$(dirname "$CURRENT")"

# 7日前の日付（macOS/Linux両対応）
if date -v-7d +%Y-%m-%d >/dev/null 2>&1; then
  PREV_DATE=$(date -v-7d +%Y-%m-%d)
else
  PREV_DATE=$(date -d "7 days ago" +%Y-%m-%d)
fi

PREV="$OUTDIR/${PREV_DATE}_${TOPIC}.jsonl"

if [[ ! -f "$PREV" ]]; then
  echo "=== 前週比較 ==="
  echo "⚠️  前週ファイルなし: $PREV"
  echo "   初回実行か、直近7日に $TOPIC のharvestが無い。"
  exit 0
fi

echo "=== 前週比較 ($PREV_DATE → $(date +%Y-%m-%d)) ==="

python3 - "$PREV" "$CURRENT" <<'PYEOF'
import json, sys
from collections import OrderedDict

prev_path, cur_path = sys.argv[1], sys.argv[2]

def load(path):
    d = OrderedDict()
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
                d[r["full_name"]] = r
            except (json.JSONDecodeError, KeyError):
                pass
    return d

prev, cur = load(prev_path), load(cur_path)
prev_keys, cur_keys = set(prev), set(cur)

new_repos = cur_keys - prev_keys
gone_repos = prev_keys - cur_keys
common = cur_keys & prev_keys

print(f"🆕 新規登場: {len(new_repos)}件 / 📉 圏外: {len(gone_repos)}件 / 継続: {len(common)}件")

if new_repos:
    print("\n🆕 新規Top5:")
    sorted_new = sorted(
        [cur[k] for k in new_repos],
        key=lambda r: r.get("stargazers_count", 0),
        reverse=True,
    )[:5]
    for r in sorted_new:
        desc = (r.get("description") or "")[:55]
        print(f"  {r['stargazers_count']:6d}★  {r['full_name']}")
        print(f"         {desc}")

# star急増Top5
deltas = []
for k in common:
    d = cur[k].get("stargazers_count", 0) - prev[k].get("stargazers_count", 0)
    if d > 0:
        deltas.append((d, cur[k]))
deltas.sort(key=lambda x: x[0], reverse=True)

if deltas:
    print(f"\n📈 star急増Top5 (+delta):")
    for d, r in deltas[:5]:
        desc = (r.get("description") or "")[:50]
        print(f"  +{d:5d}  {r['stargazers_count']:6d}★  {r['full_name']}")
        print(f"         {desc}")
PYEOF
