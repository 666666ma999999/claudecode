# Playwright Browser Automation

Playwright を使用したブラウザ自動化のためのスキル。Webスクレイピング、フォーム自動入力、E2Eテストなど、あらゆるブラウザ操作を支援します。

## トリガー

以下のフレーズで発動します：
- 「Playwrightで」「ブラウザ自動化」
- 「Webスクレイピング」「データ抽出」
- 「フォーム自動入力」「自動ログイン」
- 「E2Eテスト」「ブラウザテスト」

## 基本構成

### 必須インポート

```python
import asyncio
from playwright.async_api import async_playwright, Browser, BrowserContext, Page, TimeoutError as PlaywrightTimeout
```

### 基本テンプレート

```python
async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        try:
            # ブラウザ操作
            await page.goto("https://example.com")
            # ...
        finally:
            await browser.close()

asyncio.run(main())
```

### コンテキストマネージャーパターン（推奨）

```python
class BrowserAutomation:
    def __init__(self, headless=True, slow_mo=0):
        self.headless = headless
        self.slow_mo = slow_mo

    async def __aenter__(self):
        self._playwright = await async_playwright().start()
        self.browser = await self._playwright.chromium.launch(
            headless=self.headless,
            slow_mo=self.slow_mo
        )
        self.context = await self.browser.new_context()
        self.page = await self.context.new_page()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.context.close()
        await self.browser.close()
        await self._playwright.stop()
```

## 主要操作

### ナビゲーション

```python
# 基本的なページ遷移
await page.goto("https://example.com")

# ネットワークアイドルまで待機（SPAに有効）
await page.goto(url, wait_until="networkidle", timeout=60000)

# DOM読み込み完了まで待機
await page.goto(url, wait_until="domcontentloaded")

# 戻る・進む
await page.go_back()
await page.go_forward()

# リロード
await page.reload()
```

### 要素選択（セレクタ）

```python
# ロールベース（推奨 - アクセシビリティ対応）
page.get_by_role("button", name="ログイン")
page.get_by_role("textbox", name="メールアドレス")
page.get_by_role("link", name="詳細を見る")

# テキストベース
page.get_by_text("送信")
page.get_by_label("パスワード")
page.get_by_placeholder("検索...")

# CSSセレクタ
page.locator("input[name='email']")
page.locator(".submit-button")
page.locator("#main-content")

# 複数要素から選択
page.locator(".item").first
page.locator(".item").last
page.locator(".item").nth(2)
```

### クリック操作

```python
# 基本クリック
await page.get_by_role("button", name="送信").click()

# ダブルクリック
await element.dblclick()

# 右クリック
await element.click(button="right")

# 強制クリック（非表示要素）
await element.click(force=True)

# クリック後の待機
await element.click()
await page.wait_for_load_state("networkidle")
```

### 入力操作

```python
# テキスト入力
await page.get_by_role("textbox", name="メール").fill("user@example.com")

# 入力前にクリア
await input_element.clear()
await input_element.fill("新しい値")

# キーボード入力
await page.keyboard.type("テキスト")
await page.keyboard.press("Enter")
await page.keyboard.press("Control+A")

# セレクトボックス
await page.locator("select[name='country']").select_option("japan")
await page.locator("select").select_option(value="jp")  # value属性で選択
await page.locator("select").select_option(label="日本")  # 表示テキストで選択

# チェックボックス
await page.get_by_role("checkbox", name="同意する").check()
await page.get_by_role("checkbox").uncheck()

# ファイルアップロード
await page.locator("input[type='file']").set_input_files("path/to/file.pdf")
```

### フォーム送信

```python
# 基本: submitボタンをクリック
await page.locator("input[type='submit']").click()

# click()が効かない場合: JavaScriptで直接submit
await page.evaluate("document.querySelector('form').submit()")
```

### 待機処理

```python
# 要素の表示を待つ
await page.locator(".modal").wait_for(state="visible", timeout=30000)

# 要素の非表示を待つ
await page.get_by_text("Loading").wait_for(state="hidden")

# ページロード完了を待つ
await page.wait_for_load_state("networkidle")
await page.wait_for_load_state("domcontentloaded")

# 特定のURLを待つ
await page.wait_for_url("**/success")

# 任意の時間待機（非推奨だが必要な場合）
await asyncio.sleep(1)

# 要素の存在確認
if await page.locator(".element").count() > 0:
    # 要素が存在する
    pass
```

### データ抽出

```python
# テキスト取得
text = await page.locator(".title").text_content()
inner_text = await page.locator(".content").inner_text()

# 属性取得
href = await page.locator("a").get_attribute("href")
value = await page.locator("input").input_value()

# 複数要素からテキスト取得
elements = await page.locator(".item").all()
for el in elements:
    text = await el.text_content()
    print(text)

# HTML取得
html = await page.locator(".container").inner_html()

# ページ全体のHTML
full_html = await page.content()
```

### スクリーンショット

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

### 動画録画・トレース

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

### ダイアログ処理

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

### 認証状態の保存・復元

```python
# 認証状態を保存
await context.storage_state(path="auth_state.json")

# 認証状態を復元してコンテキスト作成
context = await browser.new_context(storage_state="auth_state.json")
```

## フォームフィールド事前調査パターン

### 問題

CMSやWebサイトによってログインフィールド名が異なる。

| サイト | ユーザーID | パスワード |
|--------|-----------|-----------|
| サイトA | `user_id` | `password` |
| サイトB | `user` | `pass` |
| サイトC | `email` | `passwd` |

想定と異なるフィールド名を使うと、ログインや入力が失敗する。

### 解決策：自動化前にフィールド名を調査

```python
async def discover_form_fields(page, url):
    """ページのフォームフィールド構造を調査"""
    await page.goto(url)
    await page.wait_for_load_state('networkidle')

    elements = await page.evaluate('''
        () => {
            const result = { inputs: [], textareas: [], selects: [] };
            document.querySelectorAll('input[name]').forEach(el => {
                result.inputs.push({
                    name: el.name,
                    type: el.type,
                    placeholder: el.placeholder,
                    id: el.id
                });
            });
            document.querySelectorAll('textarea[name]').forEach(el => {
                result.textareas.push({ name: el.name, id: el.id });
            });
            document.querySelectorAll('select[name]').forEach(el => {
                result.selects.push({ name: el.name, id: el.id });
            });
            return result;
        }
    ''')
    return elements
```

### 汎用ログイン関数（フィールド名可変）

```python
async def login_flexible(page, url, username, password, field_config=None):
    """フィールド名を指定可能なログイン関数

    field_config = {
        'user_field': 'user',      # ユーザーIDのname属性
        'pass_field': 'pass',      # パスワードのname属性
        'submit_selector': 'button:has-text("Login")'
    }
    """
    config = field_config or {
        'user_field': 'user',
        'pass_field': 'pass',
        'submit_selector': 'button[type="submit"], button:has-text("Login")'
    }

    await page.goto(url)
    await page.fill(f"input[name='{config['user_field']}']", username)
    await page.fill(f"input[name='{config['pass_field']}']", password)
    await page.click(config['submit_selector'])
    await page.wait_for_load_state('networkidle')
```

### 多要素タイプ一括入力（input + textarea + select対応）

フォーム入力時、フィールドのHTML要素タイプが不明な場合に使用：

```javascript
// JavaScript (page.evaluate用)
const fillFields = (fields) => {
    let filled = 0;
    let notFound = [];

    for (const [name, value] of Object.entries(fields)) {
        // input → textarea → select の順に検索
        let element = document.querySelector(`input[name='${name}']`);
        if (!element) element = document.querySelector(`textarea[name='${name}']`);
        if (!element) element = document.querySelector(`select[name='${name}']`);

        if (element) {
            element.value = value;
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
            filled++;
        } else {
            notFound.push(name);
        }
    }
    return { filled, notFound };
};
```

```python
# Python側
async def fill_form_fields(page, fields: dict):
    """フォームフィールドを一括入力（要素タイプ自動検出）"""
    js_result = await page.evaluate('''
        (fields) => {
            let filled = 0;
            let notFound = [];
            for (const [name, value] of Object.entries(fields)) {
                let el = document.querySelector(`input[name='${name}']`);
                if (!el) el = document.querySelector(`textarea[name='${name}']`);
                if (!el) el = document.querySelector(`select[name='${name}']`);
                if (el) {
                    el.value = value;
                    el.dispatchEvent(new Event('input', { bubbles: true }));
                    el.dispatchEvent(new Event('change', { bubbles: true }));
                    filled++;
                } else {
                    notFound.push(name);
                }
            }
            return { filled, notFound };
        }
    ''', fields)

    if js_result['notFound']:
        logger.warning(f"⚠️ 入力先が見つからなかったフィールド: {js_result['notFound']}")

    return js_result
```

### デバッグログ出力パターン

自動化が失敗した際の原因特定に使用：

```python
async def fill_with_debug(page, fields: dict):
    """デバッグ情報付きフォーム入力"""

    # 1. 入力前のフォーム構造を記録
    form_structure = await discover_form_fields(page, page.url)
    logger.info(f"フォーム構造: inputs={len(form_structure['inputs'])}, "
                f"textareas={len(form_structure['textareas'])}, "
                f"selects={len(form_structure['selects'])}")

    # 2. 入力試行
    result = await fill_form_fields(page, fields)

    # 3. 結果をログ
    logger.info(f"入力成功: {result['filled']}フィールド")
    if result['notFound']:
        logger.warning(f"入力失敗フィールド: {result['notFound']}")
        logger.info(f"利用可能なフィールド名: {[i['name'] for i in form_structure['inputs']]}")

    # 4. スクリーンショット保存
    await page.screenshot(path=f"debug_form_{datetime.now().strftime('%H%M%S')}.png")

    return result
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

## エラーハンドリング

```python
from playwright.async_api import TimeoutError as PlaywrightTimeout

try:
    await page.goto(url, timeout=30000)
    await page.locator(".element").click(timeout=5000)
except PlaywrightTimeout:
    # タイムアウトエラー
    await page.screenshot(path="error_timeout.png")
    raise
except Exception as e:
    # その他のエラー
    await page.screenshot(path="error_general.png")
    raise
```

## 実装パターン

### ログイン処理

```python
async def login(page, user_id: str, password: str) -> bool:
    try:
        await page.goto(LOGIN_URL, wait_until="networkidle")
        await page.get_by_role("textbox", name="user-id").fill(user_id)
        await page.get_by_role("textbox", name="password").fill(password)
        await page.get_by_role("button", name="ログイン").click()
        await page.wait_for_load_state("networkidle")
        return True
    except Exception as e:
        logging.error(f"ログインエラー: {e}")
        return False
```

### データ収集（スクレイピング）

```python
async def scrape_items(page) -> list:
    items = []
    elements = await page.locator(".item-card").all()

    for el in elements:
        item = {
            "title": await el.locator(".title").text_content(),
            "price": await el.locator(".price").text_content(),
            "url": await el.locator("a").get_attribute("href")
        }
        items.append(item)

    return items
```

### ページネーション処理

```python
async def scrape_all_pages(page) -> list:
    all_items = []

    while True:
        items = await scrape_items(page)
        all_items.extend(items)

        next_button = page.get_by_role("link", name="次へ")
        if await next_button.count() == 0:
            break

        await next_button.click()
        await page.wait_for_load_state("networkidle")

    return all_items
```

### フォーム連続入力

```python
async def fill_form(page, data: dict):
    for field_name, value in data.items():
        field = page.locator(f"input[name='{field_name}']")
        if await field.count() > 0:
            await field.fill(value)
```

## デバッグ方法

```bash
# ヘッドレスモードを無効にして実行
headless=False

# スローモーションで実行
slow_mo=500

# トレースビューアで確認
playwright show-trace trace.zip

# スクリーンショット保存場所
./data/playwright_recordings/session_{timestamp}/
```

## インストール

```bash
# Playwright インストール
pip install playwright

# ブラウザバイナリインストール
playwright install chromium
# または全ブラウザ
playwright install
```

## 非同期バックエンド処理の確認方法

### 問題パターン
フロントエンドからAPIを呼び出し、バックエンド側でPlaywright処理が実行される場合：
- UI上の「処理中...」テキストを`wait_for`で待機
- タイムアウトが発生
- **しかし実際にはバックエンド処理は成功している**

### 原因
- バックエンドのPlaywright処理は非同期で実行される
- APIレスポンスが返る前にフロントエンドの`wait_for`がタイムアウトする
- UIテキストの更新タイミングとバックエンド処理完了のタイミングが一致しない

### 正しい確認方法

```
1. UIテキスト待機でタイムアウトした場合でも、失敗と断定しない
2. ネットワークリクエストのステータスを確認する（200なら成功）
3. APIレスポンスのJSONを確認する（"success": true など）
```

### MCP chrome-devtools での確認手順

```python
# 1. ネットワークリクエスト一覧を取得
list_network_requests()

# 2. 該当リクエストの詳細を確認
get_network_request(reqid=<request_id>)

# 3. Response Body の success フラグを確認
# {"success": true, "message": "..."}
```

### 実例（外部サイト登録）
```
# NG: UIテキスト待機のみ
wait_for("登録完了", timeout=300000)  # タイムアウト → 失敗と誤判定

# OK: ネットワークリクエスト確認
POST /api/register-manuscript [success - 200]
Response: {"success": true, "message": "8件の小見出しを登録・確定しました"}
# → 実際には成功していた
```

### 教訓
- **APIレスポンスが真実の情報源**
- UI状態の待機はあくまで補助的な確認
- タイムアウト時は必ずネットワークリクエストを確認してから結果を判断する

## よくある落とし穴と対策

### 1. 新しいページ作成直後のナビゲーションエラー

**症状:**
```
Page.goto: Navigation to "https://..." is interrupted by another navigation to "about:blank"
```

**原因:** `new_page()` 直後は `about:blank` への初期ナビゲーションが進行中

**対策:**
```python
self.page = await self.context.new_page()
# ページが準備されるまで待機（必須）
await self.page.wait_for_load_state("domcontentloaded")
# この後でgoto()を実行
await self.page.goto("https://example.com")
```

### 2. ダイアログハンドラーが動作しない

**症状:** `page.on("dialog", lambda dialog: dialog.accept())` で403エラーや予期しない動作

**原因:** `dialog.accept()` は非同期メソッドだが、lambdaでawaitできない

**対策:**
```python
import asyncio

def handle_dialog(dialog):
    logger.info(f"ダイアログ検出: {dialog.message}")
    asyncio.ensure_future(dialog.accept())  # 正しい非同期処理

page.on("dialog", handle_dialog)
```

### 3. コンテキスト切り替え時の認証エラー

**症状:** 複数サイトで異なるBasic認証を使う際、2つ目のサイトで認証失敗

**対策:**
```python
# 古いコンテキストを確実に閉じてから新しいコンテキストを作成
if self.context:
    await self.context.close()

self.context = await self.browser.new_context(
    http_credentials={"username": "user", "password": "pass"}
)
```

## 実装前の必須確認事項

**ワークフロー自動化では、実装前に以下を必ずユーザーに確認：**

1. **完全なワークフロー**
   - 画面遷移の順序（URL）
   - 各画面でクリックする要素
   - 出現するダイアログとそのメッセージ
   - 期待される最終画面

2. **各ステップの詳細**
   - ボタンのテキストまたはセレクタ
   - ラジオボタン/チェックボックスの選択肢
   - 入力フィールドの値

3. **エラー時の挙動**
   - 何が表示されたら失敗か
   - リトライは必要か

**教訓:** ワークフローの一部でも不明な場合、実装を開始しない。
確認不足で実装すると、デバッグに何倍もの時間がかかる。

## ユーザーへの確認事項

実装前に AskUserQuestion で確認：
- 対象サイトのURL
- 必要な操作（ログイン、データ抽出、フォーム入力など）
- ヘッドレスモードで実行するか（デバッグ時は表示推奨）
- 動画録画・トレース記録が必要か
- エラー時のリトライ処理が必要か

## Chromeプロファイルの使用（認証済みセッション再利用）

既存のChrome認証情報（Cookie、ログイン状態）を再利用したい場合：

### プロファイルコピー戦略（推奨）

既存のChromeが起動中でもプロファイルを使用できるよう、コピーして使用する：

```python
import shutil
import tempfile
from pathlib import Path

def copy_chrome_profile() -> str:
    """Chromeプロファイルを一時ディレクトリにコピー"""
    # macOSのデフォルトパス
    source_dir = Path.home() / "Library/Application Support/Google/Chrome"
    temp_dir = Path(tempfile.mkdtemp(prefix="chrome_profile_"))

    # 認証情報関連のファイルのみコピー
    items_to_copy = [
        "Default/Cookies",
        "Default/Login Data",
        "Default/Web Data",
        "Default/Preferences",
        "Local State",
    ]

    (temp_dir / "Default").mkdir(parents=True, exist_ok=True)
    for item in items_to_copy:
        src = source_dir / item
        dst = temp_dir / item
        if src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)

    return str(temp_dir)

# 使用例
temp_profile = copy_chrome_profile()
context = await playwright.chromium.launch_persistent_context(
    temp_profile,
    headless=False,
    channel="chrome",  # システムのChromeを使用
)

# 終了時にクリーンアップ
shutil.rmtree(temp_profile)
```

### 注意点
- 既存Chromeと同時使用可能（コピーなので競合しない）
- 終了時に一時ディレクトリを必ず削除
- `channel="chrome"` でシステムのChromeバイナリを使用

## 接続エラーのパターン判定

ナビゲーション時のエラーを適切にハンドリング：

```python
async def navigate_with_error_handling(page, url: str) -> tuple[bool, str]:
    """エラーパターンを判定してわかりやすいメッセージを返す"""
    try:
        response = await page.goto(url, wait_until="domcontentloaded", timeout=30000)

        # HTTPエラーチェック
        if response and response.status >= 400:
            return False, f"HTTPエラー: {response.status}"

        # リダイレクトループ/接続エラー検出
        current_url = page.url
        if "chrome-error" in current_url or "about:blank" in current_url:
            return False, "接続エラー（VPN接続またはBasic認証を確認）"

        return True, ""

    except Exception as e:
        error_str = str(e)
        error_patterns = {
            "ERR_TOO_MANY_REDIRECTS": "リダイレクトループ（VPN接続が必要な可能性）",
            "ERR_INVALID_AUTH_CREDENTIALS": "Basic認証エラー（認証情報を確認）",
            "ERR_CONNECTION_REFUSED": "接続拒否（サーバーに接続できません）",
            "ERR_NAME_NOT_RESOLVED": "DNS解決エラー（URLを確認）",
            "Timeout": "タイムアウト（ネットワーク接続を確認）",
        }
        for pattern, message in error_patterns.items():
            if pattern in error_str:
                return False, message
        return False, f"接続エラー: {error_str}"
```

## テーブル行内の要素を探すパターン

テーブルから特定の行を見つけてアクションを実行：

```python
async def find_row_and_click_button(page, identifier: str, button_text: str) -> bool:
    """
    テーブルから識別子を含む行を見つけ、その行内のボタンをクリック

    Args:
        identifier: 行を特定するテキスト（ID、名前など）
        button_text: クリックするボタンのテキスト
    """
    # パターン1: テーブル行内
    row = page.locator(f"tr:has-text('{identifier}')")

    # パターン2: リスト/div内（テーブルでない場合）
    if await row.count() == 0:
        row = page.locator(f"li:has-text('{identifier}'), div.row:has-text('{identifier}')")

    if await row.count() == 0:
        return False

    # 行内のボタンを探してクリック
    button = row.first.locator(f"button:has-text('{button_text}'), a:has-text('{button_text}')")
    if await button.count() > 0:
        await button.first.click()
        return True

    return False

# 使用例
success = await find_row_and_click_button(page, "monthlyAffinity001.045", "反映")
```

## HTML日付・時刻フィールドの入力形式

HTMLのtype属性によって入力形式が異なる。間違った形式だとエラーになる：

```python
# ❌ エラーになるパターン
await page.locator('#date_field').fill('2026/12/24')  # type="date"にスラッシュ形式

# ✅ 正しい形式
await page.locator('#date_field').fill('2026-12-24')  # type="date" → YYYY-MM-DD
await page.locator('#time_field').fill('00:00')       # type="time" → HH:MM
await page.locator('#datetime_field').fill('2026-12-24T00:00')  # type="datetime-local"
```

### 入力形式一覧

| type属性 | 正しい形式 | 例 |
|----------|-----------|-----|
| `date` | YYYY-MM-DD | `2026-12-24` |
| `time` | HH:MM | `14:30` |
| `datetime-local` | YYYY-MM-DDTHH:MM | `2026-12-24T14:30` |
| `month` | YYYY-MM | `2026-12` |
| `week` | YYYY-Www | `2026-W52` |

## Basic認証を含むURLでのアクセス

Basic認証が必要なサイトへのアクセス方法：

### 方法1: URL埋め込み（シンプル）

```python
# 認証情報をURLに含める
await page.goto('https://username:password@example.com/admin/')
```

### 方法2: コンテキスト設定（複数ページ）

```python
context = await browser.new_context(
    http_credentials={
        "username": "cpadmin",
        "password": "arfni9134"
    }
)
page = await context.new_page()
await page.goto('https://example.com/admin/')
```

## 大きなページでの要素確認（evaluate活用）

スナップショットがトークン制限を超える場合、`page.evaluate()`でJavaScriptを実行：

```python
# 特定のIDが存在するか確認
result = await page.evaluate('''(target_id) => {
    const allText = document.body.innerText;
    const found = allText.includes(target_id);

    // テーブル行から詳細を取得
    const rows = document.querySelectorAll('table tr');
    let rowInfo = null;
    for (const row of rows) {
        if (row.innerText.includes(target_id)) {
            rowInfo = row.innerText.substring(0, 300);
            break;
        }
    }

    return { found, rowInfo };
}''', '48200015')

if result['found']:
    print(f"ID発見: {result['rowInfo']}")
```

### 活用シーン

- 一覧ページが数百行ある場合
- 登録完了後の確認
- 特定テキストの存在確認

## 登録完了の確認パターン

フォーム登録後に成功を確認する方法：

### 1. URLパラメータの変化

```python
# 登録前
# URL: https://example.com/edit.html

# 登録後
# URL: https://example.com/edit.html?id=12345&save=1

current_url = page.url
if 'save=1' in current_url or 'id=' in current_url:
    print("登録成功（URLパラメータで確認）")
```

### 2. ページ内テキストの変化

```python
# MODEの変化を確認
mode_text = await page.locator('text=MODE').text_content()
if 'edit' in mode_text:
    print("登録成功（MODE: new → edit）")

# 成功メッセージを確認
if await page.locator('text=登録しました').count() > 0:
    print("登録成功（メッセージ確認）")
```

### 3. 一覧ページでの存在確認（推奨）

```python
async def verify_registration_in_list(page, list_url: str, target_id: str) -> bool:
    """一覧ページで登録されたIDが存在するか確認"""
    await page.goto(list_url, wait_until="networkidle")

    result = await page.evaluate('''(target_id) => {
        return document.body.innerText.includes(target_id);
    }''', target_id)

    return result

# 使用例
success = await verify_registration_in_list(
    page,
    'https://example.com/admin/list.html',
    '48200015'
)
```

### 確認フローのベストプラクティス

```python
async def register_and_verify(page, form_data: dict, list_url: str) -> dict:
    """登録 → 確認を一括実行"""
    result = {
        'success': False,
        'url_check': False,
        'message_check': False,
        'list_check': False
    }

    # 1. フォーム入力・送信
    await fill_and_submit_form(page, form_data)

    # 2. URLパラメータ確認
    result['url_check'] = 'save=1' in page.url or 'id=' in page.url

    # 3. 成功メッセージ確認
    result['message_check'] = await page.locator('text=登録しました').count() > 0

    # 4. 一覧ページ確認（最も信頼性が高い）
    result['list_check'] = await verify_registration_in_list(
        page, list_url, form_data['id']
    )

    result['success'] = result['list_check']
    return result
```

## Docker + VNC でのGUI実行は不安定（ローカル推奨）

### 背景

Dockerコンテナ内でPlaywrightをGUIモード（`headless=False`）で実行したい場合、VNC環境を構築する方法がある。

### 構成例

```dockerfile
FROM mcr.microsoft.com/playwright/python:v1.57.0-jammy
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    xvfb x11vnc fluxbox novnc websockify supervisor

# supervisordで Xvfb + fluxbox + x11vnc + novnc を起動
```

### 実際に遭遇した問題

| 問題 | 詳細 |
|------|------|
| VNC接続後に画面が表示されない | noVNCでConnectしても黒画面/空白 |
| novncパス変更 | Ubuntu版ではパスが異なり起動スクリプト修正が必要 |
| tzdata対話プロンプト | `DEBIAN_FRONTEND=noninteractive` 必須 |
| X11転送の複雑さ | macOSではXQuartz + socat設定が必要で不安定 |

### 結論：ローカル実行を推奨

**Docker + VNC は設定が複雑で不安定**。以下の理由からローカル実行を推奨：

```
Docker + VNC:
  ❌ 設定が複雑（Xvfb, VNC, noVNC, supervisor）
  ❌ 接続問題が頻発
  ❌ デバッグが困難
  ❌ パフォーマンス低下

ローカル実行:
  ✅ セットアップが簡単（venv + playwright install）
  ✅ 画面が直接見える
  ✅ デバッグしやすい
  ✅ CDP接続でCookie取得可能
```

### ローカル環境セットアップ

```bash
# 仮想環境作成
python3 -m venv venv
source venv/bin/activate

# インストール
pip install playwright
playwright install chromium

# 実行
python your_script.py
```

### Dockerが必要な場合

本番環境やCI/CDでDockerが必須の場合は、**headless=True**で実行：

```python
browser = playwright.chromium.launch(headless=True)
```

ただしheadlessモードはbot検知されやすいため、事前にローカルでCookieを取得しておく。

---

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

---

## ⚠️ ユーザープロファイル使用の危険性と対策

### 絶対に避けるべき設定

```python
# ❌ 危険: ユーザーの実際のChromeプロファイルを使用
@dataclass
class Config:
    use_user_profile: bool = True  # 絶対にデフォルトTrueにしない

# ❌ 危険: 直接ユーザープロファイルを指定
context = await playwright.chromium.launch_persistent_context(
    "~/Library/Application Support/Google/Chrome",  # ユーザーの実プロファイル
    ...
)
```

### 何が起きるか

1. **ブックマーク消失/破損**: Bookmarksファイルが上書き・破損
2. **ファビコン消失**: Faviconsデータベースが破損し、全アイコンが同一に
3. **認証情報消失**: Cookieやログイン状態が失われる
4. **拡張機能の設定消失**: Chromeの拡張機能設定がリセット

### 安全な設定（必須）

```python
@dataclass
class Config:
    use_user_profile: bool = False  # 必ずFalseをデフォルトに
    chrome_user_data_dir: Optional[str] = None

# ✅ 安全: 独立したセッションを使用
browser = await playwright.chromium.launch(headless=False)
context = await browser.new_context()
```

### 認証が必要な場合の安全な方法

```python
# ✅ 安全: プロファイルをコピーして使用（前述のcopy_chrome_profile()を使用）
temp_profile = copy_chrome_profile()
try:
    context = await playwright.chromium.launch_persistent_context(
        temp_profile,
        headless=False,
    )
    # ... 処理 ...
finally:
    shutil.rmtree(temp_profile)  # 必ずクリーンアップ
```

### Chromeプロファイル復旧手順

もしプロファイルが破損した場合：

```bash
# 1. Chromeを完全に終了
pkill -9 "Google Chrome"

# 2. バックアップの確認
ls -la ~/Library/Application\ Support/Google/Chrome/*/Bookmarks*

# 3. 使用中のプロファイル確認（Local Stateから）
cat "~/Library/Application Support/Google/Chrome/Local State" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('最後に使用:', data.get('profile', {}).get('last_used'))
"

# 4. ブックマーク復元（例: Defaultプロファイルの場合）
cp "~/Library/Application Support/Google/Chrome/Profile 1/Bookmarks.bak" \
   "~/Library/Application Support/Google/Chrome/Default/Bookmarks"

# 5. ファビコン復元（アイコンが消えた場合）
cp "~/Library/Application Support/Google/Chrome/Profile 1/Favicons" \
   "~/Library/Application Support/Google/Chrome/Default/Favicons"

# 6. Chrome起動
open -a "Google Chrome"
```

### チェックリスト（実装時に必ず確認）

- [ ] `use_user_profile`のデフォルト値は`False`か
- [ ] ユーザープロファイルを直接参照していないか
- [ ] プロファイルをコピーする場合、終了時にクリーンアップしているか
- [ ] 設定クラスが複数ある場合、全てチェックしたか

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

### トラブルシューティング

| 症状 | 原因 | 対策 |
|------|------|------|
| ポートに接続できない | 既存Chromeが残っている | `pkill -9 Chrome` で全終了後に再起動 |
| 認証トークンなし | サイトでログインしていない | Chrome内で手動ログイン |
| `open -a` でオプションが効かない | macOSの仕様 | フルパスで直接実行 |
| **Googleアカウントにアクセスできない** | デバッグChromeが起動中 | 下記「Chrome使い分けの注意」参照 |

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

## ⚠️ MCP使用時のGoogleログインブロック問題

### 症状

MCP（Chrome DevTools MCP / Playwright MCP）使用中に、Chromeで以下のエラーが表示される：

```
ログインできませんでした
このブラウザまたはアプリは安全でない可能性があります。
別のブラウザをお試しください。
```

### 原因

MCPはChromeを**自動化フラグ付き**で起動する：

```bash
--enable-automation              # 自動化モードフラグ
--remote-debugging-port=XXXXX    # リモートデバッグ有効
--user-data-dir=/特殊な場所/       # 通常とは別のプロファイル
```

Googleはこれらのフラグを検出し、ボット/スクレイピングと判断してログインをブロックする。

### 解決策

#### 1. headlessモードを使用（推奨）

`.mcp.json`でheadlessモードを指定：

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic/mcp-playwright", "--headless"]
    }
  }
}
```

**メリット:** ブラウザ画面が表示されないので、通常のChromeと混同しない

#### 2. 通常のChromeと自動化用Chromeを使い分ける

| 用途 | 使用するChrome |
|------|---------------|
| Googleログイン、普段使い | Dockから起動した**通常のChrome** |
| スクレイピング、自動化 | **MCP経由で起動される自動化用Chrome** |

#### 3. 自動化用Chromeの見分け方

| 項目 | 通常のChrome | 自動化用Chrome |
|------|-------------|---------------|
| 起動方法 | Dockクリック | MCP経由で自動起動 |
| 警告バー | なし | 「Chromeは自動テストソフトウェアによって制御されています」 |
| ブックマーク | あなたのもの | 空 or 別物 |

### 復旧手順

自動化用ChromeでGoogleログインしようとしてブロックされた場合：

```bash
# 1. すべてのChromeプロセスを終了
pkill -f "Google Chrome"

# 2. Dockから通常のChromeを起動
# → これでGoogleにログイン可能
```

### 教訓

- **自動化用ブラウザではGoogleログインは不可**
- headlessモードを使えば混同を防げる
- 認証が必要なサイトの自動化は `storage_state` で認証状態を保存・復元する方法を使う

---

## 🚨 MCP使用時のユーザーChromeブラウザ保護（必須）

### 絶対禁止事項

MCP（Playwright MCP / Chrome DevTools MCP）使用時、以下の操作は**絶対に行わない**：

| 禁止操作 | 理由 |
|---------|------|
| ユーザーのChromeプロファイルへのアクセス | 拡張機能・ブックマーク・認証情報が消失する |
| `--user-data-dir` でユーザープロファイル指定 | プロファイル破損の原因 |
| Googleアカウントへのログイン操作 | ボット検知でアカウントがブロックされる可能性 |
| ユーザーの通常Chrome使用中のMCP操作 | セッション競合でデータ破損 |

### MCPツール使用時の必須ルール

```
1. headlessモードを優先使用
2. ユーザーのChromeプロファイルには絶対にアクセスしない
3. 認証が必要な場合はCookie/storage_stateを使用（プロファイル直接使用禁止）
4. MCP操作前にユーザーの通常Chromeに影響がないことを確認
```

### 安全な使用パターン

```python
# ✅ 安全: 独立したブラウザインスタンス
browser = await playwright.chromium.launch(headless=True)
context = await browser.new_context()

# ✅ 安全: 認証状態を別途保存・読み込み
context = await browser.new_context(storage_state="auth_state.json")

# ❌ 危険: ユーザープロファイル直接使用
context = await playwright.chromium.launch_persistent_context(
    "~/Library/Application Support/Google/Chrome",  # 絶対禁止
    ...
)
```

### MCP操作後の確認事項

MCPでブラウザ操作を行った後：
1. ユーザーの通常Chromeが正常に起動するか確認
2. 拡張機能が残っているか確認
3. Googleアカウントにログインできるか確認

### 問題が発生した場合の復旧

```bash
# 1. すべてのChromeを終了
pkill -9 "Google Chrome"

# 2. chrome://settings/syncSetup にアクセス
# 3. 「拡張機能」の同期がONか確認
# 4. Googleアカウントで再ログインして同期復元
```
