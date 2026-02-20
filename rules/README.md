# Rules ディレクトリ

## 概要

このディレクトリには、Claude Codeエージェントの運用ルールファイルが格納されています。
複数の個別ルールファイルを統合・整理し、現在の6ファイル構成に集約されています。

## ディレクトリ構成

```
~/.claude/rules/
├── README.md            # 本ファイル（ルール構成の説明）
├── CLAUDE.md            # Claude-Mem自動生成アクティビティログ（ルール定義ではない）
├── core-workflow.md     # コアワークフロー（事実確認、エラー報告、実装完了チェック、タスク管理、Docker方針、メモリシステム）
├── execution-guard.md   # 実行ガード（ブロッカー対応、バッチ実行、SubAgent委託、デバッグ、リファクタリング、プラン作成）
├── git-safety.md        # Git安全ルール（禁止コマンド、コミット禁止ファイル、事故対応、.vscodeガイドライン）
├── secret-management.md # シークレット管理（direnv + ${VAR}方式、.envrc運用、新プロジェクト手順）
├── skill-lifecycle.md   # スキルライフサイクル（自動認識、配置、スキル化判断、横展開、重複チェック）
└── tool-selection.md    # ツール選択ガイド（Webスクレイピング、SubAgent vs Agent Teams）
```

## ルールファイル一覧

| ファイル | 目的 | 主要セクション |
|---------|------|---------------|
| `CLAUDE.md` | Claude-Memによる自動生成アクティビティログ | 最近の活動履歴（自動更新） |
| `core-workflow.md` | エージェントの基本動作ルール | 事実確認ルール、エラー報告フォーマット、実装完了チェック（STEP 1-4）、タスク管理、Docker-Only開発ポリシー、メモリシステム棲み分け |
| `execution-guard.md` | 実行時の安全制御とデバッグ手法 | ブロッカープロトコル、バッチ実行方式、SubAgent委託テンプレート、デバッグ鉄則（3-Fix Limit、4段階根本原因分析）、リファクタリング戦略、プラン作成基準 |
| `git-safety.md` | Gitリポジトリの安全運用ルール | 禁止コマンド（force-push等）と代替案、コミット禁止ファイル14カテゴリ、`git add`個別指定強制、事故対応手順、.vscodeガイドライン、リモート側推奨事項 |
| `secret-management.md` | シークレットの安全な管理方法 | direnv + ${VAR}プレースホルダー方式、.envrc階層構造、新プロジェクト追加手順、.mcp.jsonの書き方、運用ルール |
| `skill-lifecycle.md` | スキルの管理・作成・更新ルール | 自動認識、配置場所判定、スキル化判断フロー（Q0-Q3）、横展開チェック、重複チェック |
| `tool-selection.md` | ツール・エージェントの選択基準 | Webスクレイピング3段階エスカレーション、SubAgent vs Agent Teams判定 |

## 統合履歴

以下の個別ファイルが現在のルールファイルに統合されました。

| 旧ファイル | 統合先 | 統合先セクション |
|-----------|--------|-----------------|
| `quality-ops.md` | `core-workflow.md` | 全体（品質管理オペレーション） |
| `server-restart.md` | `core-workflow.md` | STEP 1: サーバー再起動 |
| `docker-policy.md` | `core-workflow.md` | SS5: Docker-Only開発ポリシー |
| `task-management.md` | `core-workflow.md` | SS4: タスク管理 |
| `plan-execution-guide.md` | `execution-guard.md` | 全体（プラン実行ガイド） |
| `debugging-strategy.md` | `execution-guard.md` | SS4: デバッグ鉄則 |
| `refactoring-strategy.md` | `execution-guard.md` | SS5: リファクタリング戦略 |
| `firecrawl-patterns.md` | `tool-selection.md` | SS1: Webスクレイピング（Firecrawl実装パターン） |
| `agent-teams.md` | `tool-selection.md` | SS2: SubAgent vs Agent Teams |

## 関連ファイル

- `~/.claude/CLAUDE.md` - エージェント運用方針（メインの指示ファイル）
- `~/.claude/skills/` - スキル定義ファイル群
- `~/.claude/commands/` - コマンド定義ファイル群
