# 設定ファイル例

## 基本構造

```json
{
  "settings": {
    "request_delay": 1.0,
    "timeout": 30,
    "encoding": "utf-8"
  },
  "input": {
    "type": "excel または csv",
    "file": "ファイルパス",
    "sheet": "シート名（Excel時）",
    "columns": {"出力名": 列インデックス}
  },
  "url_template": "https://example.com/item/{id}/",
  "extractors": {
    "フィールド名": {
      "selector": "CSSセレクタ",
      "multiple": false,
      "join": "; "
    }
  },
  "output": {
    "file": "output.csv"
  }
}
```

## 例1: 商品情報取得（占いプライム）

```json
{
  "settings": {
    "request_delay": 1.0
  },
  "input": {
    "type": "excel",
    "file": "/path/to/products.xlsx",
    "sheet": "Sheet1",
    "columns": {
      "product_id": 0,
      "title": 1,
      "category": 2,
      "author": 3,
      "sales_count": 4,
      "sales_amount": 5
    }
  },
  "url_template": "https://uranai-box.com/fortune-telling/{product_id:06d}/",
  "extractors": {
    "商品見出し": {
      "selector": "ul.sub_header li",
      "multiple": true,
      "join": "; "
    }
  },
  "output": {
    "file": "商品見出し一覧.csv"
  }
}
```

## 例2: ニュース記事取得

```json
{
  "input": {
    "type": "csv",
    "file": "articles.csv"
  },
  "url_template": "{url}",
  "extractors": {
    "タイトル": {
      "selector": "h1.article-title"
    },
    "本文": {
      "selector": "div.article-body p",
      "multiple": true,
      "join": "\n"
    },
    "公開日": {
      "selector": "time.publish-date",
      "attr": "datetime"
    }
  }
}
```

## 例3: ECサイト商品情報

```json
{
  "url_template": "https://shop.example.com/product/{sku}/",
  "extractors": {
    "商品名": {"selector": "h1.product-name"},
    "価格": {
      "selector": "span.price",
      "regex": "[0-9,]+"
    },
    "在庫状況": {"selector": "div.stock-status"},
    "説明": {"selector": "div.description"},
    "画像URL": {
      "selector": "img.main-image",
      "attr": "src"
    }
  }
}
```

## extractors設定詳細

| パラメータ | 説明 | 例 |
|-----------|------|-----|
| selector | CSSセレクタ | `"ul.menu li"`, `"#content"` |
| attr | 取得する属性（省略時はテキスト） | `"href"`, `"src"` |
| multiple | 複数要素を取得するか | `true` / `false` |
| join | multiple時の結合文字 | `"; "`, `"\n"` |
| regex | 正規表現でフィルタ | `"[0-9]+"` |
| default | 取得失敗時のデフォルト値 | `""`, `"N/A"` |

## URL テンプレート

プレースホルダー `{カラム名}` を使用:

```
https://example.com/item/{id}/
https://example.com/user/{user_id}/profile
{url}  ← CSV内のURL列をそのまま使用
```

数値フォーマット:
```
{id:06d}  → 6桁ゼロ埋め（例: 123 → 000123）
{id:04d}  → 4桁ゼロ埋め
```
