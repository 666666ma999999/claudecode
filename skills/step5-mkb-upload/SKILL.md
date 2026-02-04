---
name: step5-mkb-upload
description: |
  STEP 5: 売上集計登録（MKBアクセス解析）
  MKBアクセス解析にCSVをアップロードして売上集計を登録する。
  Playwright MCPを使用してブラウザ操作を自動化。
  ※Squidプロキシ経由でアクセス（VPN不要）
  キーワード: STEP5, MKB, 売上集計, CSVアップロード, Playwright MCP
---

# STEP 5: 売上集計登録（MKBアクセス解析）

## 概要

MKBアクセス解析（swan-manage.aws.mkb.local）にCSVをアップロードし、売上集計を登録する。

## 対象システム

- **URL**: `http://swan-manage.aws.mkb.local/`
- **認証**: フォームログイン
- **認証情報**: 環境変数 `MKB_USER`, `MKB_PASSWORD`
  - デフォルト値: `MKB_USER=masaaki`, `MKB_PASSWORD=masaaki123`
  - 設定ファイル: `backend/.env`
- **ネットワーク**: Squidプロキシ経由（VPN不要）

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
3. アップロード対象のCSVファイルが準備済み
4. 以下の入力データが必要:
   - `site_id`: サイトID
   - `csv_path`: CSVファイルパス

## 実行フロー

### 1. ネットワーク接続確認

Squidプロキシ経由でアクセスする。Playwright MCPの設定でプロキシが自動適用される。

```
1. browser_navigate → http://swan-manage.aws.mkb.local/users/login
2. タイムアウトした場合 → プロキシ設定を確認
```

### 2. MKBログイン

```
URL: http://swan-manage.aws.mkb.local/users/login

1. browser_navigate → ログインページ
2. browser_snapshot → フォーム要素確認
3. browser_type (ref: ユーザー名入力欄) → ユーザー名入力
   - セレクタ: input[name="data[User][username]"]
4. browser_type (ref: パスワード入力欄) → パスワード入力
   - セレクタ: input[name="data[User][password]"]
5. browser_click (ref: ログインボタン) → ログイン実行
   - セレクタ: button[type="submit"]
6. browser_wait_for (text: "ログアウト") → ログイン完了確認
```

### 3. CSVインポートページへ移動

```
URL: http://swan-manage.aws.mkb.local/csvs/csv_in/SitePpv/

1. browser_navigate → インポートページ
2. browser_snapshot → フォーム要素確認
```

### 4. サイト選択

**注意**: `browser_select_option`が動作しない場合は`browser_evaluate`でJavaScript直接操作。

```javascript
// browser_evaluate で実行
(() => {
  const select = document.querySelector('#SitePpvSiteId');
  if (select) {
    select.value = '{SITE_ID}';  // 例: '482'
    select.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }
  return false;
})();
```

### 5. ファイルアップロード

**重要**: `browser_file_upload`は「ファイルダイアログが開いている状態」でのみ動作する。
ファイルダイアログが開いていない場合は`browser_run_code`を使用。

```javascript
// browser_run_code で実行（推奨）
async (page) => {
  await page.locator('#CsvInFile').setInputFiles('/path/to/fixed.csv');
  return 'File uploaded';
}
```

または:
```
1. browser_click (ref: ファイル入力要素) → ファイルダイアログを開く
2. browser_file_upload (paths: [csv_path]) → ファイル選択
```

### 6. フォーム送信（重要）

**注意**: 通常のクリックではフォーム送信が動作しないことがある。
`browser_evaluate` でJavaScriptから直接送信する。

```javascript
// browser_evaluate で実行
(() => {
  const form = document.querySelector('form');
  if (form) {
    form.submit();
    return true;
  }
  const btn = document.querySelector('input[value="import"]');
  if (btn) {
    btn.click();
    return true;
  }
  return false;
})();
```

### 7. 結果確認

```
1. browser_wait_for (text: "件保存しました") → 結果待機 (timeout: 15秒)
2. browser_snapshot → 結果ページ確認
3. browser_take_screenshot → 結果スクリーンショット
```

## セレクタ参照

### ログインページ

| 要素 | セレクタ | 説明 |
|------|----------|------|
| ユーザー名 | `input[name="data[User][username]"]` | ユーザー名入力欄 |
| パスワード | `input[name="data[User][password]"]` | パスワード入力欄 |
| ログインボタン | `button[type="submit"]` | ログイン実行 |

### インポートページ

| 要素 | セレクタ | 説明 |
|------|----------|------|
| サイト選択 | `#SitePpvSiteId` | サイト選択ドロップダウン |
| ファイル入力 | `#CsvInFile` | CSVファイル選択 |
| importボタン | `input[value="import"]` | インポート実行 |

## 結果判定

| メッセージ | 意味 | 状態 |
|-----------|------|------|
| `X件保存しました` | X件のレコードが保存された | 成功 |
| `0件保存しました` | 変更なし（既存レコード更新） | 成功 |
| `公開日は過去の日付に変更はできません` | public_dateが過去 | 要修正 |
| エラーメッセージ | インポート失敗 | エラー |

## CSVフォーマット

### 重要: CSVは原稿管理CMSからダウンロードする

**手動でCSVを作成しないこと。** MKBが期待する28列のフォーマットと一致しないため、インポートエラーになる。

### CSVダウンロード手順

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=up&site_id={SITE_ID}

1. browser_navigate → 原稿管理CMSのCSVダウンロードページ
2. browser_snapshot → ページ確認
3. browser_click (ref: "CSVダウンロード" または対象リンク) → CSVダウンロード
4. ダウンロードされたCSVファイルを取得
```

### CSVカラム（28列）

```
ppv_id, title, guide, docomo_sid, au_pc_code, softbank_sid, dmenu_sid,
spau_pc_code, spsb_sid, price, au_price, SoftBank_price, price_res, term,
page_num, affinity, site_code, p_menu_id, page_type, ranking_view_flg,
view_flg, ppv_category_id, menu_id_list, view_id, toc_flg, public_date,
ppv_icon_id, const_flg
```

### public_date修正（必須）

原稿管理CMSからダウンロードしたCSVの`public_date`が`0000-00-00`の場合、MKBはエラーを返す。
**アップロード前に必ず当日以降の日付に修正すること。**

```python
# Python（バイナリ置換 - エンコーディング問題回避）
from datetime import datetime

today = datetime.now().strftime('%Y-%m-%d')  # 例: 2026-01-28

with open('downloaded.csv', 'rb') as f:
    content = f.read()

content = content.replace(b'0000-00-00', today.encode('utf-8'))

with open('fixed.csv', 'wb') as f:
    f.write(content)
```

**注意**: CSVはShift-JISエンコーディングの場合があるため、`sed`ではなくPythonのバイナリ置換を推奨。

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| 接続タイムアウト（プロキシ確認） | プロキシ設定を確認、リトライ |
| ログイン失敗 | 認証情報確認を促す |
| タイムアウト | プロキシ設定確認、リトライ |
| 0件保存 | 既存データ更新の可能性（正常） |
| CSVダウンロード失敗 | 自動3回リトライ（指数バックオフ: 2s→4s）、失敗時ページリロード |

### 自動リトライ機能（2026-02-03実装、2026-02-04更新）

CSVダウンロード処理には自動リトライ機能が実装されています：

- **最大リトライ回数**: 3回
- **待機時間**: 指数バックオフ（2s → 4s）
- **失敗時リカバリ**: ページをリロードしCSVリンクを再検索
- **networkidle待機**: タイムアウト10秒（MKBネットワーク向け最適化）
- **失敗時スクリーンショット**: 各リトライごとにスクリーンショット保存

### 独立イベントループパターン（2026-02-05実装）

CSVダウンロードはFastAPIイベントループとは**独立したイベントループ**で実行される。

**問題**: FastAPIのuvicornイベントループ内でPlaywrightを実行すると、CDP WebSocket通信が干渉し、CMS SPAが"Loading.."で永続スタックする。

**解決策**: `asyncio.to_thread()` + `asyncio.run()` で独立イベントループに隔離。

```python
# download_csv() → asyncio.to_thread() → _download_csv_sync() → asyncio.run()
# _download_csv_sync() 内で独自Playwright instanceを生成（headless, no slow_mo, dialog handler only）
```

**ログ識別**: 独立イベントループ内のログは `[isolated]` プレフィックス付き。

**注意事項**:
- `_download_csv_sync()` を直接呼び出さない（既にイベントループがある場合RuntimeError）
- `session_dir` はスナップショットで渡す（スレッド安全性）
- スクリーンショットはtry/exceptで保護（失敗してもダウンロードを継続）

**セレクタ優先度（誤データ取得防止）**:
1. ppv_idを含む行のCSVリンク
2. menu_id（save_id）を含むリンク
3. XPath検索（ppv_id含む行内）
※汎用セレクタは誤データ取得リスクがあるため使用禁止
| public_dateエラー | 当日以降の日付に修正 |

## 出力

- `success`: 成功/失敗
- `saved_count`: 保存件数
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## 不変条件（Invariants）

**リファクタリング時に絶対に壊してはならない動作仕様。**

### I1. CSVはCMSからダウンロード
- 手動CSV作成禁止（28列フォーマットが必要）
- ダウンロードセレクタはppv_id含む行を優先（汎用セレクタは誤データ取得リスク）

### I2. public_date修正
- `0000-00-00`を当日日付に置換すること
- Python バイナリ置換を使用（Shift-JISエンコーディング対応）

### I3. CSVダウンロード自動リトライ
- 最大3回、指数バックオフ（2s→4s）
- 失敗時はページリロードしCSVリンクを再検索

### I4. ファイルアップロード方式
- `browser_file_upload`ではなく`page.locator().setInputFiles()`を使用
- ファイルダイアログが不要な直接セット方式

## 使用例

```
/step5

入力:
- site_id: 482
- csv_path: /path/to/izumo_482.csv
```

## トラブルシューティング

### フォーム送信が動作しない

**症状**: ファイル選択後、importボタンクリックしてもページが更新されない

**解決策**: `browser_evaluate` でJavaScriptの `form.submit()` を直接呼び出す

### プロキシ接続エラー

**症状**: タイムアウトまたは接続エラー

**解決策**: Squidプロキシ設定（.mcp.json）を確認し、リトライ

### 「0件保存しました」+ Undefined offsetエラー

**症状**: インポート完了するが0件、PHPのUndefined offsetエラーが表示される

**原因**: CSVのカラム数が不正（手動作成CSVの場合に発生）

**解決策**: 原稿管理CMSからCSVをダウンロードして使用する（28列フォーマット）

### public_dateエラー「公開日は過去の日付に変更はできません」

**症状**: インポート時にpublic_dateエラー

**原因**: CSVのpublic_dateが`0000-00-00`または過去日付

**解決策**:
```python
# Pythonでバイナリ置換（エンコーディング問題回避）
from datetime import datetime
today = datetime.now().strftime('%Y-%m-%d')
with open('input.csv', 'rb') as f:
    content = f.read()
content = content.replace(b'0000-00-00', today.encode('utf-8'))
with open('output.csv', 'wb') as f:
    f.write(content)
```

### browser_file_uploadエラー「can only be used when there is related modal state present」

**症状**: ファイルアップロード時にエラー

**原因**: ファイルダイアログが開いていない状態で`browser_file_upload`を実行

**解決策**: `browser_run_code`を使用
```javascript
async (page) => {
  await page.locator('#CsvInFile').setInputFiles('/path/to/file.csv');
}
```

### サイト選択ドロップダウンが反応しない

**症状**: `browser_select_option`でサイトを選択してもvalueが変わらない

**解決策**: `browser_evaluate`でJavaScript直接操作
```javascript
(() => {
  const select = document.querySelector('#SitePpvSiteId');
  select.value = '482';
  select.dispatchEvent(new Event('change', { bubbles: true }));
})();
```

## 完了確認（必須）

**STEP 5 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. インポート結果ページのスナップショットを取得
   browser_snapshot

2. 以下を確認:
   - 「X件保存しました」メッセージが表示
   - エラーメッセージがないこと
   - public_dateエラーがないこと
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| 保存メッセージ | 「X件保存しました」表示 | snapshot内を検索 |
| エラー | エラーメッセージなし | snapshot内を検索 |
| public_date | 日付エラーなし | snapshot内を検索 |

### 確認コード例

```javascript
// snapshotから確認
const hasSuccess = snapshot.includes('件保存しました');
const hasError = snapshot.includes('エラー') || snapshot.includes('過去の日付');
if (!hasSuccess || hasError) {
  throw new Error('STEP 5 確認失敗');
}
console.log('✅ STEP 5 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| 0件保存+エラー | CSVフォーマット不正 | CMSから再ダウンロード |
| public_dateエラー | 日付が0000-00-00 | 当日日付に置換 |
| タイムアウト | プロキシ経由で接続不可 | プロキシ設定を確認 |
| ログイン失敗 | 認証情報エラー | MKB_USER/MKB_PASSWORD確認 |

---

## 統一APIエンドポイント

STEP 5はセッション駆動の統一APIでも実行可能:

```
POST /api/step/5/execute
{
  "session_id": "xxx",
  "overrides": {"headless": false, "slow_mo": 100}
}
```

- STEP 4がSUCCESSでないと実行不可
- セッションのppv_id, menu_idを自動使用
- 既存API `/api/sales/register` も引き続き利用可能

---

## 依存関係

**STEP 5 は STEP 4 の完了後に実行すること。**
**STEP 5 の完了後に STEP 6 を実行すること。**

### 実行順序
```
STEP 4: メニュー設定（?p=cms_menu）
    ↓ （完了確認後）
STEP 5: 売上集計登録（MKB）← このスキル
    ↓ （完了確認後）
STEP 6: 原稿本番アップ（izumo同期）
```

### 順次実行の理由
- STEP 4 までで原稿管理CMSへの登録が完了
- STEP 5 でMKBに売上集計データを登録
- STEP 6 以降はizumo CMSでの作業

異なるシステムへのアクセスのため、理論上は並列実行可能だが、
データ整合性とエラー追跡のため順次実行を推奨。
