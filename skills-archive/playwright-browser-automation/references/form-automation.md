# フォーム自動化パターン詳細

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
        logger.warning(f"入力先が見つからなかったフィールド: {js_result['notFound']}")

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

## フォーム連続入力

```python
async def fill_form(page, data: dict):
    for field_name, value in data.items():
        field = page.locator(f"input[name='{field_name}']")
        if await field.count() > 0:
            await field.fill(value)
```

## HTML日付・時刻フィールドの入力形式

HTMLのtype属性によって入力形式が異なる。間違った形式だとエラーになる：

```python
# エラーになるパターン
await page.locator('#date_field').fill('2026/12/24')  # type="date"にスラッシュ形式

# 正しい形式
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

## 複数セレクタ段階的フォールバックパターン

認証フォームやサイトごとに異なる入力フィールドのname/type属性に対応するため、複数セレクタを優先度順に試行する。

### 問題

サイトによって認証コード入力欄のHTML属性が異なる:
- `input[name="otp"]`
- `input[type="tel"]`
- `input[placeholder="6桁の認証番号"]`
- `input[inputmode="numeric"]`

1つのセレクタでは汎用性がない。

### 解決策: 優先度付きセレクタチェーン

```python
def find_auth_code_input(page):
    """認証コード入力欄を段階的に探索"""
    selectors = [
        'input[placeholder*="認証"]',      # 日本語サイト
        'input[placeholder*="verify"]',     # 英語サイト
        'input[name*="code"]',             # name属性
        'input[name*="otp"]',              # OTP系
        'input[type="tel"]',               # 電話番号型
        'input[type="number"]',            # 数値型
        'input[inputmode="numeric"]',      # モバイル数値キーボード
        'input[type="text"]',              # 最終フォールバック
    ]

    for selector in selectors:
        locator = page.locator(selector)
        if locator.count() > 0:
            return locator.first

    raise Exception("認証コード入力欄が見つかりません")
```

### 応用: ログインフォームの汎用探索

```python
def find_login_fields(page):
    """ログインフォームのフィールドを汎用的に探索"""
    email_selectors = [
        'input[type="email"]',
        'input[name*="email"]',
        'input[name*="mail"]',
        'input[placeholder*="メール"]',
        'input[placeholder*="電話"]',
        'input[name*="user"]',
        'input[name*="login"]',
    ]

    password_selectors = [
        'input[type="password"]',
        'input[name*="pass"]',
    ]

    email_input = None
    for sel in email_selectors:
        loc = page.locator(sel)
        if loc.count() > 0:
            email_input = loc.first
            break

    pass_input = None
    for sel in password_selectors:
        loc = page.locator(sel)
        if loc.count() > 0:
            pass_input = loc.first
            break

    return email_input, pass_input
```
