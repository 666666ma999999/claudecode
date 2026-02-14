---
name: web-form-detector
description: Webページのフォーム要素を検知し操作するスキル。ファイルアップロード、ボタンクリック、フォーム送信を自動実行。Playwrightを使用。「フォームを検知」「ボタンを探して」「ファイルをアップロード」などのリクエストで使用。
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Web Form Detector

Webページのあらゆるインタラクティブ要素を検知し、自動操作するスキル。

## トリガー条件

以下のいずれかに該当する場合に使用:
- Webページの要素を検知したい
- ボタン・リンクをクリックしたい
- フォームに入力・送信したい
- ファイルをアップロードしたい
- ページ内の操作可能な要素を把握したい

## 入力

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| url | Yes | 対象ページURL |
| action | No | detect / click / fill / upload / submit |
| target | No | 操作対象（テキスト、セレクタ、ref） |
| value | No | 入力値・選択値 |
| file_path | No | アップロードファイルパス |

## 出力

| パラメータ | 説明 |
|-----------|------|
| detected_elements | 検知した要素一覧（カテゴリ別） |
| result | 操作結果（success/error） |
| screenshot_path | 操作後のスクリーンショット |

---

## 使用ツール

**必ずPlaywright MCPを使用すること**

```
mcp__plugin_playwright_playwright__browser_*
```

---

## 要素検知カタログ

詳細は [references/element-catalog.md](references/element-catalog.md) を参照。

主要カテゴリ:
1. ボタン系（送信・通常・リンク・アイコン・トグル）
2. 入力系（テキスト・パスワード・数値・日付・ファイル）
3. 選択系（チェックボックス・ラジオ・ドロップダウン・オートコンプリート）
4. ナビゲーション系（リンク・タブ・メニュー・ページネーション）
5. モーダル・ダイアログ系
6. 特殊要素（非表示・iframe・Shadow DOM・動的生成）

---

## Firecrawl活用（初期調査の効率化）

ログイン不要のページでフォーム検知を行う場合、Firecrawlで初期調査を効率化できる。

### Step 1: Firecrawl scrapeでページ構造を取得

```
firecrawl_scrape(
  url="https://example.com/form-page",
  formats=["markdown"],
  onlyMainContent=true
)
# → ページの全体構造をMarkdownで取得
# → フォーム要素の存在・配置を高速に把握
```

### Step 2: Firecrawl extractでフォーム要素を構造化抽出

```
firecrawl_extract(
  urls=["https://example.com/form-page"],
  prompt="このページの全フォーム要素（入力フィールド、ボタン、セレクトボックス、チェックボックス等）を検出し、それぞれの名前、タイプ、選択肢、必須かどうかを抽出してください",
  schema={
    "type": "object",
    "properties": {
      "forms": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "action": {"type": "string"},
            "method": {"type": "string"},
            "fields": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "name": {"type": "string"},
                  "type": {"type": "string"},
                  "required": {"type": "boolean"},
                  "options": {"type": "array", "items": {"type": "string"}}
                }
              }
            }
          }
        }
      }
    }
  }
)
```

### Step 3: 操作が必要な場合のみPlaywrightにエスカレーション

以下の場合はPlaywrightに切り替え:
- フォームへの実際の入力・送信が必要
- ログイン後のページにフォームがある
- ファイルアップロードが必要
- iframe内のフォーム操作が必要
- 動的生成フォーム（SPA）でFirecrawlが要素を検出できない場合

### Firecrawl未導入時

- 従来通りPlaywright MCPのsnapshotで全要素を検知
- 検知精度・機能に影響なし

---

## 注意事項

- **Playwright優先**: Chrome DevToolsは使用しない
- **待機処理**: 操作前後は適切に待機
- **エラーハンドリング**: タイムアウト、要素未検出に対応
- **スクリーンショット**: 重要な操作後は証跡を保存
- **ファイルパス**: Playwrightの許可ディレクトリ内を使用

## 関連ガイド
- ツール選択基準: `~/.claude/rules/web-scraping.md` を参照
