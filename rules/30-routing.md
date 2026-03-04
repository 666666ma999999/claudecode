# スキルルーティング & 追加ルール

## スキルルーティング

回答・作業前に、以下のマッピングを確認し該当スキルを参照すること:

| トリガー | 参照スキル |
|---------|-----------|
| BE新機能追加、APIエンドポイント追加、BEエクステンション作成、バックエンド設計、HookPoint実装、新機能追加、エクステンション作成、プラグインアーキテクチャ、backend feature、new API endpoint、extension pattern、plugin architecture、add backend、create extension | `be-extension-pattern` |
| SubAgent委託、デバッグ、リファクタリング、大量データ分析 | `execution-patterns` |
| FE+BE連携、APIコントラクト、エクステンション共有設定、クロスリポ連携、デプロイ協調 | `fe-be-extension-coordination` |
| 新機能追加、ページ追加、ウィジェット追加、エクステンション作成、FEアーキテクチャ、フロントエンド設計 | `fe-extension-pattern` |
| git commit/push/add、コミット禁止ファイル詳細、事故対応 | `git-safety-reference` |
| .envrc/.mcp.json操作、APIキー設定、新プロジェクト環境 | `secret-management` |
| 新プロジェクト初期化 | `project-bootstrap` |
| スキル作成・更新・判断、横展開チェック | `skill-lifecycle-reference` |
| Webスクレイピング、Agent Teams構成 | `tool-selection-reference` |

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
詳細フロー: `skill-lifecycle` スキル参照。
