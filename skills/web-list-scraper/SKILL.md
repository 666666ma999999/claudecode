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

## JSレンダリング対応（Firecrawl連携・任意）

Firecrawl MCPが有効な場合、JSレンダリングが必要なページの取得をFirecrawlにフォールバックできる。

### 判定基準
- 静的HTMLで要素が取得できない場合 → Firecrawlで再取得を試行
- リスト内に `need_js` フラグがある行 → Firecrawlを優先使用

### 使い方
```python
# extractorsで要素が見つからない場合のフォールバック
# Firecrawl MCPのfirecrawl_scrapeを使用してMarkdownを取得
# 取得したMarkdownから正規表現等で情報を抽出
```

### Firecrawl未導入時
- 従来通り静的HTML取得のみで動作（警告ログを出力）
- 既存の動作に影響なし

## エラー対処

| 問題 | 対処 |
|------|------|
| 403エラー | User-Agent変更、request_delay増加 |
| タイムアウト | timeout値を増加 |
| 文字化け | encoding指定（utf-8, shift_jis等） |
| 要素が見つからない | CSSセレクタを再確認、ページ構造変更の可能性 |
