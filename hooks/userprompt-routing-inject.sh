#!/usr/bin/env bash
# UserPromptSubmit hook: プロンプトのキーワードを 30-routing.md と突き合わせ、
# 該当スキル行を stdout に出力して Claude の context に注入する。
# stdout は context に入るため、ノイズ防止のため明確な一致のみ出力。

set -euo pipefail

input=$(cat 2>/dev/null || echo "{}")
prompt=$(echo "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get("prompt") or d.get("user_prompt") or "")
except Exception:
    print("")' 2>/dev/null || echo "")

# 短すぎるプロンプト・空プロンプトはスキップ
[ -z "$prompt" ] && exit 0
[ "${#prompt}" -lt 12 ] && exit 0

ROUTING="$HOME/.claude/rules/30-routing.md"
[ ! -f "$ROUTING" ] && exit 0

# キーワード（日本語+英語）。プロンプトに含まれたら routing 表から該当行を抽出
keywords=(
  "デバッグ" "リファクタリング" "セキュリティ監査" "脆弱性"
  "KPI" "ダッシュボード" "可視化" "売上分析"
  "テスト修正" "test fixing"
  "スキル作成" "skill creator"
  "プロジェクト復帰" "catch up"
  "ブックマーク" "bookmark"
  "エンゲージメント" "engagement" "いいね数"
  "Playwright" "Firecrawl" "スクレイピング"
  "Codex" "Agent Teams" "SubAgent"
  "Plan mode" "新機能" "MVP"
  "Obsidian" "NOW→DONE"
  "gitコミット" "git push" "シークレット" "API鍵"
  "repomix" "コードベース調査"
  "Gmail" "Google Sheets" "スプレッドシート" "Docs"
)

# 最大表示件数
max_hits=4
hit_count=0
declare -A seen
output=""

for kw in "${keywords[@]}"; do
  if [ "$hit_count" -ge "$max_hits" ]; then
    break
  fi
  # case-insensitive, literal match
  if echo "$prompt" | grep -qiF "$kw"; then
    # 対応する routing 表の行（パイプで始まる表行、またはトリガー行）を抽出
    match=$(grep -iF "$kw" "$ROUTING" 2>/dev/null | grep -E '^\|' | head -1 || true)
    if [ -n "$match" ] && [ -z "${seen[$match]:-}" ]; then
      seen[$match]=1
      output="${output}${match}"$'\n'
      hit_count=$((hit_count + 1))
    fi
  fi
done

if [ -n "$output" ]; then
  echo "【Skill Routing Hint (30-routing.md 自動抽出)】"
  echo "$output" | sed 's/^/  /'
  echo "（該当スキルの利用を検討。無関係なら無視してよい）"
fi

exit 0
