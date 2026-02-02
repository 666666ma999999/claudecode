---
name: step6-izumo-sync
description: |
  STEP 6: 原稿本番アップ（izumo CMS）
  izumo CMSで原稿を本番環境に同期する。
  Playwright MCPを使用してブラウザ操作を自動化。
  ※Basic認証はURLに埋め込んで対応
  キーワード: STEP6, 原稿本番アップ, izumo, 同期, Basic認証, Playwright MCP
---

# STEP 6: 原稿本番アップ（izumo CMS）

## 概要

izumo CMS（izumo-dev.uranai-gogo.com）で原稿を本番環境に同期する。

## 対象システム

- **URL**: `https://izumo-dev.uranai-gogo.com/admin/`
- **認証**: Basic認証
- **認証情報**: 環境変数 `IZUMO_USER`, `IZUMO_PASSWORD`

## Basic認証の対応方法

URLに認証情報を埋め込んでアクセス:

```
https://{IZUMO_USER}:{IZUMO_PASSWORD}@izumo-dev.uranai-gogo.com/admin/
```

例:
```
https://cpadmin:arfni9134@izumo-dev.uranai-gogo.com/admin/
```

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
2. STEP 1-4 が完了していること（原稿が登録済み）
3. 認証情報が環境変数に設定済み

## 実行フロー

### 1. izumo-dev 管理画面にアクセス

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/

1. browser_navigate → Basic認証付きURL
2. browser_snapshot → 管理画面確認
```

### 2. 同期実行

```
1. browser_snapshot → 同期ボタン確認
2. browser_click (ref: "同期" ボタン) → 同期実行
3. browser_wait_for (text: "同期完了") → 完了確認
4. browser_take_screenshot → 結果スクリーンショット
```

### 3. izumo-chk で確認（オプション）

```
URL: https://{IZUMO_CHK_USER}:{IZUMO_CHK_PASSWORD}@izumo-chk.uranai-gogo.com/admin/sync_compare.html

1. browser_navigate → チェックサイト
2. browser_snapshot → 同期状態確認
3. browser_take_screenshot → 確認スクリーンショット
```

## セレクタ参照

### izumo-dev 管理画面

| 要素 | セレクタ/テキスト | 説明 |
|------|------------------|------|
| 同期ボタン | `button "同期"` | 本番同期実行 |
| 全体同期 | `button "全体同期"` | 全原稿同期 |
| 差分同期 | `button "差分同期"` | 変更分のみ同期 |

## 認証情報（環境変数）

| 環境変数 | サイト | 用途 |
|----------|--------|------|
| `IZUMO_USER` | izumo-dev | ユーザー名 |
| `IZUMO_PASSWORD` | izumo-dev | パスワード |
| `IZUMO_CHK_USER` | izumo-chk | ユーザー名 |
| `IZUMO_CHK_PASSWORD` | izumo-chk | パスワード |

## 出力

- `success`: 成功/失敗
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| 認証失敗 (401) | 認証情報確認、URLを再構成 |
| 接続エラー | VPN接続確認（必要な場合） |
| 同期エラー | エラーメッセージ取得、スクリーンショット |

## 使用例

```
/step6

※引数不要（STEP 1-4で登録した原稿を同期）
```

## 補足

### Basic認証の注意点

- URLに認証情報を直接埋め込むため、ログに残る可能性がある
- 本番運用ではログの取り扱いに注意
- スクリーンショットにURLバーが写らないよう注意

### 同期の種類

1. **差分同期**: 変更された原稿のみ同期（推奨）
2. **全体同期**: 全原稿を再同期（時間がかかる）

## 完了確認（必須）

**STEP 6 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. izumo-dev 管理画面でPPV一覧を確認
   URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/ppv.html

2. browser_snapshot でPPV一覧を取得

3. 以下を確認:
   - ppv_id が一覧に存在
   - 同期日時が最新
   - ステータスが「同期済み」
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| 同期メッセージ | 「同期完了」表示 | snapshot内を検索 |
| ppv_id存在 | PPV一覧にppv_idあり | ppv.htmlで検索 |
| 同期日時 | 最新の日時 | 該当行の日時列 |

### 確認コード例

```javascript
// snapshotから確認
const hasSyncComplete = snapshot.includes('同期完了') || snapshot.includes('sync completed');
const hasPpvId = snapshot.includes('{ppv_id}');
if (!hasSyncComplete) {
  throw new Error('STEP 6 確認失敗: 同期完了メッセージなし');
}
console.log('✅ STEP 6 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| 認証エラー(401) | Basic認証失敗 | 認証情報をURL再構成 |
| ppv_id未表示 | 同期未実行 | 同期ボタンを再クリック |
| 同期エラー | データ不整合 | STEP 1-4を再確認 |

---

## 統一APIエンドポイント

STEP 6はセッション駆動の統一APIでも実行可能:

```
POST /api/step/6/execute
{
  "session_id": "xxx",
  "overrides": {"headless": false}
}
```

- STEP 5がSUCCESSまたはSKIPPEDでないと実行不可
- sync_complete/sync_messageをガード用に保存
- 既存API `/api/izumo/sync-production` も引き続き利用可能

---

## 依存関係

**STEP 6 は STEP 5 の完了後に実行すること。**
**STEP 6 の完了後に STEP 7 を実行すること（並列実行禁止）。**

### 実行順序
```
STEP 5: 売上集計登録（MKB）
    ↓ （完了確認後）
STEP 6: 原稿本番アップ（izumo同期）← このスキル
    ↓ （完了確認後）
STEP 7: 小見出し登録（izumo反映）
```

### 並列実行禁止の理由
- STEP 6 と STEP 7 は同じizumo CMSを使用
- STEP 6 の同期が完了する前に STEP 7 を実行すると、古いデータで反映される
- 必ず同期完了を確認してから STEP 7 を実行すること
