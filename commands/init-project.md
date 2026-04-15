# /init-project

$ARGUMENTS をプロジェクト名 or 概要として使用。引数なしなら現在の cwd を初期化対象とする。

このコマンドは `project-bootstrap` スキルを起動します。詳細は `~/.claude/skills/project-bootstrap/SKILL.md` 参照。

## 用途

新プロジェクトの初期ファイル配置・シークレット管理・テンプレート適用を一括実施。

## チェックリスト

### 1. 基本ファイル
- [ ] `.gitignore` — `~/.claude/templates/project/.gitignore` をコピー + プロジェクト固有パターン追加
- [ ] `CLAUDE.md` — `~/.claude/templates/project/CLAUDE.md` をコピー + プレースホルダ置換
- [ ] `.mcp.json` — 必要時 `~/.claude/templates/project/.mcp.json.example` 参考 (`${VAR}` プレースホルダ構文)

### 2. シークレット管理
- [ ] プロジェクト固有の環境変数は `~/.zshrc` に `export NEW_KEY="..."` 追記
- [ ] `source ~/.zshrc` で反映
- [ ] `.mcp.json` 内は `${NEW_KEY}` 参照のみ (直書き禁止)
- 詳細: `secret-management` スキル

### 3. Docker 構成 (該当時)
- [ ] `Dockerfile` / `docker-compose.yml` 作成
- [ ] ホスト上 `pip/npm install` 禁止方針を CLAUDE.md に明記
- 詳細: CLAUDE.md「Docker-Only 開発」

### 4. テスト / lint 定義
- [ ] 言語別の test runner 設定 (pytest / jest / go test)
- [ ] lint (ruff / eslint 等) 設定
- [ ] CI がある場合、上記を実行する workflow 追加

### 5. task.md / plan.md 配置
- [ ] `tasks/` ディレクトリ作成 (feature 単位の plan.md 格納用)
- [ ] `~/.claude/templates/task.md` / `plan.md` をプロジェクトに合わせて配置

## 完了後

`/new-feature` で初回機能追加ワークフローに移行推奨。
