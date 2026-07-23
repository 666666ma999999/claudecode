# スキルルーティング & 追加ルール

## スキルルーティング

回答・作業前に以下のマッピングを確認し該当スキルを参照すること:

> **注**: 「新機能追加」「エクステンション作成」が複数行にマッチする場合は、エクステンション分岐フロー（後述）で解決する。「デバッグ」は `debugging-guide` を優先し、委託判断には `execution-patterns` を参照。

### ワークフロー・計画

| トリガー | 参照スキル |
|---------|-----------|
| タスク細分化・実装計画策定 | `task-planner` |
| task進捗・stuck記録・セッション引き継ぎ | `task-progress` |
| Obsidian NOW→DONE移動・元プロンプト/原文/証跡/refs/ログ保存・タスク完了記録・`/done` | `/done` コマンド（自己完結・skill は _dormant/obsidian-now-done） |
| wikiキュー作って / wiki取り込み / URL取り込み / ✅処理して（第二の脳＝wiki知識化・queue経由） | `wiki-ingest` + `[[wiki-ingest-queue]]`（`wiki/meta/wiki-ingest-queue.md`・✅式の取り込み待合室。URL 1フロー=defuddle→`.raw/<topic>/`→wiki-ingest。取り込み時に関連既存ページへ根拠付き相互リンク+`## Updates`追記で「育つ」・完了を `wiki/log.md` に1行記録・処理済✅はキューから削除。SessionStart hook が未処理✅を通知） |
| wiki の健全性チェック・orphan/dead link/古い主張検出・wiki監査・掃除 | `wiki-lint`（"lint the wiki", "health check", "wiki audit"） |
| wiki から引用付き回答・"what do you know about"・wiki 検索・要約 | `wiki-query`（quick/standard/deep） |
| 今日の取り込みして / wiki自動取り込みの手動実行 / 第二の脳v3日次ジョブを今すぐ回す（無人・ハブ追記型） | 日次ジョブ `com.masa.wiki-daily-ingest`（毎日8:47・news収集8:07の後）。2段=`vault-prompt-runner.sh`(read-only claudeでpatch生成)→`wiki_ingest_apply.py`(柵・機械適用)。手動実走: `launchctl start com.masa.wiki-daily-ingest`。TCC 未付与時の直接実走: `/bin/bash -lc '~/.claude/scripts/vault-prompt-runner.sh "~/Documents/Obsidian Vault/00_General/prompts/scheduled/wiki-daily-ingest.md" && /usr/bin/python3 ~/.claude/scripts/wiki_ingest_apply.py "~/Documents/Obsidian Vault/wiki/meta/wiki-daily-ingest-result.md"'`。着地=ハブ5枚(`wiki/concepts/{AI活用と自動化,広告・マーケティング,占いビジネス,投資,事業戦略}.md`)の`## AI追記`節末尾のみ・新規ファイルは✅ゲート。柵=単一fenceのみ/allowlist外target拒否/秘密9種スキャン/4KB・12KB上限/flock/冪等(apply-log jsonl)。決定正本 `wiki/meta/decisions.md` 2026-07-06「無人AI書込はハブ追記型」・設計 `03_ClaudeEnv/ClaudeEnv-secondbrain-v2-plan.md` §v3 |
| プロジェクト復帰・コンテキスト復元 | `project-recall` |
| SubAgent委託・デバッグ・リファクタリング | `execution-patterns` |
| 叩き台・探索・試作・UI案・API挙動確認・要件曖昧 | `/prototype` コマンド |
| 実装完了・完了報告前・検証完了 | `implementation-checklist` |
| 新機能/MVP開始・4項目ブリーフ収集→Plan mode起動 | `new-feature` |
| 新プロジェクト初期化(.gitignore/Docker/CLAUDE.md 等) | `project-bootstrap`（CLAUDE.md 生成は公式 `/init` 併用。旧 /init-project コマンドは 2026-07-23 統合済） |
| ベスプラ検索・Claude Code運用改善・最新Tips | `search-best-practice` |
| Plan mode前スキル検索・外部レジストリ検索 | `find-skills` |
| Plan中のアーキテクチャ判断・設計リスク分析 | `plan-adversarial-review` |
| 別PC/別Macへの既存プロジェクト引き継ぎ・機密データ移送・setup-runbook 整備 | `project-cross-pc-handoff` |

### アーキテクチャ・設計

| トリガー | 参照スキル |
|---------|-----------|
| BE新機能・APIエンドポイント・エクステンション・HookPoint | `be-extension-pattern` |
| FE新機能・ページ追加・ウィジェット追加・FEアーキテクチャ | `fe-extension-pattern` |
| FE+BE連携・APIコントラクト・デプロイ協調 | `fe-be-extension-coordination` |
| コード重複・dual-path・DRY違反 | `20-code-quality.md` + `70-architecture.md` 参照 |
| BEパイプライン重複・BE設計 | `70-architecture.md`「BE 固有」参照 |
| vanilla FE設計・Command/Query分離・FEパイプライン | `70-architecture.md`「FE 固有」参照 |
| システム全体像・機能マップ・アーキ図・input/output・各機能の役割を図で・人に説明する構成図 | `templates/architecture.md`（雛形コピー・新設 2026-07-16。図は補助・正本は I/O/依存表） |
| 3F+設計判断・大規模アーキ判断・公開API変更・二択判断 | `plan-adversarial-review`（旧 opponent-review は 2026-07-11 吸収・汎用型は同 skill references/opponent-review-general.md）（軽い前提検証は `/review --mode=challenge`） |

### コード品質・リファクタリング

| トリガー | 参照スキル |
|---------|-----------|
| デバッグガイド・根本原因分析 | `debugging-guide` |
| 敵対的レビュー・前提疑問・ロジック検証 | `/review --mode=challenge` |
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
| データ可視化・チャート生成（**X 投稿用・単発チャート**） | `data-visualization`（現在 off=一覧非表示・使う時は skillOverrides 解除。経営層向けは dashboard-design-guide） |
| 経営層向けダッシュボード・デジタル庁ガイドブック準拠・matplotlib PNG | `dashboard-design-guide`（X 投稿用の単発チャートは data-visualization） |
| vault に司令塔/現状診断ボード/運用ダッシュボードを **full** で設計（薄い索引でなく判断材料を内包）・経営層1-pager・findings 清書・スクショ映え | `vault-report-writing`（設計／構文は `obsidian-markdown`。配置構造は rules/41・42 が正本。MOC の薄い索引化は `/sync-vault-summary`。※ `dashboard-design-guide`=matplotlib PNG生成・`salesmtg-dashboard-qa`=表示QA とは射程が別） |
| 売上分析・多変数分析 | `sales-analysis` |
| salesmtg CSV整合性・粗利構成不整合・スクレイピング後検証 | `salesmtg-data-audit` |
| salesmtg ダッシュボード表示・セグメント統一・N/A表示・QA | `salesmtg-dashboard-qa` |
| プロジェクト改善記録・改善メモ・X記事ネタ・定量改善・「これ記事化したい」「素材化」「マテリアルに」（質的体験も可） | `capture-improvement` |
| 占い商品改題・11体Agent Pipeline | rohan プロジェクト側 `retitle-product`＋`/retitle`（2026-07-23 グローバルから移設。rohan で作業時のみ発火） |

### ツール・ユーティリティ

| トリガー | 参照スキル |
|---------|-----------|
| Web リサーチ・情報検索・調査 | 下記「Web リサーチツール選択」参照 |
| Webスクレイピング・Agent Teams構成 | `tool-selection-reference` |
| Playwright並列化・ブラウザ自動化高速化・mutex競合解消 | `execution-patterns`（references/browser-automation-parallelization.md・2026-07-23 吸収） |
| X(Twitter)ブックマーク取得・教師データ変換 | `fetch-bookmarks` |
| X(Twitter)投稿エンゲージメント取得・候補URLの実測検証・いいね数確認 | `fetch-engagement` |
| X Cookie再取得・Chrome→x_profiles抽出・auth_token更新・`import_chrome_cookies.py` | influx側 `refresh-x-cookies`（`~/Desktop/biz/influx/.claude/skills/refresh-x-cookies/SKILL.md`、VNC方式は2026-04-21に廃止） |
| 有償生成API発注UI・estimate/confirm・二重課金・日次コスト上限・課金迂回路の監査 | `paid-generation-gate-audit`（2026-07-14 新設・reading-factory Phase C 敵対レビュー由来） |
| 人間承認ボタン・承認フロー設計・承認の証拠性/失効・reaperからの承認待ち保護 | `human-approval-design`（同上） |
| 動画からの種コマ/候補フレーム抽出・鮮明度スコア・単独人物判定の方式比較ベンチ | `media-candidate-bench`（同上） |
| ジョブ/ワークフロー状態機械の実装改修・遷移表からのテスト導出・CAS/二重送信/再起動 | `state-machine-test-gen`（同上） |
| Gmail・カレンダー・Drive・Google Sheets・スプレッドシート・Google Docs・Slides・`docs.google.com/spreadsheets/`・`docs.google.com/document/`・`drive.google.com/`・Google Workspace操作 | `gog-cli`（WebFetch は認証を通せないため禁止。`PreToolUse(WebFetch)` hook で自動 deny される） |
| ローカル文書ファイルの作成・編集・抽出 — PDF（結合/分割/フォーム/OCR）・Word `.docx`・PowerPoint `.pptx`・Excel `.xlsx`/CSV 整形 | 公式 `pdf` / `docx` / `pptx` / `xlsx`（anthropics/skills @1f630fd を 2026-07-23 コピー導入・棚卸し裁定③。用途: taxreturn 申告書類・collect_receipt 領収書・report 役員資料。Google Docs/Sheets 上の操作は gog-cli） |
| 通知設定・アラート設定 | `notification-alert` |
| デスクトップ整理・ファイル整理 | `organize-desktop` |
| 設定配置・グローバル vs プロジェクト | `config-placement-guide` |
| 2台目で設定再現・MCP追加後の手順書化・~/.codex/変更の配布・~/.zshrc export追加の codify | `codify-config` |
| 設定診断・health check・設定不整合・hook監査 | `health` |
| MCP使用回数・ツール頻度・スキル起動数・編集ファイル数・セッション数の実測裏取り | `env-factcheck` |
| Codex汎用委譲・非エンジニアタスク・資料レビュー | `codex-delegate` |
| Webページ本文のクリーン抽出（WebFetch 代替・省トークン） | `defuddle` |
| 新しい Mac の初期構築・環境複製 | `machine-bootstrap` |
| 高機密情報（銀行/証券/仮想通貨）の vault 基盤構築 | `secret-vault-setup` |
| JSON Canvas ファイル生成・編集 | `canvas`（構文は references/json-canvas-syntax.md・2026-07-11 統合） |
| Obsidian CLI の read/create/search・プラグイン/テーマ開発（DOM検査等）**ユーザー明示指名時のみ** | `obsidian-cli`（rules/40-obsidian.md「obsidian-cli ガード」準拠。workflow skill からの自動委譲は禁止・正系は wiki-ingest/save/canvas） |

### 記事生成・検証（X Articles パイプライン）

| トリガー | 参照スキル |
|---------|-----------|
| X Articles 長文記事生成・6 Agent Teams 並列生成 | `generate-x-article`（make_article 専用） |
| 記事短文投稿・3候補並列生成 | `generate-x-post`（make_article 専用） |
| 記事の体験・数値・シーン捏造チェック・AI捏造排除 | `verify-experience`（make_article 専用） |
| 記事のプロンプト例・コマンド・日付の環境履歴裏取り・自動ファクトチェック | `fact-check-from-history`（make_article 専用） |
| 記事のプロンプト実行可能性検証・読者コピペできるか・ペルソナシミュレーション | `verify-prompt-executability`（make_article 専用） |
| 記事画像計画・視覚化優先度付け・画像マーカー挿入 | `plan-article-images`（make_article 専用） |
| 記事投稿・プロモツイート・記事本文クリップボード | `post-article`（make_article 専用） |
| 投稿結果メトリクス記録・Feedback Loop | `record-result`（make_article 専用） |
| Feedback Loopパフォーマンス分析・素材パターン評価 | `analyze-performance`（make_article 専用） |
| reply の多い X 投稿の週次半手動収集（記事ネタ） | `collect-reply-posts` |
| 成果を X 記事化→投稿→24h計測まで一気通貫で出荷・x-stock 消化・「これ記事にして出して」 | `ship-article`（`/ship-article`・thin orchestrator） |

### スキル管理

| トリガー | 参照スキル |
|---------|-----------|
| スキル作成・更新・判断 | `skill-lifecycle-reference` |
| スキル新規作成・ワークフロー保存 | `skill-creator` |
| hook（PreToolUse/Stop 等）の新設・改修・誤検知/暴発の修理 | `hook-development-guide` |

## Web リサーチツール選択（2軸主義 — 概要）

**主軸 2 つ**: X バズ（grok-search + `/fetch-engagement`）/ GitHub star（`gh` CLI + `/gh-star-harvest`）。
**補助**: 公式 / MCP レジストリ / HN・Reddit・Zenn 等（Codex MCP 横断に一本化）。

詳細（情報源別ツール表 / 日常運用フロー / Don'ts）: `~/.claude/docs/web-research-tools.md`

## エクステンション設計の分岐

「新機能追加」「エクステンション作成」等の汎用リクエスト時、以下のフローで判定する。
BE/FEは独立に判定し、それぞれのルールを並行適用する。

### Step 1: マーカーファイル検出

| extensions.yaml | extensions.json | 適用ルール |
|:-:|:-:|---|
| あり | あり | 同一リポ → `be-extension-pattern` + `fe-extension-pattern` 個別適用 (両者ハイブリッド)。分離リポ → `fe-be-extension-coordination` スキル参照 |
| あり | なし | BE: `be-extension-pattern` スキル。FE: Step 2 へ |
| なし | あり | FE: `fe-extension-pattern` スキル。BE: Step 2 へ |
| なし | なし | Step 2 へ |

### Step 2: マーカーなし時の判定

- `backend/` or `src/` にPythonサービスコードあり → `70-architecture.md`「BE 固有」適用
- `frontend/*.html` + JS あり（React/TypeScript不使用）→ `70-architecture.md`「FE 固有」適用
- 上記いずれにも該当しない → ユーザーにBE/FEを確認

### 適用優先順

- `CLAUDE.md`（全体方針）> `rules/`（領域別ルール）> スキル（実装手順）
- マーカーありのスキルルール > マーカーなしのアーキテクチャルール
- 競合時は「より限定的なルール」を優先

## シークレット管理（要約）

- `.mcp.json` へのシークレット直書き**禁止**。`${VAR}` プレースホルダー必須
- 値は `~/.zshrc` で `export VAR=...`、Claude Code は**ターミナルから起動**（Launchpad起動だと環境変数が空）
- 詳細（アーキテクチャ・新プロジェクト追加手順・パーミッション）: `secret-management` スキル参照

## スキル化判断（要約）

実装完了時: ① 新機能/新パターン/再発バグか → ② 今後も繰り返し使う知見か → ③ 既存スキルに追加可能か。
詳細フロー（Q0-Q3 / 横展開チェック / 重複チェック）: `skill-lifecycle-reference` スキル参照。

## wiki-daily-ingest（TCC 未付与時の代替コマンド・rules/30 から移設 2026-07-15）

`launchctl start com.masa.wiki-daily-ingest` が TCC 未付与で失敗する時:
```bash
/bin/bash -lc '~/.claude/scripts/vault-prompt-runner.sh "~/Documents/Obsidian Vault/00_General/prompts/scheduled/wiki-daily-ingest.md" && /usr/bin/python3 ~/.claude/scripts/wiki_ingest_apply.py "~/Documents/Obsidian Vault/wiki/meta/wiki-daily-ingest-result.md"'
```
