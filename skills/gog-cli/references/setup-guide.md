# gogcli セットアップ手順

## 概要

credentials.json を iCloud Drive で全Mac共有。token は各PCで個別発行。

```
[Google Cloud Console] → credentials.json DL
        ↓
[iCloud Drive] ~/Library/Mobile Documents/com~apple~CloudDocs/secure/gogcli/credentials.json
        ↓ (自動同期)
[各PC] setup-gogcli → gog auth add → ブラウザ認証 → 完了
```

## 初回セットアップ（1台目）

### Step 1: OAuth Client ID 作成

1. https://console.cloud.google.com/apis/credentials を開く
2. 「認証情報を作成」→「OAuth クライアント ID」→ **デスクトップアプリ**
3. 作成 → JSON をダウンロード

### Step 2: API 有効化

https://console.cloud.google.com/apis/library で以下を有効化:
- Google Sheets API
- Google Drive API
- （必要に応じて Gmail API, Calendar API）

### Step 3: iCloud Drive に配置

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/secure/gogcli
mv ~/Downloads/client_secret_*.json \
  ~/Library/Mobile\ Documents/com~apple~CloudDocs/secure/gogcli/credentials.json
```

### Step 4: セットアップスクリプト実行

```bash
~/.claude/bin/setup-gogcli
```

スクリプトが自動で:
1. gogcli のインストール確認（なければ brew install）
2. credentials.json を iCloud Drive から検出
3. `gog auth credentials` で登録
4. メールアドレスを聞いて `gog auth add` → ブラウザ認証

### Step 5: 動作確認

```bash
gog auth list --check
gog sheets read "SPREADSHEET_ID" "Sheet1!A1:B5"
```

## 2台目以降のセットアップ

### 前提
- `~/.claude/` を git pull 済み
- iCloud Drive が同期済み（credentials.json が届いている）

### 手順（2コマンドだけ）

```bash
# 1. git pull（スクリプト取得）
git -C ~/.claude pull

# 2. セットアップ実行（iCloud Driveから自動検出）
~/.claude/bin/setup-gogcli
```

ブラウザが開くのでGoogleアカウントでログイン → 完了。

### credentials.json を直接指定する場合

```bash
# パス指定
~/.claude/bin/setup-gogcli ~/Downloads/client_secret_*.json

# パス + メールアドレス指定
~/.claude/bin/setup-gogcli ~/Downloads/client_secret_*.json your@gmail.com
```

## credentials.json の検出優先順位

| 優先度 | パス |
|--------|------|
| 1 | 引数で指定したパス |
| 2 | `~/.config/gogcli/credentials.json` |
| 3 | `~/Library/Mobile Documents/com~apple~CloudDocs/secure/gogcli/credentials.json` |
| 4 | 環境変数 `$GOGCLI_CREDENTIALS_PATH` |

## OAuth consent screen の設定

### Publishing status は「本番」にする

「テスト」モードではトークンが **7日で失効** する。個人利用でも必ず「本番に公開」すること。

1. https://console.cloud.google.com/auth/audience を開く
2. 「テスト中」→「アプリを公開」をクリック
3. 個人利用（自分のアカウントのみ）なので Google 審査は不要

### 「このアプリは Google で確認されていません」警告

自分で作った OAuth Client なので問題ない。
→ 画面左下「詳細」→「(安全ではないページ)に移動」で進む。

## Workspace アカウントのシートにアクセスする場合

### 問題

Google Workspace（組織）が所有するスプレッドシートに個人 Gmail (`100ameros@gmail.com` 等) で API アクセスすると **403 forbidden** になる。ブラウザでは開けても、API では OAuth したアカウント本人の権限で判定されるため。

### 原因の判別

| ブラウザで開ける？ | `gog sheets read` の結果 | 原因 |
|:---:|:---:|---|
| YES | 403 | Workspace 外部共有禁止 or 別アカウントでログイン中 |
| NO | 403 | そもそもアクセス権なし |
| YES | 200 | 正常 |

### 対処（優先順）

#### 1. Workspace アカウントで gogcli 認証を追加（推奨）

```bash
gog auth add workspace-user@company.com --services sheets,drive --force-consent
```

使用時に `--account` で切り替え:
```bash
gog sheets read --account workspace-user@company.com "SPREADSHEET_ID" "Sheet1!A1:G5"
```

**注意**: Workspace 管理者がサードパーティ OAuth アプリをブロックしている場合は失敗する。

#### 2. 個人 Gmail にシートをコピー（最終手段）

- 外部共有禁止の組織ではコピー操作自体がブロックされる可能性あり
- 元データとの同期が途切れるため、静的スナップショットで十分な場合のみ

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `no credentials` | `gog auth credentials <path>` を再実行 |
| `token expired` | `gog auth add <email> --force-consent` |
| `insufficient scope` | `gog auth add <email> --services sheets,drive,gmail` |
| `API not enabled` | Cloud Console → APIライブラリ → 該当APIを有効化 |
| `redirect_uri_mismatch` | OAuth Client を「デスクトップアプリ」で作り直す |
| `403 forbidden` (Sheets) | 上記「Workspace アカウントのシートにアクセスする場合」参照 |
| `refresh token missing` | Keychain の問題。`gog auth remove <email>` → `gog auth add` で再認証 |
| `このアプリは確認されていません` | 「詳細」→「(安全ではないページ)に移動」で続行 |
| iCloud 同期が遅い | Finder で iCloud Drive を開くと同期が促進される |
