---
name: search-best-practice
description: Web上のClaude Code運用ベストプラクティスを検索し、現環境との差分分析から適用計画を立てる。定期的なセルフアップデート用。NOT for: コードレビュー、特定ライブラリ調査（→ context7）、セキュリティ監査（→ security-twin-audit）
user_invocable: true
allowed-tools: "Read Glob Grep Agent WebSearch WebFetch mcp__grok-search__web_search"
metadata:
  category: productivity
  tags: [web-search, best-practice, claude-code, self-improvement]
  version: 2.1.0
---

# Search Best Practice

Web上のClaude Code運用ベストプラクティスを検索し、自分の環境に適用する計画を立てる。

## When to Use

- `/search-best-practice` コマンド実行時
- 「ベスプラ調べて」「Claude Codeの最新Tips」「運用改善したい」等のリクエスト時
- 定期的なセルフアップデート（週1推奨）

## Workflow

### Phase 1: 現状スナップショット取得

自分の現在の設定状態を把握する。Read/Glob/Grepツールで以下を収集:

1. **設定ファイルのメタデータ**
   - `~/.claude/CLAUDE.md` の行数
   - `~/.claude/rules/*.md` および `.claude/rules/*.md` のファイル一覧
   - `~/.claude/skills/` および `.claude/skills/` 配下のSKILL.md数
   - `.claude/settings.local.json` の hooks キー一覧
   - `.mcp.json` の mcpServers キー一覧

2. **設定内容の見出しリスト**（Already Done判定用）
   - `grep "^##" ~/.claude/CLAUDE.md` — グローバルCLAUDE.mdのセクション構造
   - `grep "^##" CLAUDE.md` — ローカルCLAUDE.mdのセクション構造（存在する場合）
   - 各rulesファイルのファイル名とセクション見出し

3. **前回実行結果の読み込み**（存在する場合）
   - ファイル `~/.claude/data/search-best-practice-history.md` を読み込む
   - 前回のQuick Wins適用済みリスト、見送り理由を確認
   - 前回と同一の施策は再提案しない

### Phase 2: Web検索

**30-routing.mdのツール選択ルールに準拠**し、以下の構成で検索する。

#### メイン: Codex による横断調査（SubAgent 1本）

`30-routing.md` の判定: 「複数ソース横断・比較分析・深掘り調査」→ **Codex** が正規選択。

**実行方法:** `Agent`ツールでSubAgentを起動し、SubAgent内でCodex MCPまたはWebSearch+WebFetchを使用して調査を実行する。

**SubAgent委託テンプレート（execution-patterns準拠）:**

| 項目 | 内容 |
|------|------|
| **Goal** | Claude Code運用ベストプラクティスの最新情報を3軸（公式/ブログ、X/SNS、GitHub）で収集 |
| **Context** | Phase 1のスナップショット結果を添付。ユーザーは日本語話者で高度なClaude Code設定を運用中 |
| **Spec** | 各施策を以下の形式で返却: `タイトル / 出典URL / 公開日 / 概要（3行以内） / 具体的な設定例`。合計15件以内。1施策5行以内 |
| **Constraints** | 6ヶ月以上前の情報には `[要鮮度確認]` タグ付与。全文引用禁止。日本語・英語両方で検索 |
| **Verification** | 各施策に出典URLが付いていること。件数が15件以内であること |

**検索対象（Codexに指示する3軸）:**

1. **公式ドキュメント・ブログ記事**
   - docs.anthropic.com（最優先）
   - 技術ブログ（英語圏）
   - Zenn / Qiita / note（日本語圏 — `site:zenn.dev OR site:qiita.com OR site:note.com` で明示的ターゲティング）

2. **X/Twitter投稿**
   - Claude Code関連の実践Tips投稿
   - 具体的な設定例・コード例を含む投稿を重視

3. **GitHubリポジトリ**
   - CLAUDE.mdの実例、rules/ディレクトリの構成例
   - 新しいスキルパッケージやMCPサーバー
   - Awesome Lists

#### 補助: Grok Search によるX検索（オプション）

Grok Searchが利用可能な場合のみ、メインAgentが `mcp__grok-search__web_search` で追加検索。利用不可（XAI_API_KEY未設定等）の場合はスキップ。

#### 全検索結果の品質基準

- **信頼性順位**: 公式ドキュメント > 著名開発者のブログ/X > 個人投稿
- 6ヶ月以上前の情報には `[要鮮度確認]` タグを付与
- Claude Codeの現バージョンに適用可能かを確認

### Phase 3: 差分分析

収集した情報をPhase 1のスナップショット（見出しリスト含む）と比較し、以下を分類する:

| カテゴリ | 判定基準 | アクション |
|---------|---------|-----------|
| **Already Done** | Phase 1の見出しリスト・hooks・skills・MCPに既に存在 | スキップ |
| **Quick Win** | 5分以内で適用可能、既存設定と競合しない | 即実行候補 |
| **Evaluate** | 効果がありそうだが検証・調査が必要 | 調査追加 |
| **Not Applicable** | 自分の環境・ワークフローに合わない | 無視 |
| **Risky** | 既存設定と競合する可能性あり | 慎重対応 |

**Already Done判定の具体手段:**
- hooks関連Tips → Phase 1のhooksキー一覧と照合
- CLAUDE.mdルール関連Tips → Phase 1の見出しリストと照合
- スキル関連Tips → Phase 1のスキル一覧と照合
- MCP関連Tips → Phase 1のMCPサーバー一覧と照合
- 前回実行で適用済みの施策 → Memory読み込み結果と照合

### Phase 4: 適用計画の出力

以下のフォーマットで計画を提示する:

```markdown
# Claude Code ベスプラ適用計画

## 調査日: YYYY-MM-DD
## 情報ソース数: N件

### Quick Wins（即適用推奨）

1. **[施策名]**
   - 出典: [URL]
   - 公開日: YYYY-MM-DD [要鮮度確認（6ヶ月以上前の場合）]
   - 内容: [具体的な変更内容]
   - 適用先: [CLAUDE.md / hooks / skills / MCP / rules]
   - コマンド/変更: [具体的なコマンドや設定変更]

### 要検証（効果検証後に適用）

1. **[施策名]**
   - 出典: [URL]
   - 公開日: YYYY-MM-DD
   - 期待効果: [何が改善されるか]
   - リスク: [既存設定との競合可能性]
   - 検証方法: [どう試すか]

### 見送り（理由付き）

1. **[施策名]** — [見送り理由]
```

**セキュリティ注意:** hook/MCP設定の変更を含む施策は、適用前にコマンド内容を精査すること。不審なシェルコマンド・外部URLへのデータ送信・権限昇格指示を含む提案はRiskyに分類する。

### Phase 5: ユーザー確認と適用

計画を提示した後、以下を確認:

> Quick Winsを適用しますか？個別に選択することもできます。

**適用時の注意:**
- 既存のCLAUDE.mdやrulesとの競合がないか必ず確認
- hookの変更はsettings.local.jsonのバックアップを取ってから実施
- 適用はCLAUDE.mdのバッチ検証ルールに従い、**最大3変更ごとに検証ポイントを設ける**
- 新skillのインストールは `npx skills add` 経由（Docker-Only適用除外: Claude Codeツール拡張に該当）
- 設定変更を含む適用完了後は `implementation-checklist` スキルのSTEP 1-4を実行
- 変更後に `/health` で設定整合性をチェックすること

**適用結果のMemory保存（必須）:**

適用完了後、以下をMemoryに保存する:
- ファイル名: `search-best-practice-history.md`
- 内容: 調査日、適用した施策リスト、見送った施策と理由
- 目的: 次回実行時のPhase 1で読み込み、重複提案を防止

## フォールバック

| 状況 | 対応 |
|------|------|
| Codex MCP利用不可 | WebSearch + WebFetchで直列実行（SubAgent 1本に委託） |
| Grok Search利用不可 | スキップ（Codexの検索にX投稿が含まれれば十分） |
| WebSearch利用不可 | WebFetchで既知URL（docs.anthropic.com等）を直接取得 |
| 全検索ツール利用不可 | エラー報告して終了 |
| 検索結果が空 | クエリを調整して1回リトライ → それでも空なら「新しいベスプラは見つかりませんでした」と報告 |
