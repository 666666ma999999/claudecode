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
    inputs[20].value = '1';   // 表示フラグ (disp_flg)
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
| 20 | 表示フラグ | 1 |

```javascript
// fixedCode001 用
(() => {
  const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
  inputs[20].value = '1';  // 表示フラグ (disp_flg)
})();
```

### monthlyAffinity001 の場合

全項目を設定:

| input index | 項目 | 値 |
|--------|------|-----|
| 20 | 表示フラグ | 1 |
| 39 | どの画数を使うか | 2 |
| 93 | 蔵干の取得方法 | 1 |
| 94 | 日の切り替わり | 1 |
| 100 | 看法 | 1 |
| 101 | 辞書 | 1 |

```javascript
// monthlyAffinity001 用
(() => {
  const inputs = document.querySelectorAll('table tr:nth-child(2) td input');
  inputs[20].value = '1';   // 表示フラグ (disp_flg)
  inputs[39].value = '2';   // どの画数を使うか (kakusuId)
  inputs[93].value = '1';   // 蔵干の取得方法 (zoukan)
  inputs[94].value = '1';   // 日の切り替わり (is24Border)
  inputs[100].value = '1';  // 看法 (kanpou)
  inputs[101].value = '1';  // 辞書 (dict)
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

### カラムインデックスずれ（2026-02修正済み）

**症状**:
- 画数・蔵干・日の切り替わりが隣のカラムに入力される

**原因**:
- td column 0 (menu_id) には `input[type="text"]` も `input:not([type])` もない（hidden inputか別要素）
- そのため行あたりのinput数は138（rowSize=139は誤り）
- 全フィールドのinput indexがtd columnより1つ小さい（input index = td index - 1）

**修正内容**:
- rowSize: 139 → 138
- COL_DISPLAY_FLAG: 21 → 20, COL_KAKUSU: 40 → 39, COL_ZOUKAN: 94 → 93
- COL_DAY_CHANGE: 95 → 94, COL_KANPOU: 101 → 100, COL_JISHO: 102 → 101
- 旧コードで誤入力された隣接フィールド（partner_flg[21], searchNumber[40], relation[95], transitPillar[102]）を自動クリアする機能を追加
- メニュータイプ判定を明示的に（fixedCode / monthlyAffinity|boinGyoun）に分離し、未知のプレフィックスには触れないよう変更

**教訓**:
- CMSフォーム構造が変更される可能性があるため、カラムインデックスは**実際のCMSページで `document.querySelectorAll('input[type="text"], input:not([type])').length` を実行して検証**すること
- name属性で確認: `input.name` が期待するフィールド名と一致するか検証する

### 数値フィールドが入力されない（2026-02修正済み）

**症状**:
- STEP 4実行後、表示フラグ・画数・蔵干などの数値フィールドが空のまま
- ログには「X行を更新」と出るがupdatedFields=0

**原因**:
- 旧実装はCMSの`rowInputs[0].value`（menu_id入力欄）の値でプレフィックスを判定していた
- しかしCMS上のmenu_id欄には`001.045`のような短縮形しか表示されず、フルプレフィックス（`monthlyAffinity001`等）は含まれない
- 結果、プレフィックス判定が常にfalseとなり、全行がスキップされていた

**修正内容（v1.42.3）**:
- menu_idは`<td>`内のテキスト + `<input name="menu_id" type="hidden">`で構成されている
- `querySelectorAll('input[type="text"]')`ではhidden inputにマッチしないため、別途取得が必要
- 修正: `document.querySelectorAll('input[name="menu_id"][type="hidden"]')`で全行のmenu_idを取得
- `menuIdInputs[i].value`（例: "fixedCode001.287"）でプレフィックスを判定
- 保存後の検証ロジックも同様に修正済み
- 注意: 旧v1.36.7の`menu_prefix` API経由方式はリファクタリングで消失していた

**確認方法**:
```
ログに以下が出力されることを確認：
- "数字フィールド入力: menu_prefix=monthlyAffinity001"
- "数字フィールド入力完了: X行, Y フィールドを更新, プレフィックス=monthlyAffinity001"
- updatedFieldsが0でないこと
```

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

## 不変条件（Invariants）

**リファクタリング時に絶対に壊してはならない動作仕様。コード変更後は必ず以下を検証すること。**

### I1. menu_id検出はhidden inputから
- `input[name="menu_id"][type="hidden"]` でmenu_idを取得すること
- `input[type="text"]` にはmenu_idは含まれない（hidden inputはマッチしない）
- 旧方式の`menu_prefix` API経由は廃止済み（v1.36.7で消失）
- **テスト**: `document.querySelectorAll('input[name="menu_id"][type="hidden"]')` が全行分返ること

### I2. rowSize = 138
- 各行のtext input数は138（td column 0にはtext inputがないため）
- input index = td column index - 1
- **絶対に139にしないこと**（過去にこの誤りで全フィールドが1つずれた）

### I3. フィールドインデックス
- disp_flg: input[20] (td[21])
- kakusuId: input[39] (td[40])
- zoukan: input[93] (td[94])
- is24Border: input[94] (td[95])
- kanpou: input[100] (td[101])
- dict: input[101] (td[102])
- **変更時は必ずCMS実ページで `input.name` を検証すること**

### I4. プレフィックス別設定パターン
- `fixedCode001`: disp_flg のみ設定（他は触らない）
- `monthlyAffinity001` / `boinGyoun*`: 全6フィールドを設定
- 未知のプレフィックス: 触らない（安全側に倒す）

### I5. 残留フィールドクリア
- 旧+1オフセットで誤入力された可能性のあるフィールドを自動クリア:
  - partner_flg[21], searchNumber[40], relation[95], transitPillar[102]
- これらのクリア処理を削除しないこと

### I6. 保存後検証
- 保存後にページリロード→全行のフィールド値を検証
- menu_idのhidden inputからプレフィックスを再判定し、期待値と比較
- 検証NGでもresult.successは変更しない（警告のみ）

### I7. STEP 3依存
- STEP 3未完了時は`{status: error}`が返る
- STEP 4単独では保存不可

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
   - inputs[20] = 1（表示フラグ）
   - monthlyAffinityの場合: inputs[39] = 2, inputs[93] = 1 等
   - 保存結果が `{status: error}` でないこと
```

### 確認項目

| 項目 | input index | 成功条件 | 確認方法 |
|------|:-----------:|----------|----------|
| 表示フラグ | 20 | `"1"` | browser_evaluate |
| 画数設定 | 39 | monthlyAffinity: `"2"` | browser_evaluate |
| 蔵干取得 | 93 | monthlyAffinity: `"1"` | browser_evaluate |
| 日切り替わり | 94 | monthlyAffinity: `"1"` | browser_evaluate |
| 看法 | 100 | monthlyAffinity: `"1"` | browser_evaluate |
| 辞書 | 101 | monthlyAffinity: `"1"` | browser_evaluate |
| partner_flg | 21 | `""` or `"0"`（残留クリア済み） | browser_evaluate |
| searchNumber | 40 | `""`（残留クリア済み） | browser_evaluate |
| relation | 95 | `""`（残留クリア済み） | browser_evaluate |
| transitPillar | 102 | `""`（残留クリア済み） | browser_evaluate |
| 保存結果 | - | error でない | コンソールログ確認 |

**注意**: `browser_automation.py` の保存後検証は上記全項目を全行で自動チェックします。API実行時はログに `保存検証OK` / `保存検証NG` が出力されます。

### 確認コード例

```javascript
// browser_evaluate で全行確認
const inputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'));
const rowSize = 138;
const totalRows = Math.floor(inputs.length / rowSize);
const errors = [];
for (let i = 0; i < totalRows; i++) {
  const s = i * rowSize;
  const v = (idx) => inputs[s + idx]?.value;
  if (v(20) !== '1') errors.push({row:i, f:'disp_flg', v:v(20)});
  if (v(39) !== '2') errors.push({row:i, f:'kakusuId', v:v(39)});
  if (v(93) !== '1') errors.push({row:i, f:'zoukan', v:v(93)});
  if (v(94) !== '1') errors.push({row:i, f:'is24Border', v:v(94)});
  if (v(100) !== '1') errors.push({row:i, f:'kanpou', v:v(100)});
  if (v(101) !== '1') errors.push({row:i, f:'dict', v:v(101)});
  // 残留フィールド
  if (v(21) && v(21) !== '' && v(21) !== '0') errors.push({row:i, f:'partner_flg', v:v(21)});
  if (v(40) && v(40) !== '') errors.push({row:i, f:'searchNumber', v:v(40)});
  if (v(95) && v(95) !== '') errors.push({row:i, f:'relation', v:v(95)});
  if (v(102) && v(102) !== '') errors.push({row:i, f:'transitPillar', v:v(102)});
}
console.log('STEP 4 検証:', {totalRows, errorCount: errors.length, errors});
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| `{status: error}` | STEP 3 未完了 | STEP 3 を先に実行 |
| 値がリセット | 保存失敗 | STEP 3 完了確認後に再実行 |
| 表示フラグ=0 | 保存未実行 | 「従量登録」を再クリック |

### 不具合ログ（issues）

API実行時、レスポンスに `issues` フィールドが含まれる。セッションJSONの `step_transactions[].issues` にも記録される。

| type | severity | 意味 |
|------|----------|------|
| RESIDUAL_CLEAR | info | 旧+1オフセットで誤入力された残留フィールドをクリア |
| SANITIZE | warn | 半角ダブルクォートを全角に変換（CMS SQL防止） |
| VERIFY_FAIL | error | 保存後検証でフィールド値が期待と不一致 |

`/verify-step 4` 実行時にissuesサマリーが出力される。

---

## mid_id事前検証（v1.39.0追加）

STEP4実行前に、STEP2で登録されたmid_idがユーザー入力のcommon_mid_idと一致するか検証できる。

### 検証API

```
GET /api/step/4/validate-mid-id?session_id=xxx

レスポンス:
{
  "success": true,
  "valid": true/false,
  "expectedMidId": "293",
  "mismatches": [
    {"order": 2, "title": "甘い記憶が...", "expected": "293", "actual": "1"}
  ],
  "message": "OK" or "X件のmid_id不一致を検出"
}
```

### 動作仕様
- `common_mid_id`が未設定（per-subtitleモード）の場合は検証スキップ（`valid: true, skipped: true`）
- 冒頭・締め（`is_opening_closing=true`または`mid_id=1026`）はスキップ
- 先頭ゼロを正規化して比較（`"001"` == `"1"`）
- フロントエンドで不一致時に警告モーダルを表示（キャンセルまたは強制続行可能）

### フロントエンド設定
- `API_ENDPOINTS.validateMidIdForStep4(sessionId)` で呼び出し
- `executeRegistration()`内のSTEP4実行前と`retryStep4()`の両方で検証が走る

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
