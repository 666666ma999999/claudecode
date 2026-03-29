---
name: search-best-practice
description: Search the web for Claude Code best practices and create a plan to apply them to your own setup. Use when wanting to stay up-to-date with community tips, CLAUDE.md patterns, hook configurations, skill ecosystems, and workflow optimizations.
user_invocable: true
---

# Search Best Practice

Web上のClaude Code運用ベストプラクティスを検索し、自分の環境に適用する計画を立てる。

## When to Use

- `/search-best-practice` コマンド実行時
- 「ベスプラ調べて」「Claude Codeの最新Tips」「運用改善したい」等のリクエスト時
- 定期的なセルフアップデート（週1推奨）

## Workflow

### Phase 1: 現状スナップショット取得

まず自分の現在の設定状態を把握する。以下を収集:

```bash
echo "=== Global CLAUDE.md ===" && wc -l ~/.claude/CLAUDE.md 2>/dev/null
echo "=== Local CLAUDE.md ===" && wc -l CLAUDE.md 2>/dev/null
echo "=== Rules ===" && ls ~/.claude/rules/*.md 2>/dev/null && ls .claude/rules/*.md 2>/dev/null
echo "=== Skills ===" && find ~/.claude/skills .claude/skills -name "SKILL.md" 2>/dev/null | wc -l
echo "=== Hooks ===" && python3 -c "import json; d=json.load(open('.claude/settings.local.json')); print(json.dumps(list(d.get('hooks',{}).keys())))" 2>/dev/null || echo "(none)"
echo "=== MCP Servers ===" && python3 -c "import json; d=json.load(open('.mcp.json')); print(list(d.get('mcpServers',{}).keys()))" 2>/dev/null || echo "(none)"
```

### Phase 2: Web検索（並列SubAgent 3本）

**3つの検索軸**で最新情報を収集する。各軸をSubAgentに委託し並列実行:

#### Agent 1: X/Twitter トレンド（Grok Search）

Grok Searchを使用してX上のClaude Code関連投稿を収集する。

```
検索クエリ:
- "Claude Code ベストプラクティス"
- "Claude Code CLAUDE.md tips"
- "Claude Code hooks 設定"
- "Claude Code workflow"
- "Claude Code MCP おすすめ"
```

**Instruction:**
- `mcp__grok-search__web_search` を使用（platform: "Twitter"）
- 日本語・英語の両方で検索する
- いいね数・RT数が多い投稿を優先的に抽出
- 投稿日が新しいものを優先（直近3ヶ月以内）
- 具体的な設定例・コード例を含む投稿を重視

#### Agent 2: ブログ・記事・公式ドキュメント（WebSearch + WebFetch）

```
検索クエリ:
- "Claude Code best practices CLAUDE.md configuration"
- "Claude Code hooks MCP setup guide"
- "Claude Code agent workflow optimization"
- "Anthropic Claude Code tips tricks"
- "Claude Code 運用 ベストプラクティス"
```

**Instruction:**
- WebSearch → 上位結果のURLをWebFetchで内容取得
- 公式ドキュメント（docs.anthropic.com）を最優先
- 具体的な設定例・コード例を抽出する

#### Agent 3: GitHub リポジトリ・Awesome Lists（WebSearch）

```
検索クエリ:
- "awesome claude code github"
- "claude code CLAUDE.md examples" site:github.com
- "claude code skills repository"
- ".claude/rules" OR ".claude/skills" site:github.com
```

**Instruction:**
- CLAUDE.mdの実例、rules/ディレクトリの構成例を収集
- スター数が多いリポジトリを優先
- 新しいスキルパッケージやMCPサーバーを発見する

### 全Agentへの共通Instruction

- 情報ソースのURL・日付・著者を必ず記録する
- 具体的な設定例・コード例を抽出する
- 「既に広く知られた一般論」と「新しい/ユニークなテクニック」を区別する
- 信頼性の低い情報源にはフラグを付ける

### Phase 3: 差分分析

収集した情報をPhase 1のスナップショットと比較し、以下を分類する:

| カテゴリ | 説明 | 例 |
|---------|------|-----|
| **Already Done** | 既に自分の環境で実装済み | CLAUDE.mdのルール体系化 |
| **Quick Win** | 5分以内で適用可能、リスク低 | 新しいhookの追加、skill installなど |
| **Evaluate** | 効果がありそうだが検証が必要 | アーキテクチャ変更、新MCP導入 |
| **Not Applicable** | 自分の環境・ワークフローに合わない | 使わない言語/FW向けのTips |
| **Risky** | 既存設定と競合する可能性あり | 既存hookの置き換え、ルール変更 |

### Phase 4: 適用計画の出力

以下のフォーマットで計画を提示する:

```markdown
# Claude Code ベスプラ適用計画

## 調査日: YYYY-MM-DD
## 情報ソース数: N件（X: n件 / ブログ: n件 / GitHub: n件）

### Quick Wins（即適用推奨）

1. **[施策名]**
   - 出典: [URL]
   - 内容: [具体的な変更内容]
   - 適用先: [CLAUDE.md / hooks / skills / MCP / rules]
   - コマンド/変更: [具体的なコマンドや設定変更]

### 要検証（効果検証後に適用）

1. **[施策名]**
   - 出典: [URL]
   - 期待効果: [何が改善されるか]
   - リスク: [既存設定との競合可能性]
   - 検証方法: [どう試すか]

### 見送り（理由付き）

1. **[施策名]** — [見送り理由]
```

### Phase 5: ユーザー確認

計画を提示した後、以下を確認:

> Quick Winsを適用しますか？個別に選択することもできます。

**適用時の注意:**
- 既存のCLAUDE.mdやrulesとの競合がないか必ず確認
- hookの変更はsettings.local.jsonのバックアップを取ってから実施
- 新skillのインストールは `npx skills add` 経由
- 変更後に `/health` で設定整合性をチェックすることを推奨

## Tips

- **信頼性順位**: 公式ドキュメント > 著名開発者のブログ/X > 個人投稿
- 「万人向けのベスプラ」より「自分のワークフローに合うか」を重視する
- 適用後は1週間程度使ってみて、効果がなければ戻す（可逆性を確保）
- 発見した良いプラクティスはMemoryに保存して次回の差分検出に活用する
