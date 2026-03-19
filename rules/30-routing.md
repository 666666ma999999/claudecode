# スキルルーティング & 追加ルール

## スキルルーティング

回答・作業前に加え、**コード変更後の報告前**にも以下のマッピングを確認し該当スキルを参照すること:

> **注**: 「新機能追加」「エクステンション作成」が複数行にマッチする場合は、エクステンション分岐フロー（後述）で解決する。「デバッグ」は `debugging-guide` を優先し、委託判断には `execution-patterns` を参照。

| トリガー | 参照スキル |
|---------|-----------|
| BE新機能追加、APIエンドポイント追加、BEエクステンション作成、バックエンド設計、HookPoint実装、新機能追加、エクステンション作成、プラグインアーキテクチャ、backend feature、new API endpoint、extension pattern、plugin architecture、add backend、create extension | `be-extension-pattern` |
| タスク細分化、実装計画策定、計画作成 | `task-planner` |
| task進捗, stuck記録, セッション引き継ぎ, 要件変更追跡, progress tracking, session handoff | `task-progress` |
| プロジェクト思い出す、久しぶり、何だったっけ、コンテキスト復元、前回何してた、忘れた、project recall、what was this、remind me、catch up | `project-recall` |
| 設定配置、グローバル vs プロジェクト、config placement、設定優先順位、settings scope | `config-placement-guide` |
| グラフ作成、データ可視化、チャート生成、ヒートマップ、棒グラフ、折れ線グラフ、X投稿画像、imp最大化、visualization、chart | `data-visualization` |
| 売上分析、多変数分析、重回帰分析、データ分析 | `sales-analysis` |
| SubAgent委託、デバッグ、リファクタリング、大量データ分析 | `execution-patterns` |
| デバッグガイド、根本原因分析、バグ調査手順 | `debugging-guide` |
| リファクタリング戦略、コード改善、リファクタリングガイド | `refactoring-guide` |
| リファクタリング安全性、削除安全性、影響範囲確認 | `refactoring-safety` |
| FE+BE連携、APIコントラクト、エクステンション共有設定、クロスリポ連携、デプロイ協調 | `fe-be-extension-coordination` |
| 新機能追加、ページ追加、ウィジェット追加、エクステンション作成、FEアーキテクチャ、フロントエンド設計 | `fe-extension-pattern` |
| git commit/push/add、コミット禁止ファイル詳細、事故対応 | `git-safety-reference` |
| 通知設定、アラート設定、通知確認 | `notification-alert` |
| .envrc/.mcp.json操作、APIキー設定、新プロジェクト環境 | `secret-management` |
| 新プロジェクト初期化 | `project-bootstrap` |
| セキュリティ監査、脆弱性診断、Red Team、Blue Team、security audit、攻撃分析、防御設計 | `security-twin-audit` |
| スキル作成・更新・判断、横展開チェック | `skill-lifecycle-reference` |
| スキル作成、スキル新規作成、ワークフロー保存 | `skill-creator` |
| テスト修正、テスト失敗、テストデバッグ、TDD | `test-fixing` |
| Webスクレイピング、Agent Teams構成 | `tool-selection-reference` |
| コードベース調査、codebase investigation、大規模コード分析 | `codebase-investigation` |
| コード重複、二重実装、dual-path、DRY違反、canonical module、同じ処理が複数、重複ロジック | `20-code-quality.md` + `75-be-architecture.md` 参照（プロジェクトに `code-reviewer` スキルがあれば併用） |
| BEパイプライン重複、service二重化、副作用経路の一本化、BE設計 | `75-be-architecture.md` 参照 |
| デスクトップ整理、ファイル整理、cleanup、organize desktop、デスクトップ片付け | `organize-desktop` |
| FE新機能追加（extensions.jsonなし + HTML/JS）、vanilla FEページ追加 | `70-fe-architecture.md` 参照（エクステンション分岐 Step 2 経由） |
| vanilla JS FE設計、IIFE、コールバック連鎖、オーケストレータ、直接fetch禁止、Command/Query分離、FEパイプライン | `70-fe-architecture.md` 参照 |
| 実装完了、修正完了、完了報告前、確認依頼前、ブラウザで確認してください、動作確認してください、検証完了 | `implementation-checklist` |

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
- アーキテクチャ: direnv (.envrc) → シェル環境変数 → .mcp.json の `${VAR}` 展開
- 共通キー: `~/.envrc.shared` に集約、各 `.envrc` から `source_env_if_exists ~/.envrc.shared`
- 新プロジェクト: `.envrc` 作成 → `source_env_if_exists` 記載 → 固有変数追記 → `direnv allow`
- `.envrc`, `.envrc.shared`, `.mcp.json` は git管理対象外
- 詳細手順: `secret-management` スキル参照

## スキル化判断（要約）

実装完了時に以下を確認:

1. **Q1**: 新機能/新パターン/再発バグ/スキル情報の誤り → NO → 終了
2. **Q2**: 今後も繰り返し使う知見か → NO → 終了
3. **Q3**: 既存スキルに追加可能か → YES → 追記（確認不要） / NO → ユーザー確認後に新規作成

コード修正がスキル記載内容に影響する場合、スキルも同時更新すること。
詳細フロー: `skill-lifecycle-reference` スキル参照。
