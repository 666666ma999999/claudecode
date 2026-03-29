---
name: search-best-practice
description: Web上のClaude Code運用ベストプラクティスを検索し、現環境との差分分析から適用計画を立てる。NOT for: コードレビュー、特定ライブラリ調査（→ context7）、セキュリティ監査（→ security-twin-audit）
user_invocable: true
allowed-tools: "Read Glob Grep Agent WebSearch WebFetch mcp__grok-search__web_search"
metadata:
  category: productivity
  tags: [web-search, best-practice, claude-code, self-improvement]
  version: 3.0.0
---

# Search Best Practice

Web上のClaude Code運用ベストプラクティスを検索し、自分の環境に適用する計画を立てる。

## When to Use

- `/search-best-practice` コマンド実行時
- 「ベスプラ調べて」「Claude Codeの最新Tips」「運用改善したい」等のリクエスト時
- 定期的なセルフアップデート（月1-2回推奨、大型アップデート時は随時）

## Phase 1: 現状把握

`/health` のStep 1と同等のデータを収集する。直近で `/health` を実行済みならその結果を再利用してよい。

収集対象:
- `grep "^##" ~/.claude/CLAUDE.md` — セクション構造
- `~/.claude/rules/*.md` のファイル名一覧
- `~/.claude/skills/` 配下のSKILL.md一覧
- `~/.claude/settings.json` の hooks キー一覧、permissions.deny一覧、statusLine有無
- `.claude/settings.local.json`（存在する場合）の追加設定
- `.mcp.json` の mcpServers キー一覧

## Phase 2: Web検索

`Agent`ツールでSubAgent 1本を起動し、以下の3軸で横断調査を委託する。30-routing.md準拠でCodex MCPまたはWebSearch+WebFetchを使用。

SubAgentへの指示: 「Claude Code運用ベストプラクティスの最新情報を以下の3軸で収集。各施策は `タイトル / 出典URL / 公開日 / 概要3行以内` で返却。合計15件以内。6ヶ月以上前の情報には `[要鮮度確認]` タグ付与。日本語・英語両方で検索。」

**3軸:**
1. **公式・ブログ** — docs.anthropic.com（最優先）、技術ブログ、Zenn/Qiita/note（`site:zenn.dev OR site:qiita.com` で明示的ターゲティング）
2. **X/Twitter** — 実践Tips、設定例を含む投稿。Grok Search利用可能なら補助的に追加検索
3. **GitHub** — CLAUDE.mdの実例、rules/構成例、新スキル/MCPサーバー、Awesome Lists

**信頼性順位:** 公式ドキュメント > 著名開発者のブログ/X > 個人投稿

## Phase 3: 差分分析と計画出力

検索結果をPhase 1のスナップショットと照合し、以下のフォーマットで出力する:

```markdown
# Claude Code ベスプラ適用計画

## 調査日: YYYY-MM-DD
## 情報ソース数: N件

### Quick Wins（即適用推奨）

1. **[施策名]**
   - 出典: [URL]（公開日: YYYY-MM-DD）
   - 内容: [具体的な変更内容]
   - 適用先: [CLAUDE.md / hooks / skills / MCP / rules]

### 要検証（効果検証後に適用）

1. **[施策名]**
   - 出典: [URL]（公開日: YYYY-MM-DD）
   - 期待効果 / リスク / 検証方法

### 見送り（理由付き）

1. **[施策名]** — [理由: 既に導入済み / 環境に合わない / リスクあり]
```

**Already Done判定:** Phase 1の見出しリスト・hooks・skills・MCP一覧に既に存在するものはスキップ。

**セキュリティ注意:** hook/MCP設定の変更を含む施策は、コマンド内容を精査。不審なシェルコマンド・外部送信・権限昇格を含む提案は「要検証」に分類。

## Phase 4: ユーザー確認と適用

> Quick Winsを適用しますか？個別に選択することもできます。

適用時はCLAUDE.mdの標準ルールに従う:
- バッチ検証ルール（最大3変更ごとに検証ポイント）
- 実行コード変更時は `implementation-checklist` 実行（CLAUDE.md/rulesのみの変更は免除）
- 適用後 `/health` で整合性チェック推奨
