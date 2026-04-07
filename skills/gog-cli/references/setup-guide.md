# gogcli セットアップ手順

## 初回セットアップ（このPC）

### Step 1: Google Cloud Console で OAuth Client ID を作成

1. https://console.cloud.google.com/apis/credentials を開く
2. 「認証情報を作成」→「OAuth クライアント ID」
3. アプリケーションの種類: **デスクトップアプリ**
4. 名前: `gogcli-desktop`（任意）
5. 作成 → JSONをダウンロード

**必要なAPI有効化** (初回のみ):
- https://console.cloud.google.com/apis/library で以下を有効にする:
  - Google Sheets API
  - Google Drive API
  - Gmail API（メール操作が必要な場合）
  - Google Calendar API（カレンダー操作が必要な場合）

### Step 2: credentials.json を配置

```bash
mkdir -p ~/.config/gogcli
mv ~/Downloads/client_secret_*.json ~/.config/gogcli/credentials.json
chmod 600 ~/.config/gogcli/credentials.json
```

### Step 3: セットアップスクリプト実行

```bash
~/.claude/bin/setup-gogcli
```

スクリプトが:
1. gogcli のインストール確認（なければ brew install）
2. credentials.json の存在確認
3. `gog auth credentials` で登録
4. `gog auth add` でブラウザ認証を案内

### Step 4: 動作確認

```bash
gog auth list --check
gog sheets read "SPREADSHEET_ID" "Sheet1!A1:B5"
```

## 新PCセットアップ（2台目以降）

### 前提
- `~/.claude/` が git clone/pull 済み
- `~/.envrc.shared` に gogcli 設定を追記済み

### 手順

```bash
# 1. gogcli インストール
brew install steipete/tap/gogcli

# 2. credentials.json を配置（以下のいずれか）
#    a. 別PCからコピー
scp other-mac:~/.config/gogcli/credentials.json ~/.config/gogcli/credentials.json
#    b. 1Password から取得（op CLI がある場合）
op read "op://Private/gogcli-oauth-desktop/credentials.json" > ~/.config/gogcli/credentials.json
#    c. Google Cloud Console から再ダウンロード

# 3. セットアップスクリプト実行
~/.claude/bin/setup-gogcli

# 4. ブラウザ認証（自動で開く）
# → Google アカウントでログイン → 権限許可
```

## credentials.json の保管方法

| 方式 | 手順 | 推奨度 |
|------|------|--------|
| **scp / AirDrop** | 既存PCから直接コピー | 最も手軽 |
| **1Password** | Secure Note に保存 → `op read` で取得 | 3台以上で運用する場合 |
| **iCloud Drive** | シンボリックリンク | Mac同士なら自動同期 |
| **再ダウンロード** | Google Cloud Console から | IDは同じものを再利用 |

**注意**: credentials.json は OAuth Client ID/Secret を含むため git に入れない。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `no credentials` | credentials.json 未登録 | `gog auth credentials ~/.config/gogcli/credentials.json` |
| `token expired` | 認証期限切れ | `gog auth add <email> --force-consent` |
| `insufficient scope` | APIスコープ不足 | `gog auth add <email> --services sheets,drive,gmail` |
| `API not enabled` | Google Cloud でAPI未有効化 | Cloud Console → APIライブラリ → 該当APIを有効化 |
| `redirect_uri_mismatch` | OAuth Client タイプが違う | 「デスクトップアプリ」で作り直す |

## 環境変数（~/.envrc.shared に追記）

```bash
# テンプレート: ~/.claude/templates/envrc.shared.gogcli.example
export GOGCLI_CREDENTIALS_PATH="$HOME/.config/gogcli/credentials.json"
export GOGCLI_ACCOUNT_EMAIL="your@gmail.com"
# export GOGCLI_CREDENTIALS_OP_URI="op://Private/gogcli-oauth-desktop/credentials.json"
```
