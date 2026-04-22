#!/usr/bin/env bash
# UserPromptSubmit hook: プロンプトのキーワードを 30-routing.md と突き合わせ、
# 該当スキル行を stdout に出力して Claude の context に注入する。
# stdout は context に入るため、ノイズ防止のため最大4件まで。

set -eu

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

# キーワードリスト（日本語+英語）
keywords="デバッグ リファクタリング セキュリティ監査 脆弱性 KPI ダッシュボード 可視化 売上分析 テスト修正 スキル作成 プロジェクト復帰 ブックマーク エンゲージメント いいね数 Playwright Firecrawl スクレイピング Codex SubAgent 新機能 MVP Obsidian gitコミット シークレット API鍵 repomix Gmail スプレッドシート Docs ツール選択 Agent"

max_hits=4
tmp=$(mktemp -t routing-hits.XXXXXX 2>/dev/null || echo "/tmp/routing-hits.$$")
trap 'rm -f "$tmp"' EXIT

for kw in $keywords; do
  if echo "$prompt" | grep -qiF "$kw"; then
    grep -iF "$kw" "$ROUTING" 2>/dev/null | grep -E '^\|' | head -1 >> "$tmp" || true
  fi
done

# 重複除去して上位4件
if [ -s "$tmp" ]; then
  hits=$(sort -u "$tmp" | head -"$max_hits")
  if [ -n "$hits" ]; then
    echo "【Skill Routing Hint (30-routing.md 自動抽出)】"
    echo "$hits" | sed 's/^/  /'
    echo "（該当スキルの利用を検討。無関係なら無視してよい）"
  fi
fi

exit 0
