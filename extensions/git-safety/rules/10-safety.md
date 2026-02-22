# 安全ルール（短縮版）

## git禁止コマンド

- `git push --force`, `git push -f`, `git push origin +*` → 代替: `--force-with-lease`
- `git reset --hard` → 代替: `git stash` + `git reset --soft`
- `git checkout .`, `git restore .` → 代替: 個別ファイル指定
- `git clean -f/-df` → 代替: `git clean -n` で確認後、個別削除
- `git branch -D` → 代替: `git branch -d`
- `git rebase main/master` → 代替: `git merge`
- `git update-ref` → 禁止

## ステージング方針

`git add -A`, `git add .` は禁止。ファイルを個別指定してステージング。

## コミット禁止ファイル

.env*, credentials*, 秘密鍵(*.pem/*.key), DBダンプ(*.sqlite3), node_modules/, .DS_Store, *.log, .docker/config.json, .npmrc, *.bak
詳細14カテゴリ: `git-safety-reference` スキル参照。
