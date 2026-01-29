# Xスクレイピング トラブルシューティング

## よくある問題と解決策

### 0. Googleアカウント/通常のChromeが使えなくなった

**症状:**
- Chromeを開いてもGoogleアカウントにログインできない
- ブックマークや拡張機能が消えている
- 「このブラウザまたはアプリは安全でない可能性があります」

**原因:**
デバッグ用Chrome（一時プロファイル使用）が起動したままになっている。

**解決:**
```bash
# すべてのChromeを終了
pkill -9 Chrome

# 確認（何も出なければOK）
pgrep Chrome

# Dockから通常のChromeを起動
# → Googleアカウント、ブックマーク等が復帰
```

**予防:**
Cookie取得作業後は必ず `pkill Chrome` してから通常Chromeを使用する。

---

### 1. Playwrightで直接ログインするとブロックされる

**症状**: ユーザー名入力フィールドで入力を受け付けない、またはbot検知エラー

**原因**: Xはブラウザ自動化ツールを検知してブロックする

**解決策**:
- 直接ログインは諦める
- 手動ログイン済みのChromeからCookieを取得して使用
- リモートデバッグ経由でCookie取得

```bash
# NG: Playwrightで直接ログイン（ブロックされる）
# OK: 手動ログイン後のCookie利用
```

---

### 2. Chrome起動時に「ポートが使用されていません」

**症状**: `curl http://localhost:9222/json/version` で応答なし

**原因**:
- 既存のChromeプロセスが残っている
- `--remote-debugging-port`オプションが適用されていない

**解決策**:

```bash
# 1. 全Chromeを強制終了
pkill -9 Chrome

# 2. プロセス確認（何も出なければOK）
pgrep Chrome

# 3. デバッグモードで起動（&をつけてバックグラウンド）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# 4. 起動確認
sleep 3
curl -s http://localhost:9222/json/version
```

---

### 3. `open -a "Google Chrome" --args` でオプションが効かない

**症状**: `open`コマンドで起動してもデバッグポートが有効にならない

**原因**: macOSの`open`コマンドは既存プロセスに引数を渡せない場合がある

**解決策**: フルパスで直接実行

```bash
# NG
open -a "Google Chrome" --args --remote-debugging-port=9222

# OK
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 &
```

---

### 4. 「認証トークンなし」エラー

**症状**: Cookie取得時に認証トークンが見つからない

**原因**: ChromeでXにログインしていない

**解決策**:
1. デバッグモードで起動したChrome内で https://twitter.com にアクセス
2. 手動でログイン（ユーザー名、パスワード、2FA等）
3. ホーム画面が表示されたらスクリプト実行

---

### 5. 収集時に「ログインしていません」

**症状**: Cookie読み込み後もログイン状態が認識されない

**原因**:
- Cookieの有効期限切れ
- Cookieファイルが空または破損

**解決策**:
```bash
# Cookieファイル確認
cat x_profile/cookies.json | python -m json.tool | head -20

# 空なら再取得
# auth_tokenが含まれているか確認
grep "auth_token" x_profile/cookies.json
```

---

### 6. 収集件数が0件

**症状**: スクロールしてもツイートが収集されない

**原因**:
- XのHTML構造変更でセレクタが無効
- 検索結果が0件

**解決策**:
```python
# 現在のセレクタを確認（ブラウザ開発者ツールで）
# data-testid="tweet" が存在するか
# data-testid="tweetText" が存在するか

# セレクタ更新が必要な場合はx_collector.pyを修正
```

---

### 7. Docker環境でGUI表示できない

**症状**: headless=Falseでブラウザが起動しない

**原因**: Docker内にディスプレイがない

**解決策**:
- VNC環境を構築（Dockerfile.vnc参照）
- またはheadless=Trueで実行（ただしbot検知されやすい）

```dockerfile
# VNC環境構築例
FROM mcr.microsoft.com/playwright/python:v1.57.0-jammy
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y xvfb x11vnc fluxbox novnc websockify supervisor
```

---

---

### 7. Docker + VNC 環境が動作しない

**症状:**
- VNC接続後に画面が真っ黒/空白
- noVNCでConnectしても何も表示されない
- ブラウザが起動しない

**原因:**
Docker + VNC環境は設定が複雑で不安定。

**解決策:**
**Docker + VNC は諦めてローカル実行を推奨。**

```bash
# ローカル環境セットアップ
python3 -m venv venv
source venv/bin/activate
pip install playwright
playwright install chromium
```

**理由:**
- VNCの設定（Xvfb, x11vnc, fluxbox, novnc, websockify）が複雑
- 各コンポーネントのバージョン/パス差異で動作しないことが多い
- ローカル実行なら10分でセットアップ完了

---

### 8. Cookie期限切れで「ログインしていません」

**症状:**
- 以前は動いていたスクリプトが「ログインしていません」エラー
- 収集件数が0件

**原因:**
CookieのAuth Tokenが期限切れ。

**解決:**
Cookie再取得手順を実行：

```bash
# 1. Chrome終了
pkill -9 Chrome

# 2. デバッグChrome起動
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# 3. Chromeで https://twitter.com にログイン

# 4. Cookie取得（別ターミナル）
cd /path/to/project
source venv/bin/activate
python scripts/setup_cookies.py  # または手動でCDP接続

# 5. デバッグChrome終了
pkill -9 Chrome
```

**予防:**
- 月1回程度、定期的にCookieを更新
- スクリプトにログイン確認処理を入れる

---

## デバッグ用コマンド集

```bash
# Chrome関連
pgrep Chrome                              # プロセス確認
pkill -9 Chrome                           # 強制終了
lsof -i :9222                             # ポート使用確認
curl -s http://localhost:9222/json/version # 接続テスト

# Cookie確認
cat x_profile/cookies.json | python -m json.tool | head
grep auth_token x_profile/cookies.json

# Playwright確認
python -c "from playwright.sync_api import sync_playwright; print('OK')"
playwright install chromium
```

## OS別 Chrome起動コマンド

```bash
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Ubuntu/Debian
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Windows (PowerShell)
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir=$env:TEMP\chrome-debug
```
