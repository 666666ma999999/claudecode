---
name: web-scraping-guide
description: |
  Webスクレイピングのツール選択とFirecrawl実装パターンガイド。
  Actionsパターン、LLM Extractパターン、バッチ最適化の具体的な実装例を提供。
  使用タイミング:
  (1) Firecrawlでスクレイピングを実装する
  (2) JSレンダリングが必要なページからデータを取得する
  (3) LLMベースの構造化データ抽出を行う
  (4) サイト全体をバッチでクロールする
  キーワード: Firecrawl, スクレイピング, actions, extract, LLM抽出, バッチ, クロール, JSレンダリング
---

# Web Scraping Guide - Firecrawl実装パターン

## Actionsパターン（ページ操作）

`firecrawl_scrape`の`actions`パラメータでスクレイピング前にページ操作を実行:

| アクション | 用途 |
|-----------|------|
| `click` (selector) | ボタンクリック・タブ切り替え・「もっと見る」展開 |
| `scroll` (direction, amount) | 無限スクロールページの全件取得 |
| `write` (text, selector) + `press` (key) | 検索フォーム入力→実行 |
| `wait` (milliseconds) | 動的コンテンツの読み込み待機 |
| `executeJavascript` (script) | カスタムDOM操作 |

### 使用例: 検索実行後のスクレイピング

```
firecrawl_scrape(
  url="https://example.com/search",
  formats=["markdown"],
  actions=[
    {"type": "write", "selector": "input#search", "text": "検索キーワード"},
    {"type": "press", "key": "Enter"},
    {"type": "wait", "milliseconds": 3000},
    {"type": "scroll", "direction": "down", "amount": 3}
  ]
)
```

### 使用例: 「もっと見る」ボタンの繰り返しクリック

```
firecrawl_scrape(
  url="https://example.com/list",
  formats=["markdown"],
  actions=[
    {"type": "click", "selector": "button.load-more"},
    {"type": "wait", "milliseconds": 2000},
    {"type": "click", "selector": "button.load-more"},
    {"type": "wait", "milliseconds": 2000}
  ]
)
```

## LLM Extractパターン（構造化データ抽出）

`firecrawl_extract`でJSON schemaベースの構造化データをLLMで抽出。CSSセレクタ特定が困難な場合に有効:

```
firecrawl_extract(
  urls=["https://example.com/page"],
  prompt="抽出指示",
  schema={"type": "object", "properties": {...}, "required": [...]}
)
```

- 複数URLを`urls`配列に渡して一括抽出可能
- テーブル・リストは`array`型のschemaで抽出

### 使用例: 商品情報の構造化抽出

```
firecrawl_extract(
  urls=["https://example.com/product/123"],
  prompt="商品の名前、価格、説明、在庫状況を抽出してください",
  schema={
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "price": {"type": "number"},
      "description": {"type": "string"},
      "in_stock": {"type": "boolean"},
      "features": {
        "type": "array",
        "items": {"type": "string"}
      }
    },
    "required": ["name", "price"]
  }
)
```

### 使用例: テーブルデータの一括抽出

```
firecrawl_extract(
  urls=["https://example.com/ranking"],
  prompt="ランキング表から順位、名前、スコアを全て抽出してください",
  schema={
    "type": "object",
    "properties": {
      "rankings": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "rank": {"type": "number"},
            "name": {"type": "string"},
            "score": {"type": "number"}
          }
        }
      }
    }
  }
)
```

## バッチ最適化（map -> targeted scrape）

大量ページを効率的に処理するワークフロー:

1. `firecrawl_map`でサイト内URL一覧を取得
2. 対象URLをフィルタリング
3. `firecrawl_extract`で複数URLを一括抽出（最も効率的）
4. 逐次`firecrawl_scrape`の場合はURL間に1秒以上の間隔を設ける

### ワークフロー例

```
# Step 1: サイトマップ取得
firecrawl_map(url="https://example.com")
# → URL一覧が返される

# Step 2: 対象URLをフィルタ（例: /product/ を含むURLのみ）
target_urls = [url for url in urls if "/product/" in url]

# Step 3: 一括抽出（最も効率的）
firecrawl_extract(
  urls=target_urls[:10],  # バッチサイズに注意
  prompt="商品名と価格を抽出",
  schema={...}
)

# Step 4: 逐次scrapeの場合は間隔を空ける
for url in target_urls:
    firecrawl_scrape(url=url, formats=["markdown"])
    time.sleep(1)  # 1秒以上の間隔
```

## ツール選択の判定フロー

スクレイピング全体のツール選択は `~/.claude/rules/tool-selection.md` を参照。概要:

```
Level 0: WebFetch（静的HTML）→ 最速・最軽量
Level 1: Firecrawl（JSレンダリング + actions + LLM抽出）→ bot検知回避対応
Level 2: Playwright（フルブラウザ制御）→ ログイン・セッション管理が必要な場合
```

## 関連スキル

- `web-list-scraper` - リスト駆動のバッチスクレイピング（Firecrawl統合あり）
- `x-scraping` - X（Twitter）データ取得
- `playwright-browser-automation` - フルブラウザ制御
