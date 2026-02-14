# スクレイピングパターン詳細

## データ収集（スクレイピング）

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

## ページネーション処理

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

## 指定日付までスクロール＆全件取得パターン

無限スクロール型のフィード（メルカリ、X/Twitter、ECサイト検索結果等）で、指定した日付に到達するまでスクロールし続けて全データを取得する汎用パターン。

### 問題

- 「直近1週間」「過去30日」のようにユーザーが期間指定するが、サイトにはフィルタ機能がない
- スクロール回数を固定すると、取引が少ない期間は足りず、多い期間は無駄にスクロールする
- 「何回スクロールすれば足りるか」が事前にわからない

### 解決策: 日付ベースの動的スクロール終了

```python
import re
from datetime import datetime, timedelta

def scroll_until_date(page, target_days_ago: int, max_scrolls: int = 100) -> int:
    """
    指定日数前の投稿に到達するまでスクロールする。

    Args:
        page: Playwright Page オブジェクト
        target_days_ago: 何日前まで遡るか（例: 7 = 1週間前）
        max_scrolls: 最大スクロール回数（安全弁）

    Returns:
        スクロールした回数
    """
    prev_count = 0
    no_change_streak = 0

    for i in range(max_scrolls):
        page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        page.wait_for_timeout(2000)  # コンテンツ読み込み待ち

        # 現在の商品/投稿数をカウント
        current_count = page.evaluate('''() => {
            // サイトに合わせてセレクタを変更
            return document.querySelectorAll('a[href*="/item/"]').length;
        }''')

        print(f"スクロール {i+1}: {current_count}件")

        # 新しいコンテンツが追加されなくなったら終了
        if current_count == prev_count:
            no_change_streak += 1
            if no_change_streak >= 3:  # 3回連続で変化なし
                print(f"コンテンツの追加が停止。スクロール終了。")
                return i + 1
        else:
            no_change_streak = 0
        prev_count = current_count

        # 最後のアイテムの日付をチェック
        if is_past_target_date(page, target_days_ago):
            print(f"{target_days_ago}日前の投稿に到達。スクロール終了。")
            return i + 1

    print(f"最大スクロール回数({max_scrolls})に到達。")
    return max_scrolls


def is_past_target_date(page, target_days_ago: int) -> bool:
    """
    ページ内の最も古い相対日付が、指定日数を超えているか判定。

    対応フォーマット:
    - 「X分前」「X時間前」「X日前」（日本語サイト）
    - 「Xm ago」「Xh ago」「Xd ago」（英語サイト）
    - 「YYYY/MM/DD」「YYYY-MM-DD」（絶対日付）
    """
    dates = page.evaluate('''() => {
        const body = document.body.innerText;

        // 相対日付を全て抽出（日本語）
        const relativeJa = body.match(/(\\d+)(秒|分|時間|日|週間|ヶ月|年)前/g) || [];

        // 相対日付を全て抽出（英語）
        const relativeEn = body.match(/(\\d+)\\s*(s|m|h|d|w|mo|y)\\s*ago/gi) || [];

        // 絶対日付（YYYY/MM/DD or YYYY-MM-DD）
        const absolute = body.match(/(\\d{4})[\\/-](\\d{1,2})[\\/-](\\d{1,2})/g) || [];

        return {
            relativeJa: relativeJa,
            relativeEn: relativeEn,
            absolute: absolute
        };
    }''')

    # 日本語の相対日付をチェック
    for date_str in dates.get('relativeJa', []):
        match = re.search(r'(\d+)(日|週間|ヶ月|年)前', date_str)
        if match:
            num = int(match.group(1))
            unit = match.group(2)
            days = 0
            if unit == '日':
                days = num
            elif unit == '週間':
                days = num * 7
            elif unit == 'ヶ月':
                days = num * 30
            elif unit == '年':
                days = num * 365

            if days > target_days_ago:
                return True

    # 英語の相対日付をチェック
    for date_str in dates.get('relativeEn', []):
        match = re.search(r'(\d+)\s*(d|w|mo|y)', date_str, re.IGNORECASE)
        if match:
            num = int(match.group(1))
            unit = match.group(2).lower()
            days = 0
            if unit == 'd':
                days = num
            elif unit == 'w':
                days = num * 7
            elif unit == 'mo':
                days = num * 30
            elif unit == 'y':
                days = num * 365

            if days > target_days_ago:
                return True

    # 絶対日付をチェック
    target_date = datetime.now() - timedelta(days=target_days_ago)
    for date_str in dates.get('absolute', []):
        try:
            parsed = datetime.strptime(date_str.replace('/', '-'), '%Y-%m-%d')
            if parsed < target_date:
                return True
        except ValueError:
            continue

    return False


def collect_items_with_date_filter(page, item_selector: str, target_days_ago: int) -> list:
    """
    スクロール後、指定期間内のアイテムのみを収集する。

    Args:
        page: Playwright Page
        item_selector: 商品/投稿のCSSセレクタ（例: 'a[href*="/item/"]'）
        target_days_ago: 何日前まで含めるか

    Returns:
        URL/hrefのリスト（期間内のもののみ）
    """
    # まずスクロール
    scroll_until_date(page, target_days_ago)

    # 全アイテムURLを取得
    urls = page.evaluate(f'''(selector) => {{
        const links = document.querySelectorAll(selector);
        const urls = new Set();
        links.forEach(link => {{
            const href = link.getAttribute('href');
            if (href) urls.add(href);
        }});
        return Array.from(urls);
    }}''', item_selector)

    return urls
```

### 使用例

#### ECサイト: 直近1週間の売却済み商品

```python
page.goto("https://example.com/search?keyword=...&status=sold&sort=created_time&order=desc")
time.sleep(3)

scroll_until_date(page, target_days_ago=7)
urls = collect_items_with_date_filter(page, 'a[href*="/item/"]', 7)
```

#### X/Twitter: 直近30日のツイート

```python
page.goto("https://twitter.com/username")
time.sleep(3)

scroll_until_date(page, target_days_ago=30)
```

#### ECサイト: 直近3日の新着商品

```python
page.goto("https://example.com/new-arrivals")
time.sleep(3)

scroll_until_date(page, target_days_ago=3)
```

### カスタマイズポイント

| パラメータ | デフォルト | 説明 |
|-----------|-----------|------|
| `target_days_ago` | （必須） | 何日前まで遡るか |
| `max_scrolls` | 100 | 安全弁（無限ループ防止） |
| `wait_for_timeout` | 2000ms | スクロール後の待機時間（重いサイトは増やす） |
| `no_change_streak` | 3 | 何回連続で変化なしなら終了するか |
| 商品セレクタ | サイト別 | `evaluate`内のセレクタをサイトに合わせて変更 |

### 対応する日付フォーマット

| フォーマット | 例 | サイト |
|------------|-----|-------|
| `X分前` `X時間前` `X日前` | 「3日前」 | メルカリ、ヤフオク |
| `X週間前` `Xヶ月前` | 「2週間前」 | 各種日本語サイト |
| `Xd ago` `Xh ago` | 「3d ago」 | X/Twitter |
| `YYYY/MM/DD` | 「2026/02/06」 | 各種ECサイト |
| `YYYY-MM-DD` | 「2026-02-06」 | 各種Webアプリ |

### 注意事項

- **ページネーション型サイト**（スクロールではなく「次へ」ボタン）にはこのパターンは不適合。別途ページネーション対応が必要。
- **日付がDOM上にない場合**（例: 商品一覧に日付が表示されず、詳細ページにのみある場合）は、各詳細ページにアクセスして日付をチェックする2段階方式が必要。
- **レート制限**: 大量スクロールはサーバー負荷になるため、`wait_for_timeout`を適切に設定する。
