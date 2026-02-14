# コアワークフロー

## 1. 事実確認ルール（最優先）

現状の事実に関する質問には**必ずツールで実態を確認してから回答**すること。

**禁止**: 推測・一般論での回答、「通常は〜」という前提、ツール実行なしでの断定
**必須手順**: 1.関連ファイル・設定・状態をツールで確認 → 2.確認結果に基づき回答 → 3.確認不可なら「未確認」と明示

| 質問の種類 | 確認方法 |
|-----------|---------|
| git設定 | `git remote -v`, `git log`, `git status` |
| ファイル存在 | `ls`, `Glob` |
| 設定内容 | `Read`でファイル読み込み |
| プロセス状態 | `ps`, `curl` |
| hook/自動化 | 設定ファイルとスクリプトを`Read` |

## 2. エラー報告フォーマット

エラー発生時は以下の構造で報告：

```
0. Sentry Issue URL（任意・該当時のみ）
1. 症状: エラーメッセージの正確な引用 + スクリーンショット
2. 原因: コードの流れ追跡→根本原因特定（ファイル名:行番号）、データ変遷（入力→変換→出力）
3. 経緯: 過去の変更履歴との関係、スキルドキュメントとの不整合
4. 選択肢: 複数の修正方針（最低2つ）、各トレードオフ、影響範囲
```

## 3. 実装完了チェック（必須）

コード修正・機能追加完了後、`implementation-checklist` スキルに従って STEP 1-4 を全て実行すること。完了報告前にスキップ禁止。

## 4. タスク管理（task.mdベース）

| コマンド | 用途 | タイミング |
|---------|------|-----------|
| `/launch-task` | 新規タスク開始・task.md生成 | Issue発行後 |
| `/onboard` | 中断した作業の復帰 | セッション開始時 |
| `/update-task` | task.mdの状態更新 | 作業の節目・中断前 |
| `/update-task --checkpoint` | 中断準備（状態保存） | 作業中断時 |
| `/update-task --complete` | タスク完了処理 | 全作業完了時 |
| `/review` | Codexコードレビュー | 実装完了後・commit前 |
| `/verify-step` | STEP完了確認 | 各STEP実行後 |

**ディレクトリ構成**: `project-root/.claude/workspace/task.md`（現在のタスク状態）、`~/.claude/commands/`（コマンド定義）、`~/.claude/templates/task.md`（テンプレート）

**ワークフロー**: 新規→`/launch-task`→Plan→実装 | 中断→`/update-task --checkpoint` | 再開→`/onboard` | 完了→`/update-task --complete`→スキル横展開→Issue Close

**task.md必須セクション**:

| セクション | 用途 |
|-----------|------|
| メタ情報 | Issue、ステータス、日時 |
| 成功基準 | 完了条件のチェックリスト |
| 実装計画 | Phase分割された作業項目 |
| 中断時の状態 | 次のアクション、未解決問題 |
| 学んだこと | 完了時の知見記録 |

## 5. Docker-Only開発ポリシー

**原則**: 依存管理・ビルド・実行はDocker経由。ホスト環境の汚染を防止。

**禁止コマンド（ホスト上）**:

| カテゴリ | 禁止コマンド |
|---------|-------------|
| Python | `pip install`, `pip3 install`, `python -m pip`, `python -m venv`, `virtualenv`, `uv pip/venv`, `poetry install/add`, `conda install/create` |
| Node.js | `npm install`, `npm i`, `npx`, `yarn`, `pnpm`, `bun install/add` |
| 環境有効化 | `source venv/bin/activate`, `. .venv/bin/activate` |

**適用除外**: `.mcp.json`のMCPサーバー設定、Claude Code自体のツール拡張・プラグイン設定

**正しい実行方法**: `docker compose exec dev <コマンド>`
**強制メカニズム**: `permissions.deny`でブロック + `block-host-installs.py`ですり抜け防止

## 6. メモリシステム棲み分け

| システム | 目的 | 記録対象 |
|---|---|---|
| Claude-Mem | 「何をしたか」の活動記録 | ツール使用・セッション活動（自動） |
| Memory MCP | 「何を知っているか」の知識蓄積 | 設計判断・方針・技術知見（意図的に保存） |

**Memory MCP保存トリガー**: ユーザーが「覚えておいて」と明示、新方針決定時、再利用可能な知見発見時
**記録しない**: 一時的作業状態、SKILL.md/rulesに既記載の情報、機密情報
