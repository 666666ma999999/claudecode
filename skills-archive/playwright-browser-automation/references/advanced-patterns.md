# 高度なパターン（iframe, Shadow DOM, プロキシ等）

## 共通ユーティリティ: `playwright_session.py`

ブラウザライフサイクル管理の共通モジュール（`backend/utils/playwright_session.py`）。
全Playwrightクラスで使用。

### 構成要素

| 要素 | 用途 |
|------|------|
| `PlaywrightLaunchOptions` | dataclass: headless, proxy, viewport, auth_state等の起動オプション |
| `launch_browser(options)` | playwright→browser→context→page を一括作成 |
| `cleanup_browser(pw, browser, ctx, page)` | 4ステップ安全クリーンアップ（各段階try/except） |
| `save_trace(context, path)` | トレース保存（失敗時空文字返却） |
| `get_video_path(page)` | 動画パス取得（失敗時空文字返却） |
| `BrowserErrorMixin` | `mark_error()`, `_should_keep_browser()`, `__aenter__`/`__aexit__` |

### 使用クラス一覧

| クラス | ファイル | Mixin | launch_browser | cleanup_browser |
|--------|---------|-------|----------------|-----------------|
| ManuscriptRegistration | browser_automation.py | Yes | Yes | Yes |
| CMSMenuRegistration | browser_automation.py | Yes | Yes | Yes |
| PPVDetailRegistration | browser_automation.py | Yes | Yes | Yes |
| BaseBrowserAutomation | browser_automation.py | Yes | No（サブクラスが独自start） | Yes |
| PlaywrightChecker | check_playwright.py | Yes | Yes | Yes |

### 新規Playwrightクラス追加時

```python
from utils.playwright_session import (
    PlaywrightLaunchOptions, launch_browser, cleanup_browser, BrowserErrorMixin
)

class NewChecker(BrowserErrorMixin):
    async def start(self):
        options = PlaywrightLaunchOptions(
            headless=True,
            viewport_width=1280,
            viewport_height=800,
        )
        self._playwright, self.browser, self.context, self.page = await launch_browser(options)

    async def close(self):
        await cleanup_browser(self._playwright, self.browser, self.context, self.page)

    # BrowserErrorMixin provides __aenter__, __aexit__, mark_error, _should_keep_browser
```

## BaseBrowserAutomation 基底クラス

`browser_automation.py`の3つの自動化クラスは`BaseBrowserAutomation`を継承:
- `IzumoCMSAutomation` (`_session_prefix="izumo"`)
- `SalesRegistrationAutomation` (`_session_prefix="sales_reg"`)
- `IzumoSyncAutomation` (`_session_prefix="izumo_sync"`)

### 基底クラスの共通メソッド
- `_get_chrome_user_data_dir()`: OS別Chromeプロファイルパス検出
- `_copy_chrome_profile()`: 一時ディレクトリへのプロファイルコピー
- `_ensure_session_dir()`: セッション別スクリーンショットディレクトリ作成
- `take_screenshot(name, full_page, add_timestamp)`: 常時撮影（error/final用）
- `debug_screenshot(name, full_page, add_timestamp)`: `config.debug_screenshots=True`時のみ撮影（中間状態用）
- `close()`: ブラウザ・コンテキスト・一時ディレクトリのクリーンアップ（`cleanup_browser()`に委譲）

### 新規クラス追加時
```python
class NewAutomation(BaseBrowserAutomation):
    _session_prefix = "new_auto"
    _log_label = "新規自動化"

    def __init__(self, config=None):
        super().__init__()
        self.config = config
```

## Rohan プロキシ認証パターン

Rohanプロジェクト固有のSquidプロキシ経由アクセスパターン。

### Python Playwright認証パターン（必須）

プロキシ認証は**ブラウザ起動時**に設定すること（context単位では設定不可）：

```python
import base64
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        # ブラウザレベルでプロキシ認証を設定
        browser = await p.chromium.launch(
            proxy={
                "server": "http://proxy.example.com:3128",
                "username": "media-masaaki",
                "password": "wWFBdtwo",
                "bypass": "localhost,127.0.0.1"
            }
        )

        # サイトのBasic認証が必要な場合はURLに埋め込む
        # ※ extra_http_headersはSquidプロキシ経由で消失するため使用禁止
        from urllib.parse import quote
        user = quote("cpadmin", safe="")
        passwd = quote("arfni9134", safe="")
        context = await browser.new_context(
            ignore_https_errors=True
        )

        page = await context.new_page()
        await page.goto(f"https://{user}:{passwd}@izumo-dev.uranai-gogo.com/admin/")
        # ... 処理続行
```

### `_embed_auth_in_url()` ヘルパー

```python
# URLに認証情報を埋め込む（_embed_auth_in_url()ヘルパーを使用）
from urllib.parse import urlsplit, urlunsplit, quote

def _embed_auth_in_url(url: str, username: str, password: str) -> str:
    parts = urlsplit(url)
    netloc = f"{quote(username, safe='')}:{quote(password, safe='')}@{parts.hostname}"
    if parts.port:
        netloc += f":{parts.port}"
    return urlunsplit((parts.scheme, netloc, parts.path, parts.query, parts.fragment))

url = _embed_auth_in_url("https://izumo-dev.uranai-gogo.com/admin/", "cpadmin", "arfni9134")
await page.goto(url)
```

### 禁止パターン（動作しない）

```python
# 1. http_credentialsはプロキシ認証に対応しない
context = await browser.new_context(
    http_credentials={"username": "...", "password": "..."}  # 動作しない
)

# 2. extra_http_headersはSquidプロキシ経由で消失する（401エラーの原因）
context = await browser.new_context(
    extra_http_headers={"Authorization": "Basic ..."}  # プロキシが消す
)

# 3. proxy引数なしのブラウザ起動
browser = await p.chromium.launch()  # プロキシが使われない
```

### トラブルシューティング

| エラー | 原因 | 対応 |
|--------|------|------|
| 407 Proxy Authentication Required | プロキシ認証が設定されていない | ブラウザ起動時に`proxy`引数を設定 |
| 401 Unauthorized | サイトBasic認証が設定されていない | URLに認証情報を埋め込む |
| SSL: CERTIFICATE_VERIFY_FAILED | HTTPS証明書検証エラー | コンテキスト作成時に`ignore_https_errors=True`を設定 |
| ECONNREFUSED | プロキシサーバーに接続できない | プロキシアドレス・ポート番号を確認 |

## 動画録画・トレース

```python
# 動画録画
context = await browser.new_context(
    record_video_dir="./videos",
    record_video_size={"width": 1280, "height": 720}
)

# トレース記録
await context.tracing.start(screenshots=True, snapshots=True, sources=True)
# ... 操作 ...
await context.tracing.stop(path="trace.zip")

# トレースの確認: playwright show-trace trace.zip
```

## ダイアログ処理

```python
# 自動accept
page.on("dialog", lambda dialog: asyncio.create_task(dialog.accept()))

# 自動dismiss
page.on("dialog", lambda dialog: asyncio.create_task(dialog.dismiss()))

# カスタム処理
async def handle_dialog(dialog):
    if dialog.type == "confirm":
        await dialog.accept()
    elif dialog.type == "prompt":
        await dialog.accept("入力値")
    else:
        await dialog.dismiss()

page.on("dialog", lambda d: asyncio.create_task(handle_dialog(d)))
```

## 認証状態の保存・復元

```python
# 認証状態を保存
await context.storage_state(path="auth_state.json")

# 認証状態を復元してコンテキスト作成
context = await browser.new_context(storage_state="auth_state.json")
```

## 設定オプション

### ブラウザ起動オプション

```python
browser = await p.chromium.launch(
    headless=True,           # ヘッドレスモード
    slow_mo=500,             # 各操作の遅延（デバッグ用）
    args=[
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage'  # Docker環境向け
    ]
)
```

### コンテキストオプション

```python
context = await browser.new_context(
    viewport={"width": 1280, "height": 720},
    user_agent="Custom User Agent",
    locale="ja-JP",
    timezone_id="Asia/Tokyo",
    permissions=["geolocation"],
    geolocation={"latitude": 35.6762, "longitude": 139.6503},
    storage_state="auth_state.json"  # 認証状態
)
```

### タイムアウト設定

```python
# ページのデフォルトタイムアウト
page.set_default_timeout(30000)  # 30秒

# ナビゲーションのタイムアウト
page.set_default_navigation_timeout(60000)  # 60秒
```

## スクリーンショット

```python
# ページ全体
await page.screenshot(path="screenshot.png", full_page=True)

# 表示領域のみ
await page.screenshot(path="viewport.png")

# 特定要素のみ
await page.locator(".card").screenshot(path="element.png")

# Base64として取得
import base64
screenshot_bytes = await page.screenshot()
base64_image = base64.b64encode(screenshot_bytes).decode()
```
