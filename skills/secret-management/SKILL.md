---
name: secret-management
description: |
  シークレット管理の詳細ルール。~/.zshrc 直接 export + ${VAR}プレースホルダー方式によるAPIキー管理。
  .mcp.jsonの書き方（正例/禁止例）、新プロジェクト追加手順、起動時の注意点、パーミッション。
  .mcp.json操作時、APIキー設定時、新プロジェクトセットアップ時に使用。
  キーワード: シークレット, API鍵, zshrc, mcp.json, 環境変数, ${VAR}
  NOT for: 通常の開発作業、git操作
allowed-tools: "Read Glob Grep"
---

# シークレット管理ルール

## 1. 基本方針

APIキー・DB認証情報等のシークレットは **`~/.zshrc` で直接 export + `.mcp.json` の `${VAR}` プレースホルダー方式** で管理する。

**禁止**: `.mcp.json` や設定ファイルへのシークレット直書き
**必須**: 環境変数経由での参照（`${VAR}` 構文）

## 2. アーキテクチャ

```
~/.zshrc (export) → ターミナルのシェル環境変数 → Claude Code 起動時に継承 → .mcp.json の ${VAR} 展開 → MCPサーバー
```

### ファイル一覧

| ファイル | 役割 | git管理 |
|---------|------|---------|
| `~/.zshrc` | 全シークレットを `export` で定義 | 対象外（ホーム直下） |
| `~/.claude/.mcp.json` | `${VAR}` プレースホルダーで参照 | 対象外 |

### データフロー

1. ターミナル（iTerm / Terminal.app）起動時に `~/.zshrc` が読まれシェル環境変数が設定される
2. そのターミナルから `claude` を起動 → Claude Code がシェル環境変数を継承
3. `.mcp.json` の `${VAR}` がシェル環境変数から展開される
4. MCPサーバーが正しいキーで起動

**重要**: Claude Code を Launchpad/Dock から GUI 起動すると `~/.zshrc` が読まれず、環境変数が空のまま MCP が起動して認証失敗する。**必ずターミナルから起動すること**。

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

## 4. ~/.zshrc の書き方

```bash
# OpenAI API Key
export OPENAI_API_KEY="sk-proj-..."

# xAI (Grok) API
export XAI_API_KEY="xai-..."

# DB
export DB_CONNECTION_STRING="postgresql://user:pass@localhost:5433/dbname"
```

プロジェクト固有キーが必要な場合も同様に `~/.zshrc` に追記する。ディレクトリスコープでの切り替えは不可（全シェルで同じ値）。

## 5. 新プロジェクト追加手順

1. プロジェクトの `.mcp.json` に `${VAR}` 参照でエントリを追加
2. 新しいキーが必要なら `~/.zshrc` に `export NEW_KEY="..."` を追加
3. ターミナルを再起動（または `source ~/.zshrc`）
4. そのターミナルから `claude` を起動
5. `claude mcp list` で `✓ Connected` 確認

## 6. 運用ルール

### シークレットの更新手順

1. `~/.zshrc` の該当 export 行を新しい値に書き換える
2. `source ~/.zshrc` で現シェルに反映
3. Claude Code を再起動（シェル環境変数を再継承するため）
4. `claude mcp list` で動作確認

### Claude Code 起動時の注意

| 起動方法 | `~/.zshrc` 読み込み | MCP 動作 |
|---------|-------------------|---------|
| ターミナルから `claude` | される | ✓ 正常 |
| Launchpad / Dock | **されない** | ✗ MCP 認証失敗 |
| VSCode 拡張 | 統合ターミナル設定による | 要検証 |

### パーミッション

| ファイル | パーミッション |
|---------|--------------|
| `~/.zshrc` | `chmod 644`（デフォルトで十分。ホーム直下でユーザー権限） |

### gitignore

以下はgit管理対象外にすること:

- `~/.zshrc` はそもそも git 管理されるべきではない（dotfiles リポに含める場合はシークレットを別出しする設計が必要）
- `.mcp.json` — MCP設定（${VAR}参照でもローカル固有設定を含むため）

### プロジェクト別 .mcp.json の制約

同名MCPサーバーをプロジェクト `.mcp.json` で再定義した場合、**envだけの上書きは不可**。サーバー定義全体が置き換わる。

## 7. 既存の .env ファイルとの共存

- `~/.zshrc`: シェル環境変数 → Claude Code / MCPサーバーが参照
- `.env`（dotenv）: アプリケーション（Docker, Node.js等）が直接読み込み

両方の併用は可能。同一変数名で値が異なる場合は混乱の原因になるため、MCP 用は `~/.zshrc`、アプリ用は `.env` と役割を明確に分けること。

## 8. マルチPC運用時の注意

- `~/.zshrc` のシークレット行は git 管理外のファイルに書くこと（dotfiles リポに含めない）
- 別PCへのキー受け渡しは手動（AirDrop, 1Password 等）
- マルチPC間でのキー同期は手動。ローテート時は全PC更新が必要
