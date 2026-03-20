# 運用ルール

## git安全ルール

### 禁止コマンド

- `git push --force`, `git push -f`, `git push origin +*` → 代替: `--force-with-lease`
- `git reset --hard` → 代替: `git stash` + `git reset --soft`
- `git checkout .`, `git restore .` → 代替: 個別ファイル指定
- `git clean -f/-df` → 代替: `git clean -n` で確認後、個別削除
- `git branch -D` → 代替: `git branch -d`
- `git rebase main/master` → 代替: `git merge`
- `git update-ref` → 禁止

### ステージング方針

`git add -A`, `git add .` は禁止。ファイルを個別指定してステージング。

### コミット禁止ファイル

.env*, credentials*, 秘密鍵(*.pem/*.key), DBダンプ(*.sqlite3), node_modules/, .DS_Store, *.log, .docker/config.json, .npmrc, *.bak
詳細14カテゴリ: `git-safety-reference` スキル参照。

## 実行ガード

### ブロッカープロトコル

以下発生時、即座に停止してユーザーに確認:
- プランに記載のないファイル/モジュールの変更が必要
- テスト/検証が失敗（デバッグ中は3回まで自律試行可。3回失敗で停止）
- プラン外の変更が必要と判明
- プランに記載のない外部パッケージ/サービスへの依存が必要

禁止: ブロッカーを推測で回避。

### バッチ実行方式

タスクを3つずつバッチ化、検証ポイントを設ける。
- 単純変更: 最大5/バッチ
- 高リスク変更: 1/バッチ

### プラン作成基準

含める要素: Goal, Architecture, Tech Stack, Tasks, Verification。
タスク粒度: 2-5分、原則1ファイル、1論理変更。
各タスクに推奨: ファイルパス, 関数名, コード, 検証コマンド。

### 参照

SubAgent委託、デバッグ、リファクタリング、データ分析の詳細: `execution-patterns` スキル参照。

### 検証戦略

- **コード検査のみでの完了判断は禁止**。静的検証（構文チェック・import確認・grep）+ 実行時検証（サーバー起動・API疎通・ブラウザ動作）の両方を実施すること
- **計画に検証ステップがあれば必ず実行する**。計画自身が定義した検証項目をスキップしない
- BE変更: サーバー再起動 + APIエンドポイント疎通確認
- FE変更: ブラウザでページリロード + コンソールエラーゼロ確認 + 変更機能の動作確認
