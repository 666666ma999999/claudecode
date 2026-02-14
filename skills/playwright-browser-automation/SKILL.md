---
name: playwright-browser-automation
description: |
  Playwrightを使用したブラウザ自動化スキル。Webスクレイピング、フォーム自動入力、E2Eテスト、
  CDP接続によるbot検知回避など、あらゆるブラウザ操作を支援。
  キーワード: Playwright, ブラウザ自動化, CDP, スクレイピング, E2Eテスト
allowed-tools: "Bash(python:*) Bash(node:*) Read Write Edit Glob Grep WebFetch"
compatibility: "requires: Playwright (npm package), Chromium browser"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: web-scraping
  tags: [playwright, browser, cdp, bot-detection]
---

# Playwright Browser Automation

Playwright を使用したブラウザ自動化のためのスキル。Webスクレイピング、フォーム自動入力、E2Eテスト、CDP接続によるbot検知回避など、あらゆるブラウザ操作を支援します。

## トリガー

以下のフレーズで発動します：
- 「Playwrightで」「ブラウザ自動化」
- 「Webスクレイピング」「データ抽出」
- 「フォーム自動入力」「自動ログイン」
- 「E2Eテスト」「ブラウザテスト」

## パターン選択ディシジョンツリー

```
1. bot検知されるサイト（X, Google等）？
   → YES → CDP接続パターン (references/cdp-patterns.md)
2. 2FA/SMS認証が必要？
   → YES → 2FA一時停止→CDP再接続 (references/cdp-patterns.md)
3. フォーム自動入力？フィールド名不明？
   → YES → フォーム事前調査パターン (references/form-automation.md)
4. データ収集/スクレイピング？
   → YES → スクレイピングパターン (references/scraping-patterns.md)
5. 無限スクロール + 日付ベース取得？
   → YES → 日付スクロールパターン (references/scraping-patterns.md)
6. プロキシ経由のアクセス？
   → YES → プロキシ認証パターン (references/advanced-patterns.md)
7. エラー・接続問題？
   → YES → トラブルシューティング (references/troubleshooting.md)
```

## クイックスタート

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
            await page.goto("https://example.com")
        finally:
            await browser.close()

asyncio.run(main())
```

## 主要操作（クイックリファレンス）

### ナビゲーション
```python
await page.goto(url, wait_until="networkidle", timeout=60000)
```

### 要素選択（推奨順）
```python
page.get_by_role("button", name="ログイン")   # ロールベース（推奨）
page.get_by_text("送信")                       # テキストベース
page.locator("input[name='email']")            # CSSセレクタ
```

### クリック・入力
```python
await page.get_by_role("button", name="送信").click()
await page.get_by_role("textbox", name="メール").fill("user@example.com")
await page.keyboard.press("Enter")
```

### 待機処理
```python
await page.locator(".modal").wait_for(state="visible", timeout=30000)
await page.wait_for_load_state("networkidle")
```

### データ抽出
```python
text = await page.locator(".title").text_content()
href = await page.locator("a").get_attribute("href")
elements = await page.locator(".item").all()
```

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

## 安全に関する重要ルール

- **ユーザーのChromeプロファイルを直接使用しない**（破損リスク）
- **`use_user_profile`のデフォルトは必ず`False`**
- **認証情報はハードコードせず環境変数で管理**
- **プロファイルを使う場合は必ずコピーして使用し、終了時にクリーンアップ**

See `references/bot-detection.md` for details on profile safety and MCP browser protection.

## インストール

```bash
pip install playwright
playwright install chromium
```

## ユーザーへの確認事項

実装前に AskUserQuestion で確認：
- 対象サイトのURL
- 必要な操作（ログイン、データ抽出、フォーム入力など）
- ヘッドレスモードで実行するか
- 動画録画・トレース記録が必要か
- エラー時のリトライ処理が必要か

## 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| `references/cdp-patterns.md` | CDP接続、Cookie抽出、2FA対応、Cookie有効期限管理、ブラウザキャッシュクリア |
| `references/bot-detection.md` | Bot検知回避、MCP Googleログインブロック、プロファイル保護、環境変数認証管理 |
| `references/scraping-patterns.md` | データ収集、ページネーション、テーブル行操作、日付スクロール、登録確認、非同期バックエンド確認 |
| `references/form-automation.md` | フィールド事前調査、汎用ログイン、一括入力、日付入力形式、セレクタフォールバック |
| `references/troubleshooting.md` | ナビゲーションエラー、ダイアログ問題、接続エラー判定、Docker VNC問題、エラーハンドリング |
| `references/advanced-patterns.md` | playwright_session.py共通モジュール、BaseBrowserAutomation、プロキシ認証、設定オプション、トレース・動画 |

## デバッグ方法

```bash
headless=False              # ブラウザ表示
slow_mo=500                 # スローモーション
playwright show-trace trace.zip  # トレースビューア
```
