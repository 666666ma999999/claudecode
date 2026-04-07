# 読み込みパターン

## 方式1: スクショ方式

視覚的にデータを確認したい場合。少量データの素早い把握に最適。

### 手順

```
Step 1: ページ一覧を取得
  mcp__chrome-devtools__list_pages

Step 2: Google Sheetsのタブがあれば選択、なければナビゲート
  mcp__chrome-devtools__select_page  (pageId: N)
  または
  mcp__chrome-devtools__navigate_page
    type: "url"
    url: "https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit#gid={GID}"

Step 3: 読み込み完了を待機（Sheetsはデータロードに時間がかかる）
  mcp__chrome-devtools__wait_for
    text: ["mode_edit"]  # Sheetsの編集アイコンが表示されたらロード完了
    timeout: 10000

Step 4: スクリーンショット取得
  mcp__chrome-devtools__take_screenshot

Step 5: 画像読み取り（Claude の画像認識で内容を読む）
  Read tool でスクリーンショットファイルを読む
```

### 注意事項

- **`take_snapshot` は使えない** — Google Sheets はcanvas描画のため、a11yツリーにセルデータが含まれない
- 大量データ（100行超）はスクロールが必要 — 複数回スクショを撮る
- フィルタ/非表示行があると見えないデータがある — API GET方式を推奨

### 特定シートへの直接ナビゲーション

URLにgidを含めることで特定シートに直接遷移できる:
```
https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit#gid={GID}
```

特定範囲にフォーカスする場合:
```
https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit#gid={GID}&range=A1:D20
```

---

## 方式2: API GET方式

プログラム的にデータを取得し、後続処理で使いたい場合。

### 基本: 単一範囲の取得

```javascript
// evaluate_script で実行
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const range = encodeURIComponent("{SHEET_NAME}!{RANGE}");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}`
  );
  if (!resp.ok) {
    return { error: true, status: resp.status, body: await resp.text() };
  }
  return await resp.json();
}
```

**パラメータ例**:
- `SHEET_NAME`: `Sheet1`, `商品管理マスタ`（日本語OK、URLエンコードはencodeURIComponentで自動処理）
- `RANGE`: `A1:D10`, `A:A`（列全体）, `1:1`（行全体）

**レスポンス**:
```json
{
  "range": "商品管理マスタ!A1:D10",
  "majorDimension": "ROWS",
  "values": [
    ["占い師", "テーマ", "タイトル", "menu_id"],
    ["星野リリア", "恋愛", "二人の運命", "48200167"],
    ["月宮アリス", "仕事", "転機の兆し", ""]
  ]
}
```

### 複数範囲の一括取得

```javascript
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const ranges = [
    encodeURIComponent("{SHEET_NAME}!A1:D1"),   // ヘッダー
    encodeURIComponent("{SHEET_NAME}!A2:D100")  // データ
  ];
  const query = ranges.map(r => `ranges=${r}`).join("&");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values:batchGet?${query}`
  );
  if (!resp.ok) {
    return { error: true, status: resp.status, body: await resp.text() };
  }
  return await resp.json();
}
```

### シートメタデータの取得（シート名/GID一覧）

```javascript
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}?fields=sheets.properties`
  );
  if (!resp.ok) {
    return { error: true, status: resp.status, body: await resp.text() };
  }
  return await resp.json();
}
```

**レスポンス**:
```json
{
  "sheets": [
    { "properties": { "sheetId": 0, "title": "Sheet1", "index": 0 } },
    { "properties": { "sheetId": 2025253198, "title": "商品管理マスタ", "index": 1 } }
  ]
}
```

---

## 方式選択ガイド

| 状況 | 推奨方式 |
|------|---------|
| 「このシートの中身を見せて」 | スクショ方式 |
| 「A列のデータを全部取得して」 | API GET方式 |
| 「フィルタされた結果を確認したい」 | スクショ方式（フィルタはUI操作） |
| 「取得データをCSVに変換して」 | API GET方式 |
| 「シート名の一覧を教えて」 | API GET方式（メタデータ取得） |
