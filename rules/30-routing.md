# スキルルーティング & 追加ルール

## スキルルーティング

回答・作業前に以下のマッピングを確認し該当スキルを参照すること:

> **注**: 「新機能追加」「エクステンション作成」が複数行にマッチする場合は、エクステンション分岐フロー（後述）で解決する。「デバッグ」は `debugging-guide` を優先し、委託判断には `execution-patterns` を参照。

### ワークフロー・計画

| トリガー | 参照スキル |
|---------|-----------|
| タスク細分化・実装計画策定 | `task-planner` |
| task進捗・stuck記録・セッション引き継ぎ | `task-progress` |
| Obsidian NOW→DONE移動・元プロンプト保存・タスク完了記録 | `obsidian-now-done` |
| プロジェクト復帰・コンテキスト復元 | `project-recall` |
| SubAgent委託・デバッグ・リファクタリング | `execution-patterns` |
| 叩き台・探索・試作・UI案・API挙動確認・要件曖昧 | `/prototype` コマンド |
| 実装完了・完了報告前・検証完了 | `implementation-checklist` |
| 新機能/MVP開始・4項目ブリーフ収集→Plan mode起動 | `new-feature` |
| 新機能開発・設計比較・3並列アーキテクチャ比較が必要 | `feature-dev-hybrid` |
| 新プロジェクト初期化(.gitignore/Docker/CLAUDE.md 等) | `project-bootstrap` |
| ベスプラ検索・Claude Code運用改善・最新Tips | `search-best-practice` |
| Plan mode前スキル検索・外部レジストリ検索 | `find-skills` |
| Plan中のアーキテクチャ判断・設計リスク分析 | `plan-adversarial-review` |

### アーキテクチャ・設計

| トリガー | 参照スキル |
|---------|-----------|
| BE新機能・APIエンドポイント・エクステンション・HookPoint | `be-extension-pattern` |
| FE新機能・ページ追加・ウィジェット追加・FEアーキテクチャ | `fe-extension-pattern` |
| FE+BE連携・APIコントラクト・デプロイ協調 | `fe-be-extension-coordination` |
| コード重複・dual-path・DRY違反 | `20-code-quality.md` + `75-be-architecture.md` 参照 |
| BEパイプライン重複・BE設計 | `75-be-architecture.md` 参照 |
| vanilla FE設計・Command/Query分離・FEパイプライン | `70-fe-architecture.md` 参照 |
| 設計判断・トレードオフ・反証・妥当性検証・対立検証 | `opponent-review` |

### コード品質・リファクタリング

| トリガー | 参照スキル |
|---------|-----------|
| デバッグガイド・根本原因分析 | `debugging-guide` |
| 敵対的レビュー・前提疑問・ロジック検証 | `/adversarial-review` コマンド |
| 行き詰まり・Codex完遂力が必要・stuck時引き渡し | `/rescue` コマンド |
| リファクタリング戦略・コード改善 | `refactoring-guide` |
| リファクタリング安全性・削除安全性 | `refactoring-safety` |
| テスト修正・テスト失敗・TDD | `test-fixing` |

### セキュリティ

| トリガー | 参照スキル |
|---------|-----------|
| セキュリティ監査・脆弱性診断 | `security-twin-audit` |
| git commit/push/add・コミット禁止・事故対応 | `git-safety-reference` |
| .mcp.json操作・APIキー設定・シークレット管理 | `secret-management` |

### コードベース理解・可視化

| トリガー | 参照スキル |
|---------|-----------|
| コードベース調査・大規模コード分析 | `codebase-investigation` |

### データ・ビジネス

| トリガー | 参照スキル |
|---------|-----------|
| KPI分解・構成要素・ドリルダウン・因果分析・計算式定義 | `kpi-tree-first` |
| データ可視化・チャート生成 | `data-visualization` |
| 経営層向けダッシュボード・デジタル庁ガイドブック準拠・matplotlib PNG | `dashboard-design-guide` |
| Obsidian短文MD統合先選定・DONEエントリ再配置 | `obsidian-short-note-merge` |
| 売上分析・多変数分析 | `sales-analysis` |
| salesmtg CSV整合性・粗利構成不整合・スクレイピング後検証 | `salesmtg-data-audit` |
| salesmtg ダッシュボード表示・セグメント統一・N/A表示・QA | `salesmtg-dashboard-qa` |
| プロジェクト改善記録・改善メモ・X記事ネタ・定量改善 | `capture-improvement` |
| 占い商品改題・11体Agent Pipeline | `retitle-product` |

### ツール・ユーティリティ

| トリガー | 参照スキル |
|---------|-----------|
| Web リサーチ・情報検索・調査 | 下記「Web リサーチツール選択」参照 |
| Webスクレイピング・Agent Teams構成 | `tool-selection-reference` |
| 無限スクロール・大量データスクレイピング・Playwright逐次保存 | `max-scroll-scrape` |
| Playwright並列化・ブラウザ自動化高速化・mutex競合解消 | `browser-automation-parallelization` |
| X(Twitter)ブックマーク取得・Cookie再取得・教師データ変換 | `fetch-bookmarks` |
| X(Twitter)投稿エンゲージメント取得・候補URLの実測検証・いいね数確認 | `fetch-engagement` |
| UIデザイン品質・カラーパレット・タイポグラフィ・コンポーネント設計 | `frontend-design` |
| Gmail・カレンダー・Drive・Google Sheets・スプレッドシート・Google Docs・Slides・`docs.google.com/spreadsheets/`・`docs.google.com/document/`・`drive.google.com/`・Google Workspace操作 | `gog-cli`（WebFetch は認証を通せないため禁止。`PreToolUse(WebFetch)` hook で自動 deny される） |
| 通知設定・アラート設定 | `notification-alert` |
| デスクトップ整理・ファイル整理 | `organize-desktop` |
| 設定配置・グローバル vs プロジェクト | `config-placement-guide` |
| 設定診断・health check・設定不整合・hook監査 | `health` |
| Codex汎用委譲・非エンジニアタスク・資料レビュー | `codex-delegate` |

### 記事生成・検証（X Articles パイプライン）

| トリガー | 参照スキル |
|---------|-----------|
| X Articles 長文記事生成・6 Agent Teams 並列生成 | `generate-x-article`（make_article 専用） |
| 記事短文投稿・3候補並列生成 | `generate-x-post`（make_article 専用） |
| 記事の体験・数値・シーン捏造チェック・AI捏造排除 | `verify-experience` |
| 記事のプロンプト例・コマンド・日付の環境履歴裏取り・自動ファクトチェック | `fact-check-from-history` |
| 記事のプロンプト実行可能性検証・読者コピペできるか・ペルソナシミュレーション | `verify-prompt-executability` |
| 記事画像計画・視覚化優先度付け・画像マーカー挿入 | `plan-article-images` |
| 記事投稿・プロモツイート・記事本文クリップボード | `post-article` |
| 投稿結果メトリクス記録・Feedback Loop | `record-result` |
| Feedback Loopパフォーマンス分析・素材パターン評価 | `analyze-performance` |

### スキル管理

| トリガー | 参照スキル |
|---------|-----------|
| スキル作成・更新・判断 | `skill-lifecycle-reference` |
| スキル新規作成・ワークフロー保存 | `skill-creator` |

## Web リサーチツール選択

```
1. 単純な事実確認・1〜2ページ参照？ → WebSearch + WebFetch
2. 複数ソース横断・比較分析・深掘り調査？ → Codex（自律的に多段階検索・要約）
3. 特定サイトの全ページクロール・構造化データ抽出？ → Firecrawl（Docker起動必要）
4. X(Twitter)データ？ → Grok Search（XAI_API_KEY必要）、代替: Codex（Yahoo!リアルタイム経由）
```

| ツール | 強み | 用途 |
|--------|------|------|
| WebSearch + WebFetch | 低レイテンシ、直接統合 | 単発検索、既知URLの内容取得 |
| Codex | 自律多段階リサーチ、一次情報源に到達 | 調査・比較分析・要約が必要な検索 |
| Firecrawl | サイト全体クロール、スキーマ指定抽出 | 定型データ収集・大量ページ取得 |
| Grok Search | X/Twitterデータ直接アクセス | X投稿のリアルタイム検索 |

## エクステンション設計の分岐

「新機能追加」「エクステンション作成」等の汎用リクエスト時、以下のフローで判定する。
BE/FEは独立に判定し、それぞれのルールを並行適用する。

### Step 1: マーカーファイル検出

| extensions.yaml | extensions.json | 適用ルール |
|:-:|:-:|---|
| あり | あり | 同一リポ → `60-cms-and-extension-pattern.md` のハイブリッドルール + 各スキル併用。分離リポ → `fe-be-extension-coordination` スキル参照 |
| あり | なし | BE: `be-extension-pattern` スキル。FE: Step 2 へ |
| なし | あり | FE: `fe-extension-pattern` スキル。BE: Step 2 へ |
| なし | なし | Step 2 へ |

### Step 2: マーカーなし時の判定

- `backend/` or `src/` にPythonサービスコードあり → `75-be-architecture.md` 適用
- `frontend/*.html` + JS あり（React/TypeScript不使用）→ `70-fe-architecture.md` 適用
- 上記いずれにも該当しない → ユーザーにBE/FEを確認

### 適用優先順

- `CLAUDE.md`（全体方針）> `rules/`（領域別ルール）> スキル（実装手順）
- マーカーありのスキルルール > マーカーなしのアーキテクチャルール
- 競合時は「より限定的なルール」を優先

## シークレット管理（基本方針）

- `.mcp.json` へのシークレット直書き**禁止**。`${VAR}` プレースホルダー必須
- アーキテクチャ: `~/.zshrc` で `export VAR=...` → シェル環境変数 → Claude Code 起動時に継承 → `.mcp.json` の `${VAR}` 展開
- シークレット値は `~/.zshrc` に直接 export（git管理外のホームディレクトリファイル）
- `.mcp.json` は git管理対象外
- Claude Code は**ターミナルから起動**すること（Launchpad/Dockから起動すると `~/.zshrc` が読まれず環境変数が空になる）
- 詳細手順: `secret-management` スキル参照

## スキル化判断（要約）

実装完了時に以下を確認:

1. **Q1**: 新機能/新パターン/再発バグ/スキル情報の誤り → NO → 終了
2. **Q2**: 今後も繰り返し使う知見か → NO → 終了
3. **Q3**: 既存スキルに追加可能か → YES → 追記（確認不要） / NO → ユーザー確認後に新規作成

コード修正がスキル記載内容に影響する場合、スキルも同時更新すること。
詳細フロー: `skill-lifecycle-reference` スキル参照。
