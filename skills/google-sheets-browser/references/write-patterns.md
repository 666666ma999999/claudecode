# 書き込みパターン

## 方式1: セル更新（updateCells via batchUpdate）

特定セル範囲を上書きする。既存データの更新に使用。

### 単一セル更新

```javascript
// evaluate_script で実行
// パラメータ: SPREADSHEET_ID, SHEET_GID, ROW (1-indexed), COL (0-indexed), VALUE
async () => {
  const row = {ROW} - 1;  // API は 0-indexed
  const resp = await fetch(
    "https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}:batchUpdate",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        requests: [{
          updateCells: {
            range: {
              sheetId: {SHEET_GID},
              startRowIndex: row,
              endRowIndex: row + 1,
              startColumnIndex: {COL},
              endColumnIndex: {COL} + 1
            },
            rows: [{
              values: [{
                userEnteredValue: { stringValue: "{VALUE}" }
              }]
            }],
            fields: "userEnteredValue"
          }
        }]
      })
    }
  );
  const result = await resp.json();
  return { status: resp.status, result };
}
```

### 複数セル一括更新

```javascript
// evaluate_script で実行
// updates: [{row: 2, col: 5, value: "abc"}, {row: 3, col: 5, value: "def"}, ...]
async () => {
  const updates = [
    { row: 2, col: 5, value: "48200167" },
    { row: 3, col: 5, value: "48200168" },
    { row: 4, col: 5, value: "48200169" }
  ];

  const requests = updates.map(u => ({
    updateCells: {
      range: {
        sheetId: {SHEET_GID},
        startRowIndex: u.row - 1,
        endRowIndex: u.row,
        startColumnIndex: u.col,
        endColumnIndex: u.col + 1
      },
      rows: [{
        values: [{
          userEnteredValue: { stringValue: u.value }
        }]
      }],
      fields: "userEnteredValue"
    }
  }));

  const resp = await fetch(
    "https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}:batchUpdate",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ requests })
    }
  );
  const result = await resp.json();
  return {
    status: resp.status,
    updatedCells: updates.length,
    result
  };
}
```

### 範囲更新（複数列 x 複数行）

```javascript
// evaluate_script で実行
// 2行 x 3列の範囲を一括更新
async () => {
  const resp = await fetch(
    "https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}:batchUpdate",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        requests: [{
          updateCells: {
            range: {
              sheetId: {SHEET_GID},
              startRowIndex: 1,   // 2行目から (0-indexed)
              endRowIndex: 3,     // 4行目まで（排他的）
              startColumnIndex: 0, // A列から
              endColumnIndex: 3    // C列まで（排他的）
            },
            rows: [
              { values: [
                { userEnteredValue: { stringValue: "A2" } },
                { userEnteredValue: { stringValue: "B2" } },
                { userEnteredValue: { numberValue: 100 } }
              ]},
              { values: [
                { userEnteredValue: { stringValue: "A3" } },
                { userEnteredValue: { stringValue: "B3" } },
                { userEnteredValue: { numberValue: 200 } }
              ]}
            ],
            fields: "userEnteredValue"
          }
        }]
      })
    }
  );
  return { status: resp.status, result: await resp.json() };
}
```

---

## 方式2: 行追加（values.append）

シート末尾に新しい行を追加する。ログ・履歴の追記に使用。

### 単一行追加

```javascript
// evaluate_script で実行
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const range = encodeURIComponent("{SHEET_NAME}!A:Z");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        values: [
          ["値1", "値2", "値3", 100]
        ]
      })
    }
  );
  return { status: resp.status, result: await resp.json() };
}
```

### 複数行追加

```javascript
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const range = encodeURIComponent("{SHEET_NAME}!A:Z");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        values: [
          ["行1-A", "行1-B", "行1-C"],
          ["行2-A", "行2-B", "行2-C"],
          ["行3-A", "行3-B", "行3-C"]
        ]
      })
    }
  );
  return {
    status: resp.status,
    appendedRows: 3,
    result: await resp.json()
  };
}
```

---

## 方式3: 範囲上書き（values.update）

A1 notation で指定した範囲を上書きする。updateCells より簡潔だが GID 不要（シート名で指定）。

```javascript
async () => {
  const spreadsheetId = "{SPREADSHEET_ID}";
  const range = encodeURIComponent("{SHEET_NAME}!B2:C4");
  const resp = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}?valueInputOption=USER_ENTERED`,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        values: [
          ["B2の値", "C2の値"],
          ["B3の値", "C3の値"],
          ["B4の値", "C4の値"]
        ]
      })
    }
  );
  return { status: resp.status, result: await resp.json() };
}
```

---

## valueInputOption の選択

| オプション | 動作 | 用途 |
|-----------|------|------|
| `RAW` | 入力値をそのまま保存（数式も文字列扱い） | ID、コード値などリテラル値 |
| `USER_ENTERED` | Sheets UI と同じ解釈（数式実行、日付変換、数値変換） | 日付、数値、数式を含むデータ |

デフォルト推奨: `USER_ENTERED`（最も直感的）。ID やコード値を書く場合は `RAW` を推奨。

## userEnteredValue の型

| フィールド | 用途 | 例 |
|-----------|------|-----|
| `stringValue` | 文字列 | `{ stringValue: "hello" }` |
| `numberValue` | 数値 | `{ numberValue: 42 }` |
| `boolValue` | 真偽値 | `{ boolValue: true }` |
| `formulaValue` | 数式 | `{ formulaValue: "=SUM(A1:A10)" }` |

---

## 方式選択ガイド

| 状況 | 推奨方式 |
|------|---------|
| 特定セルを個別に更新 | updateCells（方式1） |
| 行末に新データを追加 | values.append（方式2） |
| A1 notation で範囲指定して上書き | values.update（方式3） |
| GID は知っているがシート名が不明 | updateCells（方式1: GID で指定） |
| シート名は知っているが GID が不明 | values.update（方式3: シート名で指定） |
| 数式を書き込みたい | values.update + `USER_ENTERED` or updateCells + `formulaValue` |

## レスポンス確認

書き込み後は必ず `resp.status` を確認:
```javascript
if (resp.status !== 200) {
  // エラー: result.error.message を確認
}
```

成功時の batchUpdate レスポンス:
```json
{
  "spreadsheetId": "...",
  "replies": [
    { "updateCells": { "updatedRows": 1, "updatedColumns": 1, "updatedCells": 1 } }
  ]
}
```
