---
name: step7-subtitle
description: |
  STEP 7: 小見出し登録（izumo-dev CMS）
  izumo CMSで小見出し情報を反映する。
  Playwright MCPを使用してブラウザ操作を自動化。
  ※Basic認証はURLに埋め込んで対応
  キーワード: STEP7, 小見出し登録, izumo, 反映, Basic認証, Playwright MCP
---

# STEP 7: 小見出し登録（izumo-dev CMS）

## 概要

izumo CMS（izumo-dev.uranai-gogo.com）で小見出し情報を反映する。

## 対象システム

- **URL**: `https://izumo-dev.uranai-gogo.com/admin/menu.html`
- **認証**: Basic認証
- **認証情報**: 環境変数 `IZUMO_USER`, `IZUMO_PASSWORD`

## Basic認証の対応方法

URLに認証情報を埋め込んでアクセス:

```
https://{IZUMO_USER}:{IZUMO_PASSWORD}@izumo-dev.uranai-gogo.com/admin/menu.html
```

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
2. STEP 1-4 が完了していること（原稿・メニューが登録済み）
3. 以下の入力データが必要:
   - `menu_id`: 反映対象のmenu_id

## 実行フロー

### 1. メニュー管理画面にアクセス

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/menu.html

1. browser_navigate → Basic認証付きURL
2. browser_snapshot → 管理画面確認
```

### 2. menu_idでフィルター

```
1. browser_type (ref: フィルター入力欄) → menu_id入力
2. browser_click (ref: "検索" ボタン) → 検索実行
3. browser_wait_for (text: menu_id) → 検索結果確認
```

### 3. 反映実行

```
1. browser_snapshot → 対象行確認
2. browser_click (ref: "反映" ボタン) → 反映実行
3. browser_wait_for (text: "反映完了") → 完了確認
4. browser_take_screenshot → 結果スクリーンショット
```

### 4. 全menu_id一括反映（オプション）

menu_idのプレフィックスで一致する全てを反映:

```
1. browser_type (ref: フィルター入力欄) → プレフィックス入力
   例: "monthlyAffinity001"
2. browser_click (ref: "全て反映") → 一括反映
3. browser_wait_for (text: "件反映完了") → 完了確認
```

## セレクタ参照

### メニュー管理画面

| 要素 | セレクタ/テキスト | 説明 |
|------|------------------|------|
| フィルター入力 | `input[name="filter"]` | menu_id検索 |
| 検索ボタン | `button "検索"` | 検索実行 |
| 反映ボタン | `button "反映"` | 個別反映 |
| 全て反映 | `button "全て反映"` | 一括反映 |

## menu_idの形式

```
{prefix}{number}.{subtitle_number}
```

例:
- `monthlyAffinity001.001` - 月額・相性占い・001・小見出し1
- `ppvGyoun001.027` - PPV・行運占い・001・小見出し27

## 出力

- `success`: 成功/失敗
- `menu_id`: 反映したmenu_id
- `count`: 反映件数（一括の場合）
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| 認証失敗 (401) | 認証情報確認、URLを再構成 |
| menu_idが見つからない | menu_id確認、STEP 2-4の完了確認 |
| 反映エラー | エラーメッセージ取得、スクリーンショット |

## 使用例

### 個別反映

```
/step7

入力:
- menu_id: monthlyAffinity001.001
```

### 一括反映（プレフィックス指定）

```
/step7

入力:
- menu_id_prefix: monthlyAffinity001
  ※ monthlyAffinity001.001 ～ monthlyAffinity001.XXX を全て反映
```

## 補足

### 反映の仕組み

STEP 2-4で原稿管理CMSに登録したデータを、izumo CMSの内部データベースに同期する処理。

### 反映順序

1. 個別反映: 特定のmenu_idのみ反映
2. 一括反映: プレフィックスマッチする全menu_idを反映
3. 全体反映: STEP 6で実行

## 完了確認（必須）

**STEP 7 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. メニュー管理画面でmenu_idを検索
   URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/menu.html

2. browser_type でmenu_idをフィルター入力

3. browser_snapshot で結果を取得

4. 以下を確認:
   - menu_id が検索結果に存在
   - ステータスが「反映済み」
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| 反映メッセージ | 「反映完了」表示 | snapshot内を検索 |
| menu_id存在 | 検索結果にmenu_idあり | フィルター検索 |
| 反映ステータス | 「反映済み」表示 | 該当行のステータス列 |

### 確認コード例

```javascript
// snapshotから確認
const hasReflectComplete = snapshot.includes('反映完了') || snapshot.includes('件反映');
const hasMenuId = snapshot.includes('{menu_id}');
if (!hasReflectComplete || !hasMenuId) {
  throw new Error('STEP 7 確認失敗: 反映が完了していません');
}
console.log('✅ STEP 7 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| menu_id未表示 | STEP 6未完了 | STEP 6の同期を先に実行 |
| 反映エラー | データ不整合 | STEP 2-4を再確認 |
| 認証エラー | Basic認証失敗 | 認証情報をURL再構成 |

---

## 統一APIエンドポイント

STEP 7はセッション駆動の統一APIでも実行可能:

```
POST /api/step/7/execute
{
  "session_id": "xxx",
  "overrides": {"menu_id_prefix": "monthlyAffinity001"}
}
```

- STEP 6がSUCCESSでないと実行不可
- menu_id_prefixはセッションから自動導出（menu_idのドット前部分）
- reflect_complete/reflect_messageをガード用に保存
- 既存API `/api/izumo/reflect-menu-all` も引き続き利用可能

---

## 依存関係

**STEP 7 は STEP 6 の完了後に実行すること（並列実行禁止）。**
**STEP 7 の完了後に STEP 8 を実行すること（並列実行禁止）。**

### 実行順序
```
STEP 6: 原稿本番アップ（izumo同期）
    ↓ （完了確認後）
STEP 7: 小見出し登録（izumo反映）← このスキル
    ↓ （完了確認後）
STEP 8: 従量自動更新
```

### 並列実行禁止の理由
- STEP 6, 7, 8 は全て同じizumo CMSを使用
- STEP 6 の同期が完了する前に反映すると、古いデータで反映される
- STEP 7 の反映が完了する前に自動更新すると、未反映のデータで更新される
- 各STEPの完了を確認してから次STEPを実行すること
