---
name: secret-management
description: |
  シークレット管理の詳細ルール。direnv + ${VAR}プレースホルダー方式によるAPIキー管理。
  .mcp.jsonの書き方（正例/禁止例）、.envrcの階層構造、新プロジェクト追加手順、
  運用ルール（direnv allow、起動ディレクトリ注意、パーミッション）、.env共存ガイド。
  .envrc/.mcp.json操作時、APIキー設定時、新プロジェクトセットアップ時に使用。
  キーワード: シークレット, API鍵, direnv, envrc, mcp.json, 環境変数, ${VAR}
  NOT for: 通常の開発作業、git操作
allowed-tools: "Read Glob Grep"
---

# シークレット管理ルール

## 1. 基本方針

APIキー・DB認証情報等のシークレットは **direnv + `${VAR}` プレースホルダー方式** で管理する。

**禁止**: `.mcp.json` や設定ファイルへのシークレット直書き
**必須**: 環境変数経由での参照（`${VAR}` 構文）

## 2. アーキテクチャ

```
direnv (.envrc) → シェル環境変数 → .mcp.json の ${VAR} 展開 → MCPサーバー
```

### ファイル階層

| ファイル | 役割 | git管理 |
|---------|------|---------|
| `~/.envrc.shared` | 全プロジェクト共通キー（OPENAI_API_KEY等） | 対象外（chmod 600） |
| `~/.claude/.envrc` | `source_env_if_exists ~/.envrc.shared` | 対象外 |
| `project/.envrc` | `source_env_if_exists ~/.envrc.shared` + プロジェクト固有キー | 対象外 |
| `~/.claude/.mcp.json` | `${VAR}` プレースホルダーで参照 | 対象外 |

### データフロー

1. `cd project/` → direnvが `project/.envrc` を自動実行
2. `.envrc` 内で `source_env_if_exists ~/.envrc.shared` → 共通キーをロード
3. プロジェクト固有キーを export（上書き可能）
4. Claude Code起動 → `.mcp.json` の `${VAR}` がシェル環境変数から展開
5. MCPサーバーが正しいキーで起動

## 3. .mcp.json の書き方

### 正しい例（${VAR}参照）

```json
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "/path/to/codex",
      "args": ["mcp-server"],
      "env": {
        "OPENAI_API_KEY": "${OPENAI_API_KEY}"
      }
    },
    "postgresql": {
      "command": "npx",
      "args": ["-y", "@henkey/postgres-mcp-server", "--connection-string", "${DB_CONNECTION_STRING}"]
    }
  }
}
```

### 禁止例（ハードコード）

```json
"env": {
  "OPENAI_API_KEY": "sk-proj-実際のキー値"
}
```

### ${VAR} 展開の仕様

| 構文 | 動作 |
|------|------|
| `${VAR}` | 環境変数VARの値に展開。未設定時はパース失敗 |
| `${VAR:-default}` | VARが未設定の場合defaultを使用 |

**適用箇所**: `command`, `args`, `env`, `url`, `headers`

## 4. .envrc の書き方

### 共通キーファイル（`~/.envrc.shared`）

```bash
# 共通APIキー — 全プロジェクトで共有
export OPENAI_API_KEY="sk-proj-..."
export ANTHROPIC_API_KEY=""
export DB_CONNECTION_STRING="postgresql://user:pass@localhost:5433/dbname"
```

### プロジェクト固有（`project/.envrc`）

```bash
# 共通キーをロード
source_env_if_exists ~/.envrc.shared

# プロジェクト固有キー（上書き可能）
export OPENAI_API_KEY="sk-proj-別のキー"
export PROJECT_SECRET="..."
```

### ~/.claude/.envrc

```bash
source_env_if_exists ~/.envrc.shared
```

## 5. 新プロジェクト追加手順

1. プロジェクトディレクトリに `.envrc` を作成
2. `source_env_if_exists ~/.envrc.shared` を記載
3. プロジェクト固有の変数を追記
4. `direnv allow` を実行

## 6. 運用ルール

### direnv allow の再実行

`.envrc` の内容を変更した場合、`direnv allow` の再実行が必要（セキュリティ機能）。

### Claude Code 起動時の注意

| 起動ディレクトリ | 読み込まれる .envrc | 結果 |
|-----------------|-------------------|------|
| `~/.claude/` | `~/.claude/.envrc` | 共通キーのみ |
| `project/` | `project/.envrc` | 共通キー + プロジェクト固有キー |
| direnvなしのディレクトリ | なし | 環境変数未設定 → MCPサーバー起動失敗の可能性 |

### パーミッション

| ファイル | パーミッション |
|---------|--------------|
| `~/.envrc.shared` | `chmod 600`（必須） |
| `project/.envrc` | `chmod 600`（推奨） |

### gitignore

以下はgit管理対象外にすること:

- `.envrc` — direnv設定ファイル
- `.envrc.shared` — 共通キーファイル
- `.mcp.json` — MCP設定（${VAR}参照でもローカル固有設定を含むため）

### プロジェクト別 .mcp.json の制約

同名MCPサーバーをプロジェクト `.mcp.json` で再定義した場合、**envだけの上書きは不可**。サーバー定義全体が置き換わる。direnvで変数値を切り替える方式を推奨。

## 7. 既存の .env ファイルとの共存

- `.envrc`（direnv）: シェル環境変数 → Claude Code / MCPサーバーが参照
- `.env`（dotenv）: アプリケーション（Docker, Node.js等）が直接読み込み

両方の併用は可能。ただし同一変数名で値が異なる場合は混乱の原因になるため、段階的に `.envrc` に統一を推奨。

## 8. セットアップ要件

| 要件 | コマンド |
|------|---------|
| direnv | `brew install direnv` |
| shell hook | `~/.zshrc` に `eval "$(direnv hook zsh)"` |
| ヘルパー関数 | `~/.config/direnv/direnvrc` に `source_env_if_exists` 定義 |
