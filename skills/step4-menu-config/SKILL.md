---
name: step4-menu-config
description: |
  STEP 4: メニュー設定（従量管理詳細）
  原稿管理CMSでメニュー詳細設定（表示フラグ、画数設定等）を登録する。
  Playwright MCPを使用してブラウザ操作を自動化。
  キーワード: STEP4, メニュー設定, 従量管理詳細, 画数設定, Playwright MCP
---

# STEP 4: メニュー設定（従量管理詳細）

## 概要

原稿管理CMSのメニュー設定ページ（?p=cms_menu）で、表示フラグ・画数・蔵干等の詳細設定を行う。

## 対象システム

- **URL**: `https://hayatomo2-dev.ura9.com/manuscript/?p=cms_menu`
- **認証**: フォームログイン（STEP 2で済んでいれば不要）
- **認証情報**: 環境変数 `MANUSCRIPT_CMS_USER`, `MANUSCRIPT_CMS_PASSWORD`

## 前提条件

**⚠️ 重要: STEP 3 が完了していないと、STEP 4 の保存処理が失敗します。**

1. **STEP 3（PPV情報登録）が「登録済み」状態であること**（必須）
   - cms_ppvページのステータスが「登録済み」であることを確認
   - 「未登録」状態だとcms_menuの保存APIがエラーを返す
2. STEP 2 が完了していること
3. 以下の入力データが必要:
   - `site_id`: サイトID
   - `ppv_id`: PPV ID
   - `menu_id`: menu_id（STEP 2で発行）

### 前提条件の確認方法

```
1. ?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id} にアクセス
2. ステータスが「登録済み」であることを確認
3. 「未登録」の場合は STEP 3 を先に実行
```

## 実行フロー

### 1. メニュー設定ページへ移動

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=cms_menu&site_id={site_id}&ppv_id={ppv_id}&save_id={menu_id}

1. browser_navigate → メニュー設定ページ
2. browser_snapshot → テーブル要素確認
```

### 2. 設定値入力（JavaScript一括入力）

テーブル形式のため、`browser_evaluate` または `browser_run_code` でJavaScript一括入力が効率的。

**注意**: menu_idのプレフィックスによって設定項目が異なる（詳細は「menu_idプレフィックス別の設定パターン」参照）

```javascript
// browser_run_code で実行（monthlyAffinity001の場合）
async (page) => {
  await page.evaluate(() => {
    const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
    inputs[20].value = '1';   // 表示フラグ (disp_flg)
    inputs[39].value = '2';   // どの画数を使うか (kakusuId)
    inputs[93].value = '1';   // 蔵干の取得方法 (zoukan)
    inputs[94].value = '1';   // 日の切り替わり (is24Border)
    inputs[100].value = '1';  // 看法 (kanpou)
    inputs[101].value = '1';  // 辞書 (dict)
  });
}
```

```javascript
// browser_run_code で実行（fixedCode001の場合）
async (page) => {
  await page.evaluate(() => {
    const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
    inputs[21].value = '1';   // 表示フラグ (disp_flg)
  });
}
```

### 3. 従量登録実行

```
1. browser_click (ref: "従量登録") → 登録実行
2. browser_wait_for (text: "登録完了") → 完了確認
3. browser_take_screenshot → 結果スクリーンショット
```

## 主要設定項目

| td index | input index | 設定項目 | name属性 | 説明 |
|----------|-------------|----------|----------|------|
| 21 | 20 | 表示フラグ | disp_flg | 表示/非表示 |
| 40 | 39 | 画数設定 | kakusuId | どの画数を使うか |
| 94 | 93 | 蔵干取得方法 | zoukan | 蔵干の計算方式 |
| 95 | 94 | 日切り替わり | is24Border | 日の切り替わり時刻 |
| 101 | 100 | 看法 | kanpou | 看法設定 |
| 102 | 101 | 辞書 | dict | 辞書設定 |

> **注意**: td column 0 (menu_id) にtext inputがないため、input index = td index - 1。各行のinput数は138個。

## menu_idプレフィックス別の設定パターン

**重要**: menu_idのプレフィックスによって設定する項目が異なる。

### fixedCode001 の場合

表示フラグのみ設定:

| input index | 項目 | 値 |
|--------|------|-----|
| 21 | 表示フラグ | 1 |

```javascript
// fixedCode001 用
(() => {
  const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
  inputs[21].value = '1';  // 表示フラグ (disp_flg)
})();
```

### monthlyAffinity001 の場合

全項目を設定:

| input index | 項目 | 値 |
|--------|------|-----|
| 21 | 表示フラグ | 1 |
| 40 | どの画数を使うか | 2 |
| 94 | 蔵干の取得方法 | 1 |
| 95 | 日の切り替わり | 1 |
| 101 | 看法 | 1 |
| 102 | 辞書 | 1 |

```javascript
// monthlyAffinity001 用
(() => {
  const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
  inputs[21].value = '1';   // 表示フラグ (disp_flg)
  inputs[40].value = '2';   // どの画数を使うか (kakusuId)
  inputs[94].value = '1';   // 蔵干の取得方法 (zoukan)
  inputs[95].value = '1';   // 日の切り替わり (is24Border)
  inputs[101].value = '1';  // 看法 (kanpou)
  inputs[102].value = '1';  // 辞書 (dict)
})();
```

### プレフィックス判定ロジック

```javascript
function getSettingPattern(menuId) {
  if (menuId.startsWith('fixedCode')) {
    return 'fixedCode';  // 表示フラグのみ
  } else if (menuId.startsWith('monthlyAffinity')) {
    return 'monthlyAffinity';  // 全項目設定
  }
  // デフォルトは全項目設定
  return 'monthlyAffinity';
}
```

## フォールバック

`?p=cms_menu` が存在しない場合:
- 自動的に `?p=text&f=menu` へリダイレクトされる
- 同等の設定が可能

## 出力

- `success`: 成功/失敗
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| ページ不存在 | ?p=text&f=menu へフォールバック |
| セッション切れ | 再ログイン後リトライ |
| 要素が見つからない | snapshot確認、代替セレクタ試行 |
| **`{status: error}` 保存失敗** | **STEP 3 が未完了。STEP 3 を先に実行** |

## トラブルシューティング

### 保存ボタンクリック時に `{status: error}` が返る

**症状**:
- 数字の入力自体は成功する（JavaScriptで値が設定される）
- 「保存する」ボタンクリック後、コンソールに `{status: error, datas: Array(0)}` が表示
- ページ再読み込みすると入力した値が消える

**原因**:
- STEP 3（PPV情報登録）が未完了
- cms_ppvページのステータスが「未登録」状態

**解決方法**:
```
1. ?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id} にアクセス
2. ステータスを確認（「未登録」なら STEP 3 が必要）
3. STEP 3 を実行して PPV 情報を登録
4. cms_ppv のステータスが「登録済み」になったことを確認
5. STEP 4 を再実行
```

### "保存する" が status:error を返すが値は保存済み

**症状**:
- 「保存する」ボタンクリック後、`{status: error}` が返る
- しかしページリロード後にデータが保存されている

**原因**:
- UPDATE で affected_rows=0 の場合もCMSがerrorを返す仕様
- データが既に同じ値の場合、UPDATEでも変更なしとみなされる

**解決方法**:
```
1. status:error でも即座にエラー扱いしない
2. ページリロード後に各input値を確認
3. 値が保持されていれば成功とみなす
```

### カラムインデックスずれ（2025-01修正済み）

**症状**:
- 画数・蔵干・日の切り替わりが隣のカラムに入力される

**原因**:
- コードのコメントに「menu_idはselect要素のためinput配列に含まれず-1オフセット」と記載されていたが、実際にはtd index = input indexで一致していた
- rowSizeも138ではなく139が正しい

**教訓**:
- CMSフォーム構造が変更される可能性があるため、カラムインデックスは**実際のCMSページで `document.querySelectorAll('tr')[1].querySelectorAll('input')` を実行して検証**すること
- 想定やコメントを鵜呑みにしない

### タイトルの半角ダブルクォート問題

**症状**:
- lecture_name や title に半角`"`が含まれると保存エラー
- SQL UPDATE文が失敗する

**原因**:
- CMS内部のSQL文で半角`"`がエスケープされず構文エラーになる

**解決方法**:
```javascript
// 保存前にすべてのinputから半角ダブルクォートを除去
const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
inputs.forEach(input => {
  if (input.value) {
    input.value = input.value.replace(/"/g, '"');  // 半角→全角変換
    // または
    input.value = input.value.replace(/"/g, '');   // 除去
  }
});
```

### 「従量登録」ボタンクリック後に「未登録」と表示される

**症状**:
- cms_menu ページで「従量登録」ボタンをクリック
- cms_ppv ページに遷移し、ステータスが「未登録」と表示

**原因**:
- STEP 3 をスキップした、または失敗している
- cms_menuの「従量登録」処理がcms_ppvのデータを初期化する仕様

**解決方法**:
- STEP 3 から再実行する

**自動再保存（2026-01実装済み）**:
- `browser_automation.py` に自動re-save機能を実装済み
- 従量登録後にcms_ppvへリダイレクトされた場合、セッションJSONのdistributionデータを使ってPPV情報を自動再入力・保存
- `session_id`がCMSMenuRegistrationに渡されていれば自動で動作する

## 使用例

```
/step4

入力:
- site_id: 482
- ppv_id: 10001
- menu_id: monthlyAffinity001.001
```

## 完了確認（必須）

**STEP 4 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. メニュー設定ページにアクセス
   URL: ?p=cms_menu&site_id={site_id}&ppv_id={ppv_id}

2. browser_snapshot でテーブル値を取得

3. 以下を確認:
   - inputs[21] = 1（表示フラグ）
   - monthlyAffinityの場合: inputs[40] = 2, inputs[94] = 1 等
   - 保存結果が `{status: error}` でないこと
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| 表示フラグ | inputs[21] = 1 | browser_evaluate |
| 画数設定 | monthlyAffinity: 2 | browser_evaluate |
| 蔵干取得 | monthlyAffinity: 1 | browser_evaluate |
| 保存結果 | error でない | コンソールログ確認 |

### 確認コード例

```javascript
// browser_evaluate で確認
const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
const checks = {
  displayFlag: inputs[21]?.value,
  strokeCount: inputs[40]?.value,
  zokkan: inputs[94]?.value,
};
console.log('STEP 4 確認:', checks);
if (checks.displayFlag !== '1') {
  throw new Error('STEP 4 確認失敗: 表示フラグが未設定');
}
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| `{status: error}` | STEP 3 未完了 | STEP 3 を先に実行 |
| 値がリセット | 保存失敗 | STEP 3 完了確認後に再実行 |
| 表示フラグ=0 | 保存未実行 | 「従量登録」を再クリック |

---

## 統一APIエンドポイント

STEP 4はセッション駆動の統一APIでも実行可能:

```
POST /api/step/4/execute
{
  "session_id": "xxx",
  "overrides": {"headless": true, "slow_mo": 0}  // 任意
}

レスポンス (StepExecuteResponse - camelCase):
{
  "success": true,
  "sessionId": "xxx",
  "step": 4,
  "result": {"updatedRows": 3, "verification": {...}}
}
```

- STEP 3がSUCCESSでないと実行不可（ガード条件）
- 失敗時はSTEP 3へのロールバック情報を含む
- ループ検出（S3→S4→S3）によるPAUSE機能あり
- 既存API `/api/cms-menu/register` も引き続き利用可能

## 依存関係

**STEP 4 は必ず STEP 3 の完了後に実行すること。**

- STEP 3（?p=cms_ppv）: 価格、誘導、カテゴリ等の商品情報
- STEP 4（?p=cms_menu）: 表示フラグ、画数、蔵干等の技術設定

※ STEP 3 と STEP 4 は**異なるページ**を使用する。並列実行禁止。

## 実行順序の保証

register-allスキルで連続実行する場合：
1. STEP 3 の完了を確認（browser_wait_for で "保存しました" 等）
2. その後に STEP 4 を開始
3. 並列実行は厳禁（データ整合性の問題が発生する）
