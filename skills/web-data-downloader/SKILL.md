---
name: web-data-downloader
description: Webサイトから確定申告用データを自動取得するスキル。ふるさと納税サイト（ふるなび等）の寄付履歴、クレジットカード会社（アメックス等）の利用明細PDF、その他Webサイトからのデータ取得を自動化。Playwrightブラウザ操作でログイン後のページからデータをダウンロード・スクリーンショット保存。「サイトからデータをダウンロード」「明細PDFを取得」「寄付履歴を保存」などのリクエストで使用。
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# Web Data Downloader

確定申告やデータ収集のためにWebサイトからデータを自動取得するスキル。

## ワークフロー

### 1. 事前確認

ユーザーに以下を確認:
- 対象サイト名
- 取得期間（例: 202501-202512）
- 取得するデータ種類（PDF、CSV、スクリーンショット等）
- 保存先（デフォルト: プロジェクトディレクトリ配下の`DL/`フォルダ）

### 2. サイトごとの処理フロー

```
サイトにアクセス
    ↓
ログインページへ移動
    ↓
ユーザーに「ログインしてください」と依頼
    ↓
ユーザーの「ログインしました」を待つ
    ↓
対象ページへ移動（履歴、明細等）
    ↓
期間・年度を選択
    ↓
データ取得（ダウンロード or スクリーンショット）
    ↓
指定フォルダにコピー
```

### 3. データ取得方法

**PDFダウンロード**（アメックス等）:
1. 明細一覧ページで各ダウンロードボタンをクリック
2. ファイル形式選択ダイアログでPDFを選択して確定
3. `.playwright-mcp/`に保存後、指定フォルダにコピー

**スクリーンショット**（ふるなび等）:
1. 対象ページでfullPageスクリーンショットを取得
2. `.playwright-mcp/`に保存後、指定フォルダにコピー

**個別行スクリーンショット**（明細の特定行だけ切り取り）:
1. 明細一覧ページでsnapshotを取得し、対象行のrefを特定
2. `browser_take_screenshot`の`ref`パラメータに行のrefを指定して要素単位のスクリーンショットを取得
3. 命名規則: `{カード名}_{項目名}_{利用年月}_{利用日}.png`（例: `amex_manus_202512_20.png`, `smbc_claude_202601_10.png`）
4. `.playwright-mcp/`に保存後、指定フォルダにコピー

## サイト別設定

### ふるなび
- URL: https://furunavi.jp/
- ログインURL: https://furunavi.jp/login.aspx
- 取得データ: 寄附受付履歴（スクリーンショット）
- 手順: マイページ → 寄附受付履歴 → 年度選択 → スクリーンショット

### アメリカン・エキスプレス
- URL: https://www.americanexpress.com/ja-jp/
- ログインURL: https://www.americanexpress.com/ja-jp/account/login
- ダッシュボード: https://global.americanexpress.com/dashboard
- 取得データ: ご利用代金明細書（PDF）、個別行スクリーンショット
- PDF手順: ご利用状況 → ご利用代金明細書（PDF他） → 各月のダウンロードボタン → PDF選択 → ダウンロード
- 個別行手順: ダッシュボード「ご利用履歴を見る」→ 過去のご利用分から期間選択 → 対象行のrefでスクリーンショット
- 明細ページURL: `/activity/statement?end=YYYY-MM-DD`（締め日ベース）
- 過去期間リンク: ナビの「過去のご利用分」ドロップダウンから選択
- 行のref取得: snapshotが大きい場合、JSON出力をgrepでAI項目名を検索してref特定

### 三井住友カード
- URL: https://www.smbc-card.com/
- ログインURL: https://www.smbc-card.com/mem/index.jsp
- 取得データ: 利用明細スクリーンショット（fullPage）、個別行スクリーンショット
- 手順: Vpassログイン → ご利用明細 → カード切り替え（comboboxで選択）→ 月選択 → スクリーンショット
- 複数カード: comboboxで切り替え（例: プラチナプリファード、Amazon旧ゴールド）
- 個別行手順: 明細テーブル内の対象行のrefで要素スクリーンショット

## 利用店名の表記揺れ（重要）

明細上の店名はサービス名と異なる場合がある。検索時は以下の別名も含めること：

| サービス名 | 明細上の表記例 |
|-----------|---------------|
| GOOGLE ONE | ＧＯＯＧＬＥ ＰＬＡＹ ＪＡＰＡＮ、GOOGLE GOOGLE ONE |
| CLAUDE.AI | CLAUDE.AI SUBSCRIPTION (ANTHROPIC.COM) |
| ChatGPT | OPENAI *CHATGPT SUBSCR |
| MeisterTask | MEISTERLABS (VATERSTETTEN ) |

**注意**: 全角・半角の違いにも注意。SMBCは全角カナ表記が多い。

## 保存先ルール

- 保存先はプロジェクトディレクトリ配下に`DL/`フォルダを作成し、そこにまとめる
- 例: `/Users/masaaki/Desktop/prm/collect_receipt/DL/`
- デスクトップ直下への保存は避ける

## 注意事項

- Playwrightのダウンロード先は`.playwright-mcp/`固定。取得後にBashで`DL/`フォルダにコピー
- ログインはユーザーに依頼（認証情報は扱わない）
- ダイアログ表示時は適切なボタンをクリック
- 大量ダウンロード時は各ファイル間で1-2秒待機

## bot検知でサイトにアクセスできない場合

サイトがPlaywrightを検知してアクセスをブロックする場合は、**CDP接続方式**を使用:

**→ `playwright-browser-automation` スキルの「リモートChrome接続（CDP）によるbot検知回避」を参照**

概要:
1. 通常のChromeをデバッグモード(`--remote-debugging-port=9222`)で起動
2. そのChromeで手動でサイトにログイン
3. Playwrightから`connect_over_cdp()`で接続してCookieを取得
4. 取得したCookieを使って自動化

## 出力形式

完了時は以下を報告:
- 取得したファイル一覧（ファイル名、サイズ）
- 保存先パス
- 取得データのサマリー（例: 寄付合計金額、明細件数）

## Firecrawl優先モード

ログインが不要な公開ページの場合、Playwrightの代わりにFirecrawlを優先使用することで軽量・高速に処理できる。

### 判断基準

| 条件 | 使用ツール |
|------|-----------|
| ログイン不要 + 静的HTML | WebFetch |
| ログイン不要 + JSレンダリング必要 | Firecrawl scrape |
| ログイン不要 + 構造化データ抽出 | Firecrawl extract |
| ログイン不要 + スクリーンショット | Firecrawl scrape (formats: ["screenshot"]) |
| ログイン必要 | Playwright（従来手順） |
| bot検知 Level 1 | Firecrawl proxy: "stealth" |
| bot検知 Level 2（Firecrawlで突破不可） | Playwright CDP接続（従来手順） |

### Firecrawlでのスクリーンショット取得

```
firecrawl_scrape(
  url="https://example.com/page",
  formats=["screenshot"]
)
# → スクリーンショットがbase64で返却される
# → デコードしてDL/フォルダに保存
```

### Firecrawlでの構造化データ抽出

CSSセレクタの特定が困難な場合、LLMベースで直接抽出:

```
firecrawl_extract(
  urls=["https://example.com/statement"],
  prompt="明細の日付、金額、店名を全行抽出してください",
  schema={
    "type": "object",
    "properties": {
      "transactions": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "date": {"type": "string"},
            "amount": {"type": "number"},
            "merchant": {"type": "string"}
          }
        }
      }
    }
  }
)
```

### Firecrawl未導入時

- 従来通りPlaywright MCPのみで動作
- 全サイト別設定・手順に影響なし

## 関連ガイド
- ツール選択基準: `~/.claude/rules/web-scraping.md` を参照
