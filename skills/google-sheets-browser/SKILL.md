---
name: google-sheets-browser
description: >
  Chrome DevTools MCP経由でGoogle Sheetsを読み書きするスキル。
  ブラウザの認証済みセッションを利用し、Sheets API v4を直接呼び出す。
  gogcli未設定時のフォールバックとして使用。
  キーワード: Google Sheets, スプレッドシート, Chrome DevTools, ブラウザ認証, Sheets API
allowed-tools:
  - mcp__chrome-devtools__list_pages
  - mcp__chrome-devtools__select_page
  - mcp__chrome-devtools__navigate_page
  - mcp__chrome-devtools__take_screenshot
  - mcp__chrome-devtools__evaluate_script
  - Read
  - AskUserQuestion
---

# Google Sheets Browser (Chrome DevTools MCP)

ブラウザの認証済みセッションを利用して Google Sheets を読み書きするスキル。

## ツール選択ガイド

```
gogcli 認証済み？
  → YES → 対象シートに gogcli でアクセスできる？
            → YES → gog sheets read/write を使う（gog-cli スキル参照）
            → NO (403) → Workspace外部共有禁止の可能性 → 本スキルを使う
  → NO  → 本スキルを使う
```

### 本スキルが必要な典型ケース
- Workspace（組織）アカウントが所有するシートに個人Gmailではアクセスできない
- Workspace管理者がサードパーティOAuthアプリをブロックしている
- gogcli 未設定

## 前提条件

1. **Chrome DevTools MCP** が接続中であること
2. ブラウザで **Google アカウントにログイン済み** であること（どのタブでもよい）
3. 対象スプレッドシートへの **閲覧/編集権限** があること

確認手順:
```
mcp__chrome-devtools__list_pages → Google関連のタブが存在するか確認
```

ログインしていない場合はユーザーに「Chrome でGoogleにログインしてください」と案内する。

## 必要パラメータ

| パラメータ | 説明 | 例 |
|-----------|------|-----|
| `spreadsheet_id` | URLの `/d/` と `/edit` の間の文字列 | `1lqkcwh6cgk4Wc0a8TBok82g5dU05Ov4QG9xTtHtvvBs` |
| `sheet_name` | シート名（A1 notationで使用） | `Sheet1`, `商品管理マスタ` |
| `sheet_gid` | シートID（batchUpdateで使用） | `2025253198` |
| `range` | A1 notation | `A1:D10`, `A:A` |

`spreadsheet_id` はURLから抽出: `https://docs.google.com/spreadsheets/d/{ID}/edit#gid={GID}`

## 読み込み

### 方式1: スクショ方式（視覚確認向け）

人間が目視確認したい場合、少量のデータを素早く把握したい場合に使用。

```
1. navigate_page → https://docs.google.com/spreadsheets/d/{ID}/edit#gid={GID}
2. take_screenshot → PNG取得
3. Read → 画像としてセルデータを読み取り
```

**制約**: Sheets はcanvas描画のため `take_snapshot`（a11yツリー）ではセルデータを読めない。必ず `take_screenshot` を使う。

### 方式2: API GET方式（プログラム的データ取得向け）

構造化データとして取得し、後続処理で使いたい場合に使用。

```
evaluate_script で以下のJSを実行:

async () => {
  const range = encodeURIComponent("{SHEET_NAME}!{RANGE}");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}/values/${range}`
  );
  return await resp.json();
}
```

**レスポンス構造**:
```json
{
  "range": "Sheet1!A1:D10",
  "majorDimension": "ROWS",
  "values": [
    ["ヘッダー1", "ヘッダー2", "ヘッダー3"],
    ["データ1", "データ2", "データ3"]
  ]
}
```

詳細: `references/read-patterns.md`

## 書き込み

### 方式1: セル更新（updateCells）

特定セル範囲を上書きする。既存データの更新に使用。

```
evaluate_script で batchUpdate JS を実行（references/write-patterns.md のテンプレート参照）
```

**使用例**: 特定行のF列に menu_id を書き込む

### 方式2: 行追加（values.append）

シート末尾に行を追加する。新規データの追記に使用。

```
evaluate_script で values.append JS を実行（references/write-patterns.md のテンプレート参照）
```

**使用例**: ログ行を末尾に追加

詳細: `references/write-patterns.md`

## エラーハンドリング

| HTTP Status | 原因 | 対処 |
|-------------|------|------|
| 401 | 認証切れ・未ログイン | ユーザーにブラウザでGoogleログインを案内 |
| 403 | 権限不足 | スプレッドシートの共有設定を確認するよう案内 |
| 404 | spreadsheet_id/sheet_name誤り | パラメータを再確認 |
| 429 | API レート制限 | 10秒待って再試行（最大3回） |

`evaluate_script` の戻り値で `resp.status` を必ず確認する。

## 安全ルール

1. **書き込み前に必ず対象範囲をユーザーに提示** — 何行何列に何を書くか確認
2. **大量更新（10行超）は AskUserQuestion で確認** — 意図しない上書き防止
3. **読み取り専用で済む場合は書き込みしない** — 最小権限原則
4. **batchUpdate 実行後はレスポンスの `updatedCells` を確認** — 期待件数との一致を検証

## Reference Files

- `references/read-patterns.md` — 読み込みのJSテンプレートと詳細手順
- `references/write-patterns.md` — 書き込みのJSテンプレートと使い分け
