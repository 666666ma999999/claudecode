# Commit, Push & PR

$ARGUMENTS を PR のコンテキストとして使用する。引数なしの場合は変更内容から自動推論する。

## Pre-compute（情報収集）

以下を並列で実行し、結果を把握する:
1. `git status` で変更ファイル一覧を取得
2. `git diff --stat` で変更規模を把握
3. `git diff` で変更内容の詳細を確認
4. `git log --oneline -5` で直近のコミットスタイルを確認
5. 現在のブランチ名を確認（`git branch --show-current`）

## Lint（品質チェック）

プロジェクトに以下がある場合のみ実行:
- `pyproject.toml` / `setup.cfg` → `docker compose exec -T dev bash -lc 'ruff check --fix'`
- `package.json` に lint script → `docker compose exec -T dev bash -lc 'npm run lint'`
- いずれもなければスキップ

## Stage & Commit

1. 変更ファイルを**個別に** `git add` する（`git add -A` / `git add .` は禁止）
   - .env*, credentials*, *.pem, *.key, *.sqlite3, node_modules/, .DS_Store, *.log は除外
2. コミットメッセージを生成:
   - リポジトリの直近コミットスタイルに合わせる
   - 1行目: 変更の要約（50文字以内）
   - 空行後: 詳細説明（必要な場合のみ）
3. `git commit` を実行

## Push

1. リモートブランチの存在確認
2. `git push -u origin <branch>` で push
   - main/master への直接 push の場合はユーザーに確認

## PR 作成

1. `gh pr create` で PR を作成:
   - タイトル: コミットメッセージの1行目
   - ボディ: ## Summary + ## Test Plan 形式
   - $ARGUMENTS があればコンテキストに反映
2. PR の URL を表示

## エラー時

- lint 失敗 → 自動修正を試み、修正できなければ報告
- push 失敗 → `git pull --rebase` を試み、コンフリクトがあれば報告
- PR 作成失敗 → エラー内容を表示
