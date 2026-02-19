# CDP接続パターン詳細

## リモートChrome接続（CDP）によるbot検知回避

### 背景

多くのサイト（X/Twitter、Google、一部のECサイト等）は、Playwrightが起動するブラウザを検知してブロックする：
- `--enable-automation` フラグの検出
- WebDriverプロパティの検出
- ヘッドレスモードの特徴検出

**Playwrightで直接ログインしようとするとブロックされる**ケースが多い。

### 解決策: 手動ログイン済みChromeへのCDP接続

1. 通常のChromeを**リモートデバッグモード**で起動
2. そのChromeで**手動でログイン**（bot検知されない）
3. PlaywrightからCDP経由で接続し、**Cookieを抽出**
4. 抽出したCookieを使って自動化

### 実装手順

#### ステップ1: 全てのChromeを終了

```bash
pkill -9 Chrome
pgrep Chrome  # 何も出なければOK
```

#### ステップ2: デバッグモードでChrome起動

```bash
# macOS
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Linux
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Windows (PowerShell)
& "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir=$env:TEMP\chrome-debug
```

#### ステップ3: 接続確認

```bash
curl -s http://localhost:9222/json/version
# JSONが返ればOK
```

#### ステップ4: Chromeで手動ログイン

開いたChromeで対象サイトにアクセスし、通常通りログイン。

#### ステップ5: PlaywrightでCookie取得

```python
from playwright.sync_api import sync_playwright
import json
from pathlib import Path

def extract_cookies_via_cdp(domain_filter: str, output_path: str = "cookies.json"):
    """
    リモートChromeからCookieを抽出して保存

    Args:
        domain_filter: 抽出するドメイン（例: "twitter.com"）
        output_path: 保存先パス
    """
    with sync_playwright() as p:
        # CDP経由でChromeに接続
        browser = p.chromium.connect_over_cdp("http://localhost:9222")

        contexts = browser.contexts
        if not contexts:
            print("エラー: ブラウザコンテキストなし")
            return False

        context = contexts[0]
        cookies = context.cookies()

        # ドメインでフィルタ
        filtered = [c for c in cookies if domain_filter in c.get('domain', '')]

        # 認証トークン確認
        auth_token = next((c for c in filtered if c['name'] == 'auth_token'), None)

        # 保存
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(filtered, f, indent=2)

        print(f"Cookie保存: {len(filtered)}個")
        print(f"認証トークン: {'あり' if auth_token else 'なし'}")

        browser.close()
        return True

# 使用例
extract_cookies_via_cdp("twitter.com", "x_profile/cookies.json")
```

#### ステップ6: 保存したCookieで自動化

```python
def automate_with_saved_cookies(cookie_file: str, url: str):
    """保存済みCookieを使って自動化"""

    with open(cookie_file, 'r') as f:
        cookies = json.load(f)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context(
            viewport={"width": 1280, "height": 900},
            locale="ja-JP",
        )

        # Cookieを適用
        context.add_cookies(cookies)

        page = context.new_page()
        page.goto(url)

        # ログイン状態で操作可能
        # ...

        context.close()
        browser.close()

# 使用例
automate_with_saved_cookies("x_profile/cookies.json", "https://twitter.com/home")
```

### 重要なポイント

| 項目 | 説明 |
|------|------|
| **--user-data-dir** | 一時ディレクトリを指定（既存プロファイルと競合防止） |
| **ポート確認** | `curl localhost:9222/json/version` でJSON応答を確認 |
| **Cookie有効期限** | サイトにより異なる（X/Twitterは数週間〜数ヶ月） |
| **再取得タイミング** | ログイン失敗時、または定期的に（月1回程度） |

### Chrome使い分けの注意（重要）

デバッグChromeは `--user-data-dir=/tmp/chrome-debug` で**一時プロファイル**を使用するため、**通常のGoogleアカウントは使えない**。

#### 症状
- Chromeを開いてもGoogleアカウントにログインできない
- ブックマークや拡張機能がない
- 「このブラウザまたはアプリは安全でない可能性があります」エラー

#### 原因
デバッグ用Chromeが起動したままになっている。

#### 解決手順

```bash
# 1. すべてのChromeを終了
pkill -9 Chrome

# 2. プロセス確認（何も出なければOK）
pgrep Chrome

# 3. Dockから通常のChromeを起動
# → Googleアカウントにアクセス可能
```

#### 運用ルール

| Chrome種類 | 起動方法 | プロファイル | 用途 |
|-----------|---------|-------------|------|
| **通常Chrome** | Dockクリック | ユーザーの本物のプロファイル | 普段使い、Googleログイン |
| **デバッグChrome** | ターミナルから `--remote-debugging-port=9222` | 一時プロファイル (`/tmp/`) | スクレイピング用Cookie取得のみ |

**作業フロー:**
```
1. 通常Chrome終了（pkill Chrome）
2. デバッグChrome起動
3. 対象サイトにログイン・Cookie取得
4. デバッグChrome終了（pkill Chrome）
5. 通常Chrome起動（Dockから）← 忘れずに！
```

### 対象サイト例

この手法が有効なサイト：
- **X (Twitter)** - ユーザー名入力時点でブロック
- **Google** - 「安全でないブラウザ」エラー
- **一部のECサイト** - CAPTCHA表示

## 2FA一時停止→CDP再接続パターン（2段階ログインフロー）

SMS認証など2FAが必須のサイトで、認証コード入力をユーザーに委ねる2段階フロー。

### 問題

2FAが必須のサイトでは、スクリプトを1回で完結できない。再ログインすると新しい認証コードが発行されるため、コード取得後に再実行しても古いコードは無効になる。

### 解決策: ブラウザを開いたまま2段階に分離

**Step 1: ログイン→2FA画面で停止（ブラウザ維持）**

```python
from playwright.sync_api import sync_playwright
import time, os

def login_and_wait_for_2fa(email: str, password: str, login_url: str):
    """ログインし、2FA画面でブラウザを開いたまま停止"""
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            slow_mo=300,
            args=["--remote-debugging-port=9333"]  # CDP接続用ポート
        )
        context = browser.new_context(
            viewport={"width": 1280, "height": 800},
            locale="ja-JP",
            timezone_id="Asia/Tokyo"
        )
        page = context.new_page()

        # ログイン処理（サイト固有）
        page.goto(login_url, wait_until="domcontentloaded", timeout=60000)
        # ... メール入力、パスワード入力、送信 ...

        print("2FA画面に到達。認証コードを待機中...")
        print("Step 2スクリプトで認証コードを入力してください。")

        # ブラウザを開いたまま最大10分待機
        time.sleep(600)

        context.close()
        browser.close()
```

**Step 2: CDP接続→認証コード入力**

```python
from playwright.sync_api import sync_playwright
import sys

def enter_2fa_code(code: str, auth_state_path: str = "auth_state.json"):
    """Step1で開いたブラウザにCDP接続し、認証コードを入力"""
    with sync_playwright() as p:
        # Step1のブラウザにCDP経由で接続
        browser = p.chromium.connect_over_cdp("http://localhost:9333")

        context = browser.contexts[0]  # Step1のコンテキストを再利用
        page = context.pages[0]        # 2FA画面のページを再利用

        # 認証コード入力（複数セレクタで段階的に試行）
        code_input = page.locator(
            'input[placeholder*="認証"], input[name*="code"], '
            'input[name*="otp"], input[type="tel"], '
            'input[type="number"], input[inputmode="numeric"]'
        )
        if code_input.count() == 0:
            code_input = page.locator('input[type="text"]')

        code_input.first.fill(code)

        # 認証ボタンクリック
        verify_btn = page.locator(
            'button:has-text("認証"), button:has-text("完了"), '
            'button:has-text("Verify"), button[type="submit"]'
        )
        verify_btn.first.click()
        page.wait_for_load_state("domcontentloaded")

        # 認証状態を保存
        context.storage_state(path=auth_state_path)
        print(f"認証成功。状態を {auth_state_path} に保存しました。")

if __name__ == "__main__":
    enter_2fa_code(sys.argv[1])
```

### 運用フロー

```
ターミナル1: python3 login_step1.py
  → ブラウザ起動 → ログイン → 2FA画面で停止
  → SMSが届く

ターミナル2: python3 login_step2.py <認証コード>
  → CDP接続 → コード入力 → 認証完了 → 状態保存
```

### 重要ポイント

| 項目 | 値 |
|------|-----|
| CDPポート | 9333（他と競合しないポートを選択） |
| 待機時間 | 600秒（10分、SMS到着を余裕を持って待つ） |
| コンテキスト再利用 | `browser.contexts[0]` でStep1のセッションをそのまま使用 |
| 再ログイン禁止 | Step2で新たにログインすると新コードが発行され無限ループになる |

### 適用サイト例

この手法が有効なサイト:
- **メルカリ** - SMS認証必須
- **銀行・証券サイト** - ワンタイムパスワード
- **ECサイト** - SMS/メール認証

## Cookie有効期限の管理パターン

### 背景

CDP接続で取得したCookieには有効期限がある。期限切れになると自動化が失敗する。

### サイト別の目安

| サイト | Cookie有効期間（目安） |
|--------|----------------------|
| X (Twitter) | 数週間〜数ヶ月 |
| Google | 数週間（頻繁に再認証要求） |
| 一般的なECサイト | 数日〜数週間 |

### 推奨フロー

```
[定期実行スクリプト]
    ↓
ログイン状態確認（セレクタで判定）
    ↓
┌─ ログイン済み → 通常処理を実行
│
└─ 未ログイン → Cookie再取得フローへ
```

### 実装例

```python
def check_login_status(page) -> bool:
    """ログイン状態を確認"""
    try:
        # サイト固有のログイン済み要素を確認
        page.wait_for_selector(
            '[data-testid="SideNav_AccountSwitcher_Button"]',  # X/Twitterの例
            timeout=5000
        )
        return True
    except:
        return False

def run_with_cookie_refresh(cookie_file: str, task_func):
    """Cookie期限切れ時に再取得を促す"""
    cookies = load_cookies(cookie_file)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context()
        context.add_cookies(cookies)
        page = context.new_page()

        page.goto("https://twitter.com/home")

        if not check_login_status(page):
            print("=" * 50)
            print("[警告] Cookieが期限切れです")
            print("以下の手順でCookieを再取得してください：")
            print("1. pkill Chrome")
            print("2. デバッグChromeを起動")
            print("3. 手動でログイン")
            print("4. Cookie取得スクリプトを実行")
            print("=" * 50)
            context.close()
            browser.close()
            return False

        # ログイン確認OK → タスク実行
        result = task_func(page)

        context.close()
        browser.close()
        return result
```

### Cookie再取得の自動化（上級）

完全自動化したい場合は、定期的にCDPでCookieを更新するcronジョブを設定：

```bash
# crontab -e
# 毎週日曜日にCookie更新リマインダー（手動操作は必要）
0 10 * * 0 echo "X Cookie更新が必要かもしれません" | mail -s "Cookie更新リマインダー" user@example.com
```

ただし、CDP接続には手動でのChrome起動とログインが必要なため、**完全自動化は困難**。

## Playwright MCP ブラウザキャッシュ問題

### 問題

Playwright MCPブラウザは永続キャッシュを保持する。以下の操作ではクリアされない：
- `location.reload(true)`
- タブを閉じて再開
- `page.reload()`

開発中にFE変更を反映させたい場合、ブラウザキャッシュが原因で古いCSS/JSが使われ続ける。

### 解決策1: CDPセッション経由（即時）

```python
# ブラウザキャッシュをクリア
client = await page.context.new_cdp_session(page)
await client.send('Network.clearBrowserCache')
await page.reload()
```

### 解決策2: サーバー側NoCacheMiddleware（根本対策）

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

class NoCacheMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        path = request.url.path
        content_type = response.headers.get("content-type", "")

        if (path.endswith(('.js', '.css', '.html')) or
            path == '/' or
            'text/html' in content_type):
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response
```

### 注意: StaticFiles(html=True)

FastAPIの `StaticFiles(html=True)` はURLパスに `.html` がなくてもHTMLを返すため、ファイル拡張子チェックだけでは不十分。`content-type` ヘッダーも併せてチェックすること。

---

## Chrome Cookie直接抽出（CDP不要・macOS専用）

### 背景
Chrome 145以降、`--remote-debugging-port` 使用時に `--user-data-dir` が必須となり、デフォルトプロファイルのCookieをCDP経由で取得できなくなった。この方法はChromeのSQLiteデータベースから直接Cookieを復号・抽出する。

### 前提条件
- macOS（Keychain + CommonCrypto使用）
- Chrome を閉じた状態で実行
- Keychain アクセス許可ダイアログで「許可」クリックが必要

### 実装パターン

```python
import sqlite3
import json
import subprocess
import hashlib
import tempfile
import shutil
import ctypes
import ctypes.util
from pathlib import Path

def extract_chrome_cookies(domain_filter: list[str], output_path: str = "cookies.json") -> list[dict]:
    """
    ChromeのCookieデータベースから指定ドメインのCookieを抽出・復号する。

    Args:
        domain_filter: 抽出対象ドメインのリスト (例: [".x.com", "x.com", ".twitter.com", "twitter.com"])
        output_path: Cookie保存先パス

    Returns:
        Playwright互換Cookie辞書のリスト
    """
    # 1. macOS KeychainからChrome暗号化キーを取得
    result = subprocess.run(
        ["security", "find-generic-password", "-w", "-s", "Chrome Safe Storage"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Keychainからキー取得失敗: {result.stderr}")

    chrome_key = result.stdout.strip()
    derived_key = hashlib.pbkdf2_hmac('sha1', chrome_key.encode('utf-8'), b'saltysalt', 1003, dklen=16)

    # 2. CommonCrypto (macOS標準) でAES-CBC復号関数
    libSystem = ctypes.cdll.LoadLibrary(ctypes.util.find_library("System"))
    kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding = 1, 0, 1

    def aes_cbc_decrypt(key, iv, data):
        out = ctypes.create_string_buffer(len(data) + 16)
        out_len = ctypes.c_size_t(0)
        status = libSystem.CCCrypt(
            kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
            key, len(key), iv, data, len(data),
            out, len(out), ctypes.byref(out_len)
        )
        return out.raw[:out_len.value] if status == 0 else None

    def decrypt_cookie(encrypted_value, key):
        if encrypted_value[:3] == b'v10':
            decrypted = aes_cbc_decrypt(key, b' ' * 16, encrypted_value[3:])
            if decrypted:
                return decrypted.decode('utf-8', errors='replace')
        return ""

    # 3. SQLiteデータベースをコピーして読み取り（ロック回避）
    cookies_db = Path.home() / "Library/Application Support/Google/Chrome/Default/Cookies"
    tmp = tempfile.mktemp(suffix=".db")
    shutil.copy2(cookies_db, tmp)

    # ドメインフィルタのSQL WHERE句を構築
    domain_set = set(domain_filter)
    placeholders = ",".join("?" * len(domain_set))

    conn = sqlite3.connect(tmp)
    cursor = conn.cursor()
    cursor.execute(f"""
        SELECT host_key, name, encrypted_value, path, expires_utc, is_secure, is_httponly, samesite
        FROM cookies WHERE host_key IN ({placeholders})
    """, list(domain_set))
    rows = cursor.fetchall()
    conn.close()
    Path(tmp).unlink()

    # 4. 復号 + Playwright形式に変換
    import re
    cookies = []
    for host_key, name, encrypted_value, path, expires_utc, is_secure, is_httponly, samesite in rows:
        value = decrypt_cookie(encrypted_value, derived_key)
        if not value:
            continue

        # 復号後のバイナリプレフィックス除去（最長ASCII印字可能文字列を採用）
        matches = re.findall(r'[\x20-\x7e]{4,}', value)
        clean_value = max(matches, key=len) if matches else value

        cookie = {
            "name": name,
            "value": clean_value,
            "domain": host_key,
            "path": path,
            "secure": bool(is_secure),
            "httpOnly": bool(is_httponly),
            "sameSite": ["None", "Lax", "Strict"][samesite] if samesite in (0,1,2) else "None",
        }
        if expires_utc > 0:
            cookie["expires"] = (expires_utc / 1000000) - 11644473600
        cookies.append(cookie)

    # 5. 保存
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w") as f:
        json.dump(cookies, f, indent=2, ensure_ascii=False)

    auth = any(c["name"] == "auth_token" for c in cookies)
    print(f"Cookie取得: {len(cookies)}個 (auth_token: {'あり' if auth else 'なし'})")
    return cookies
```

### 使用例

```python
# X/Twitter Cookie抽出
cookies = extract_chrome_cookies(
    domain_filter=[".x.com", "x.com", ".twitter.com", "twitter.com"],
    output_path="x_profile/cookies.json"
)

# 任意のサイト
cookies = extract_chrome_cookies(
    domain_filter=[".example.com", "example.com"],
    output_path="cookies.json"
)
```

### 注意事項

| 項目 | 説明 |
|------|------|
| OS制約 | macOS専用（CommonCrypto + Keychain使用） |
| Chrome状態 | 実行前にChromeを完全に閉じること（DBロック回避） |
| Keychain | 初回実行時にアクセス許可ダイアログが表示される |
| 復号形式 | v10 (AES-128-CBC) のみ対応。将来のChrome暗号化方式変更に注意 |
| バイナリプレフィックス | 復号後にゴミバイトが付く場合があり、ASCII印字可能文字列を抽出して除去 |
| CDP方式との使い分け | Chrome 145未満 → CDP方式、Chrome 145以降 → 本方式推奨 |

### トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `Keychainからキー取得失敗` | Keychain許可拒否 | macOSの「キーチェーンアクセス」で許可 |
| `Cookie 0個` | ドメインフィルタ不一致 | `LIKE '%domain%'`ではなく完全一致。`.x.com`と`x.com`の両方を指定 |
| `Invalid cookie fields` | バイナリ値混入 | ASCII印字可能文字列抽出のクリーニング処理を確認 |
| `database is locked` | Chrome起動中 | Chromeを完全に閉じてから実行 |
