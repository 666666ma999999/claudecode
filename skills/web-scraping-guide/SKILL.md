# Webスクレイピング詳細ガイド

キーワード: スクレイピング, Firecrawl, Playwright, WebFetch, Actions, LLM抽出

## ツール別の得意領域

| ツール | 得意領域 | JSレンダリング | 認証 | クロール | Actions | LLM抽出 |
|---|---|---|---|---|---|---|
| WebFetch | 静的ページ・単発・軽量 | x | x | x | x | x |
| Firecrawl MCP | JSページ・クリーンMarkdown | o | △ | o | o | o |
| web-list-scraper | CSV/Excelリスト駆動バッチ | △（Firecrawl連携時） | x | o（リスト駆動） | x | △ |
| web-data-downloader | ログイン必須サイト | o | o | x | x | x |
| web-form-detector | フォーム操作 | o | o | x | x | x |
| Playwright MCP | ブラウザ操作全般 | o | o | x | o（フル） | x |
| x-scraping | X（Twitter）専用 | o | o（CDP） | o（スクロール） | x | x |

## Firecrawl → Playwright エスカレーション条件

以下のいずれかに該当する場合、FirecrawlからPlaywrightにエスカレーション:

| 条件 | 理由 |
|------|------|
| ログイン/セッション管理が必要 | Firecrawlは認証セッション非対応 |
| bot検知がFirecrawl stealthで突破不可 | CDP接続が必要 |
| iframe/Shadow DOM内の操作 | Firecrawl actionsでは操作不可 |
| ファイルダウンロード/アップロード | Firecrawlにはファイル操作なし |
| 複雑なマルチステップフォーム | 状態管理が必要 |
| Firecrawl actionsでタイムアウト/エラー | フルブラウザにフォールバック |

## グレースフルデグレード（Firecrawl未導入時）

- WebFetchをデフォルトで使用
- JSレンダリングが必要な場合はPlaywright MCPにフォールバック
- Firecrawl actionsが必要な場面 → Playwright MCPで代替
- LLM抽出が必要な場面 → Playwright snapshot + 手動パース
- 全スキルは正常動作する（Firecrawlはオプショナル）

---

## Firecrawl Actions活用パターン

`firecrawl_scrape`の`actions`パラメータで、スクレイピング前にページ操作を実行できる。

### 利用可能なアクション

| アクション | パラメータ | 説明 |
|-----------|-----------|------|
| `click` | `selector` | 要素をクリック |
| `scroll` | `direction`, `amount` | ページスクロール（up/down） |
| `wait` | `milliseconds` | 指定ミリ秒待機 |
| `screenshot` | -- | 現在の画面をキャプチャ |
| `write` | `text`, `selector` | テキスト入力 |
| `press` | `key` | キーボードキーを押下 |
| `executeJavascript` | `script` | JavaScriptを実行 |

### パターン例

#### 「もっと見る」ボタンをクリックして全件表示

```
actions=[
  {"type": "click", "selector": "button.load-more"},
  {"type": "wait", "milliseconds": 2000},
  {"type": "click", "selector": "button.load-more"},
  {"type": "wait", "milliseconds": 2000}
]
```

#### 無限スクロールページの全件取得

```
actions=[
  {"type": "scroll", "direction": "down", "amount": 3},
  {"type": "wait", "milliseconds": 2000},
  {"type": "scroll", "direction": "down", "amount": 3},
  {"type": "wait", "milliseconds": 2000},
  {"type": "scroll", "direction": "down", "amount": 3},
  {"type": "wait", "milliseconds": 2000}
]
```

#### 検索フォームに入力してから結果を取得

```
actions=[
  {"type": "write", "text": "検索キーワード", "selector": "input[name='q']"},
  {"type": "press", "key": "Enter"},
  {"type": "wait", "milliseconds": 3000}
]
```

#### タブ切り替えでコンテンツを表示

```
actions=[
  {"type": "click", "selector": "[data-tab='details']"},
  {"type": "wait", "milliseconds": 1000},
  {"type": "screenshot"}
]
```

## Firecrawl LLM抽出パターン

`firecrawl_extract`はLLMを使用してページからJSON schemaに基づく構造化データを抽出する。CSSセレクタの特定が困難な場合に有効。

### 基本パターン

```
firecrawl_extract(
  urls=["https://example.com/product/123"],
  prompt="この商品ページから商品情報を抽出してください",
  schema={
    "type": "object",
    "properties": {
      "name": {"type": "string", "description": "商品名"},
      "price": {"type": "number", "description": "価格（税込）"},
      "description": {"type": "string", "description": "商品説明"},
      "availability": {"type": "boolean", "description": "在庫あり"}
    },
    "required": ["name", "price"]
  }
)
```

### 複数URLの一括抽出

```
firecrawl_extract(
  urls=[
    "https://example.com/product/1",
    "https://example.com/product/2",
    "https://example.com/product/3"
  ],
  prompt="各商品の名前と価格を抽出",
  schema={...}
)
```

### テーブル・リストデータの抽出

```
firecrawl_extract(
  urls=["https://example.com/transactions"],
  prompt="取引履歴テーブルの全行を抽出してください",
  schema={
    "type": "object",
    "properties": {
      "transactions": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "date": {"type": "string"},
            "description": {"type": "string"},
            "amount": {"type": "number"},
            "category": {"type": "string"}
          }
        }
      }
    }
  }
)
```

## Firecrawl可用性チェック

### チェック方法

```
# ToolSearchでFirecrawlツールの存在を確認
ToolSearch(query="+firecrawl scrape")

# ツールが見つからない場合 → Firecrawl未導入
# → WebFetch + Playwright でフォールバック
```

### フォールバック対応表

| Firecrawl機能 | 代替手段 |
|---------------|---------|
| `firecrawl_scrape` (markdown) | WebFetch（静的）or Playwright snapshot |
| `firecrawl_scrape` (screenshot) | Playwright `browser_take_screenshot` |
| `firecrawl_scrape` (actions) | Playwright でのステップ操作 |
| `firecrawl_extract` (LLM抽出) | Playwright snapshot + 手動パース |
| `firecrawl_crawl` (クロール) | web-list-scraper でURL一覧駆動 |
| `firecrawl_search` (検索) | WebSearch |

## パフォーマンス最適化

### バッチ処理の最適化

大量URLを処理する場合の戦略:

1. **firecrawl_extract**: 複数URLを`urls`配列に渡して一括抽出（最も効率的）
2. **firecrawl_crawl**: サイト全体をクロールする場合に使用
3. **逐次firecrawl_scrape**: URL間に1秒以上の間隔を設ける

### リクエスト間隔

| ツール | 推奨間隔 |
|--------|---------|
| WebFetch | 不要（キャッシュあり） |
| Firecrawl scrape | 1秒以上 |
| Firecrawl extract | バッチなら不要 |
| Playwright | 1-2秒（サイトによる） |
