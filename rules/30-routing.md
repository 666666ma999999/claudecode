# スキルルーティング & 追加ルール

## スキルルーティング

回答・作業前に、以下のマッピングを確認し該当スキルを参照すること:

> 「新機能追加」「エクステンション作成」が複数行にマッチする場合は、エクステンション分岐フロー（`60-cms-and-extension-pattern.md`）で解決する。「デバッグ」は `debugging-guide` を優先し、委託判断には `execution-patterns` を参照。

| トリガー | 参照スキル |
|---------|-----------|
| BE新機能追加、APIエンドポイント追加、BEエクステンション作成、バックエンド設計、HookPoint実装、新機能追加、エクステンション作成、プラグインアーキテクチャ、backend feature、new API endpoint、extension pattern、plugin architecture、add backend、create extension | `be-extension-pattern` |
| タスク細分化、実装計画策定、計画作成 | `task-planner` |
| 設定配置、グローバル vs プロジェクト、config placement、設定優先順位、settings scope | `config-placement-guide` |
| task進捗、stuck記録、セッション引き継ぎ、progress tracking、session handoff | `task-progress` |
| デスクトップ整理、ファイル整理、cleanup、organize desktop、デスクトップ片付け | `organize-desktop` |
| コード重複、二重実装、dual-path、DRY違反、canonical module、同じ処理が複数、重複ロジック | `20-code-quality.md` + `75-be-architecture.md` 参照 |
| BEパイプライン重複、service二重化、副作用経路の一本化、BE設計 | `75-be-architecture.md` 参照 |
| 売上分析、多変数分析、重回帰分析、データ分析 | `sales-analysis` |
| SubAgent委託、デバッグ、リファクタリング、大量データ分析 | `execution-patterns` |
| デバッグガイド、根本原因分析、バグ調査手順 | `debugging-guide` |
| リファクタリング戦略、コード改善、リファクタリングガイド | `refactoring-guide` |
| リファクタリング安全性、削除安全性、影響範囲確認 | `refactoring-safety` |
| FE+BE連携、APIコントラクト、エクステンション共有設定、クロスリポ連携、デプロイ協調 | `fe-be-extension-coordination` |
| 新機能追加、ページ追加、ウィジェット追加、エクステンション作成、FEアーキテクチャ、フロントエンド設計 | `fe-extension-pattern` |
| FE新機能追加（extensions.jsonなし + HTML/JS）、vanilla FEページ追加 | `70-fe-architecture.md` 参照（エクステンション分岐 Step 2 経由） |
| vanilla JS FE設計、IIFE、コールバック連鎖、オーケストレータ、直接fetch禁止、Command/Query分離、FEパイプライン | `70-fe-architecture.md` 参照 |
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
