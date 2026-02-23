---
name: project-bootstrap
description: |
  新プロジェクト初期化チェックリスト。direnv .envrc作成、.gitignore整備、Docker設定確認、
  CLAUDE.md作成、テスト・lint定義、task.mdテンプレート配置を統合実行する。
  /init-project コマンド実行時、新しいプロジェクトディレクトリのセットアップ時に使用。
  キーワード: プロジェクト初期化, セットアップ, init, 新規プロジェクト, 環境構築
  NOT for: 既存プロジェクトの通常作業、コード修正、デバッグ
allowed-tools: "Bash Read Write Edit Glob Grep"
---

# プロジェクト初期化チェックリスト

## 使用方法
プロジェクトディレクトリで実行。テンプレートは `~/.claude/templates/project/` から取得。

## チェックリスト

### 1. 基本ファイル作成
- [ ] `.gitignore` — `~/.claude/templates/project/.gitignore` をコピーしてプロジェクト固有パターンを追加
- [ ] `CLAUDE.md` — `~/.claude/templates/project/CLAUDE.md` をコピーしてプレースホルダーを置換
- [ ] `.mcp.json` — 必要に応じて `~/.claude/templates/project/.mcp.json.example` を参考に作成

### 2. シークレット管理（direnv）
- [ ] `.envrc` 作成 — `~/.claude/templates/project/.envrc` をコピー
- [ ] `source_env_if_exists ~/.envrc.shared` が含まれていることを確認
- [ ] プロジェクト固有の環境変数を追記
- [ ] `chmod 600 .envrc`
- [ ] `direnv allow` 実行

### 3. Docker環境（該当時）
- [ ] `docker-compose.yml` が存在するか確認
- [ ] `docker compose up -d` で起動確認
- [ ] ホスト上の `pip install` / `npm install` は禁止（Docker経由）

### 4. 開発環境
- [ ] テスト実行コマンドを確認・CLAUDE.mdに記載
- [ ] lint/formatコマンドを確認・CLAUDE.mdに記載

### 5. タスク管理
- [ ] `.claude/workspace/` ディレクトリ作成（必要時）

## テンプレート適用コマンド例

```bash
# テンプレートコピー
cp ~/.claude/templates/project/.gitignore ./
cp ~/.claude/templates/project/CLAUDE.md ./
cp ~/.claude/templates/project/.envrc ./

# direnv設定
chmod 600 .envrc
direnv allow

# 確認
direnv status
```
