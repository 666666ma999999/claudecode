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
keywords="デバッグ リファクタリング セキュリティ監査 脆弱性 KPI ダッシュボード 可視化 売上分析 テスト修正 スキル作成 プロジェクト復帰 ブックマーク エンゲージメント いいね数 Playwright Firecrawl スクレイピング Codex SubAgent 新機能 MVP Obsidian gitコミット シークレット API鍵 repomix Gmail スプレッドシート Docs ツール選択 Agent レポート 整形 清書 1-pager 報告書 経営層"

max_hits=4
tmp=$(mktemp -t routing-hits.XXXXXX 2>/dev/null || echo "/tmp/routing-hits.$$")
trap 'rm -f "$tmp"' EXIT

for kw in $keywords; do
  if echo "$prompt" | grep -qiF "$kw"; then
    grep -iF "$kw" "$ROUTING" 2>/dev/null | grep -E '^\|' | head -1 >> "$tmp" || true
  fi
done

# 重複除去して上位4件
routing_hit=0
if [ -s "$tmp" ]; then
  hits=$(sort -u "$tmp" | head -"$max_hits")
  if [ -n "$hits" ]; then
    routing_hit=1
    echo "【Skill Routing Hint (30-routing.md 自動抽出)】"
    echo "$hits" | sed 's/^/  /'
    echo "（該当スキルの利用を検討。無関係なら無視してよい）"
  fi
fi

# --- Skill Reverse-Lookup Reflex 注入 ---
# 標準タスク受領のシグナル (動詞検出) があり、かつ routing ヒットなしの場合のみ
# 「逆引きしてから着手」を促す。即答 (Yes/No・定義確認) は素通り。
task_verb_re='実装|修正|追加|作って|直して|変更|リファクタ|新機能|機能追加|セットアップ|構築|デバッグ|調査して|分析して|レビュー|design|implement|refactor|build|fix|add|create'
if [ "$routing_hit" = "0" ] && echo "$prompt" | grep -qiE "$task_verb_re"; then
  echo ""
  echo "【⚠️ Skill Reverse-Lookup (該当スキル未マッチ)】"
  echo "  67 skills / 14 MCP / 30 commands は全把握不可能。実装前に下記いずれかで逆引き必須:"
  echo "    1) grep -i <キーワード> ~/.claude/rules/30-routing.md"
  echo "    2) Skill: find-skills (外部レジストリ・コスト要)"
  echo "  逆引きせずに Agent/手動実装に進むのは NG。即答 (Yes/No・定義確認) は除外。"
fi

# --- Mistake Prevention Checklist 注入 ---
# recurring-mistakes.md のルールから trigger キーワードで該当 checklist を抽出
inject_mistake_rule() {
  local label="$1"; shift
  local rule_id="$1"; shift
  local rule_text="$1"
  echo ""
  echo "【⚠️ Mistake Prevention: ${label}】"
  echo "  ${rule_text}"
  echo "  (ref: ~/.claude/state/recurring-mistakes.md#${rule_id})"
}

# fetch-failure-ladder: URL / 取得 / fetch / 動的 / X tweet
if echo "$prompt" | grep -qiE "URL|取得失敗|fetch|動的|tweet|x\.com|スクレイプ|scrape"; then
  inject_mistake_rule "fetch-failure-ladder" "fetch-failure-ladder" \
    "URL/動的コンテンツ取得失敗を宣言する前に WebFetch → mcp__firecrawl__firecrawl_search → Playwright の最低3経路を試す（grok は 2026-07-22 廃止・はしごから除外）。"
fi

# fact-claim-proof: 公式 / 実装 / 現状 / 配置 / 存在
if echo "$prompt" | grep -qiE "公式|official|実装|どこ|配置|存在|今の状態|現状"; then
  inject_mistake_rule "fact-claim-proof" "fact-claim-proof" \
    "「公式/実装/現状/配置/存在」は一次ソース or 実ファイル確認前に断定禁止。未確認なら「未確認」と明言する。"
fi

# simplify-converge: もっとシンプル / 簡潔 / 最小 / 削る
if echo "$prompt" | grep -qiE "もっとシンプル|もっと簡潔|もっと簡単|もっと最小|もっと削|よりシンプル|より簡単"; then
  inject_mistake_rule "simplify-converge" "simplify-converge" \
    "「もっとシンプル」2回目以降は新案探索を止め、最小案 + 失うもの(捨てる複雑性)を 1 文で明示して収束する。"
fi

# judgment-number-first: 提案 / 施策 / 見積 / 指示書 / まとめ / ランキング等、数字・優先順位を出しそうな依頼
if echo "$prompt" | grep -qiE "提案|施策|見積|予算|費用|コスト|いくら|試算|効果|案を|プラン|比較|調べて|分析|指示書|まとめ|整形|清書|レポート|ランキング|優先順|順位"; then
  inject_mistake_rule "judgment-number-first" "judgment-number-first" \
    "判断を左右する導出値は 算出(式)・前提(出所)・確度 を先出し。実測値の合計・差・比率・期間換算は単位が件数/日数でも対象。施策・提案は各項目に根拠数字を添えるか、無い項目は「根拠数字なし・定性判断」と項目内に明示。優先順位・ランキングには掲載式（並べ替え規則と各行の計算）を必ず併記する。"
fi

exit 0
