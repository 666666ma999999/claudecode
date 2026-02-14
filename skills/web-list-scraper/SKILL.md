---
name: web-list-scraper
description: |
  リスト（Excel/CSV）とWebページを紐付けて詳細情報を自動取得するスクレイピングツール。
  使用タイミング:
  (1) 商品リストから商品詳細ページの情報を取得したい
  (2) URLリストから各ページの特定要素を抽出したい
  (3) IDリストとURL規則からWebページをバッチ取得したい
  (4) 大量のWebページから同一フォーマットの情報を収集したい
  キーワード: スクレイピング、Webスクレイピング、データ抽出、リスト取得、バッチ取得、Excel、CSV
compatibility: "requires: Python 3.x, Playwright"
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Web List Scraper

リスト（Excel/CSV）のデータとWebページを紐付けて、詳細情報を自動取得する。

## クイックスタート

### 1. サイト構造の調査

Playwrightでページにアクセスし、抽出対象の要素を特定:

```python
# ブラウザでページを開いて構造確認
mcp__plugin_playwright_playwright__browser_navigate(url="https://example.com/item/123/")
mcp__plugin_playwright_playwright__browser_snapshot()
```

または、curlでHTML構造を確認:
```bash
curl -s "URL" | grep -A 10 "抽出したいテキスト"
```

### 2. CSSセレクタの特定

よくあるパターン:
- `ul.class-name li` - クラス付きリストの項目
- `h1`, `h2` - 見出し
- `div.content p` - コンテンツ内の段落
- `table tr td` - テーブルセル

### 3. Pythonでスクレイピング実行

```python
from scripts.scraper import WebListScraper

scraper = WebListScraper({"request_delay": 1.0})

# Excelから読み込み
records = scraper.load_list_from_excel(
    "input.xlsx",
    columns={"id": 0, "name": 1}
)

# スクレイピング実行
results = scraper.scrape(
    records,
    url_template="https://example.com/item/{id}/",
    extractors={
        "詳細": {"selector": "div.detail", "multiple": True, "join": "; "}
    },
    output_file="output.csv"
)
```

## URL生成パターン

### パターン1: ID直接埋め込み
```
url_template = "https://example.com/item/{id}/"
# id=123 → https://example.com/item/123/
```

### パターン2: ゼロ埋めフォーマット
```python
# 商品IDを6桁ゼロ埋め
url = f"https://example.com/item/{product_id:06d}/"
# 123 → https://example.com/item/000123/
```

### パターン3: サフィックス付きID
```python
# "816_2" → "000816-2"
if '_' in str(product_id):
    parts = str(product_id).split('_')
    url = f"https://example.com/item/{int(parts[0]):06d}-{parts[1]}/"
```

### パターン4: CSV内のURLをそのまま使用
```
url_template = "{url}"
```

## 抽出設定（extractors）

```python
extractors = {
    # 単一テキスト
    "title": {"selector": "h1.title"},

    # 複数要素を結合
    "items": {
        "selector": "ul.list li",
        "multiple": True,
        "join": "; "
    },

    # 属性値を取得
    "image_url": {
        "selector": "img.main",
        "attr": "src"
    },

    # 正規表現でフィルタ
    "price": {
        "selector": "span.price",
        "regex": "[0-9,]+"
    },

    # デフォルト値
    "stock": {
        "selector": "div.stock",
        "default": "不明"
    }
}
```

## 大量データの処理

### バックグラウンド実行

```bash
nohup python3 -u scripts/scraper.py -c config.json > log.txt 2>&1 &
```

### 進捗確認

```bash
tail -20 log.txt
wc -l output.csv
```

### 途中から再開

```python
# 既存CSVを読み込み、処理済みIDを除外
processed_ids = set()
with open("output.csv") as f:
    for row in csv.DictReader(f):
        processed_ids.add(row["id"])

records = [r for r in records if r["id"] not in processed_ids]
```

## 設定ファイル例

詳細は [references/config_examples.md](references/config_examples.md) を参照。

## Firecrawl統合（JSレンダリング・LLM抽出）

Firecrawl MCPが有効な場合、JSレンダリングやLLMベースの構造化抽出を活用できる。

### 自動フォールバック判定

以下の条件でFirecrawlへの自動フォールバックが発生:
1. 静的HTML取得（requests+BS4）でextractorsの結果が**空またはデフォルト値のみ**
2. CSVカラムに`need_js`フラグが`true`の行
3. HTTPステータス403/429で静的取得がブロックされた場合

### Firecrawl scrapeでの取得手順

```
# Step 1: firecrawl_scrapeでJSレンダリング済みMarkdownを取得
firecrawl_scrape(
  url="https://example.com/item/123/",
  formats=["markdown"],
  onlyMainContent=true
)

# Step 2: 取得したMarkdownからextractors相当の情報を抽出
# - 正規表現でパターンマッチ
# - Markdown見出し構造から階層的に抽出
```

### Firecrawl extractによるLLM抽出（セレクタ不要）

CSSセレクタが特定困難な場合、LLMベースの構造化抽出を使用:

```
# JSON schemaを定義して構造化データを直接取得
firecrawl_extract(
  urls=["https://example.com/item/123/"],
  prompt="商品の名前、価格、説明、在庫状況を抽出してください",
  schema={
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "price": {"type": "number"},
      "description": {"type": "string"},
      "in_stock": {"type": "boolean"}
    }
  }
)
```

### need_jsフラグの使い方

CSVにカラムとして追加し、行単位でFirecrawl使用を制御:

```csv
id,name,url,need_js
001,商品A,https://example.com/item/001/,false
002,商品B,https://spa-site.com/item/002/,true
```

- `need_js=true`: 最初からFirecrawl scrapeで取得（静的取得をスキップ）
- `need_js=false`または未指定: 静的取得を試行、失敗時にFirecrawlフォールバック

### Firecrawl未導入時の動作保証

- 従来通り`requests + BeautifulSoup4`で静的HTML取得のみで動作
- Firecrawl MCP未接続時は警告ログを出力し、静的取得を続行
- `need_js=true`の行はスキップされず、静的取得を試行（結果が不完全な可能性あり）
- 既存のスクレイピング動作に一切影響なし

## エラー対処

| 問題 | 対処 |
|------|------|
| 403エラー | User-Agent変更、request_delay増加 |
| タイムアウト | timeout値を増加 |
| 文字化け | encoding指定（utf-8, shift_jis等） |
| 要素が見つからない | CSSセレクタを再確認、ページ構造変更の可能性 |
