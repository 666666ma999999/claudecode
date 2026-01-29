---
name: step3-ppv-info
description: |
  STEP 3: PPV情報登録（従量登録）
  原稿管理CMSでPPV詳細情報（価格、誘導設定等）を登録する。
  Playwright MCPを使用してブラウザ操作を自動化。
  キーワード: STEP3, PPV情報, 従量登録, 価格設定, Playwright MCP
---

# STEP 3: PPV情報登録（従量登録）

## 概要

原稿管理CMSのPPV詳細ページ（?p=cms_ppv）で、価格・誘導情報・カテゴリ等を設定する。

## 対象システム

- **URL**: `https://hayatomo2-dev.ura9.com/manuscript/?p=cms_ppv`
- **認証**: フォームログイン（STEP 2で済んでいれば不要）
- **認証情報**: 環境変数 `MANUSCRIPT_CMS_USER`, `MANUSCRIPT_CMS_PASSWORD`

## 前提条件

1. STEP 2 が完了していること
2. 以下の入力データが必要:
   - `site_id`: サイトID
   - `ppv_id`: PPV ID
   - `menu_id`: menu_id（STEP 2で発行）
   - `price`: 価格（デフォルト: 2000）
   - `guide`: 商品紹介文
   - `affinity`: 0=1人用, 1=2人用
   - `ppv_icon_id`: カテゴリコード

## 実行フロー

### 1. PPV詳細ページへ移動

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id}&save_id={menu_id}

1. browser_navigate → PPV詳細ページ
2. browser_snapshot → フォーム要素確認
```

### 2. フィールド入力（JavaScript一括入力推奨）

138個のinputフィールドがあるため、`browser_evaluate` でJavaScript一括入力が効率的。

```javascript
// browser_evaluate で実行
(() => {
  // 価格
  document.querySelector('input[name="price"]').value = '2000';

  // 誘導01
  document.querySelector('input[name="yudo_ppv_id_01"]').value = 'ppv002';
  document.querySelector('input[name="yudo_menu_id_01"]').value = 'boinGyounAffinity001.003';

  // 誘導02
  document.querySelector('input[name="yudo_ppv_id_02"]').value = 'ppv005';
  document.querySelector('input[name="yudo_menu_id_02"]').value = 'boinGyoun001.027';

  // 商品紹介文
  document.querySelector('textarea[name="guide"]').value = '{guide_text}';

  // affinity
  document.querySelector('select[name="affinity"]').value = '{affinity}';

  // カテゴリ
  document.querySelector('input[name="ppv_icon_id"]').value = '{ppv_icon_id}';
})();
```

### 3. 保存実行

```
1. browser_click (ref: "保存") → 保存実行
2. browser_wait_for (text: "保存しました") → 完了確認
3. browser_take_screenshot → 結果スクリーンショット
```

## 主要フィールド

### 基本情報

| フィールド | name属性 | 説明 | デフォルト |
|-----------|----------|------|-----------|
| 価格 | `price` | 商品価格 | 2000 |
| 紹介文 | `guide` | 商品紹介文（auto_generated.guide_text から取得） | - |
| affinity | `affinity` | 0=1人用, 1=2人用 | 0 |
| カテゴリ | `ppv_icon_id` | カテゴリコード（auto_generated.category_code） | - |

### キャリア固定値（必須）

| フィールド | name属性 | 固定値 |
|-----------|----------|--------|
| dメニューSID | `dmenu_sid` | `00073734509` |
| au PCコード | `spau_pc_code` | `10503` |
| SoftBank SID | `spsb_sid` | `WZNV67ABGX5UJU4H5V` |

### 誘導設定

| フィールド | name属性 | 説明 | デフォルト |
|-----------|----------|------|-----------|
| 誘導PPV01 | `yudo_ppv_id_01` | 誘導先PPV ID | ppv002 |
| 誘導メニュー01 | `yudo_menu_id_01` | 誘導先menu_id | boinGyounAffinity001.003 |
| 誘導PPV02 | `yudo_ppv_id_02` | 誘導先PPV ID | ppv005 |
| 誘導メニュー02 | `yudo_menu_id_02` | 誘導先menu_id | boinGyoun001.027 |
| 誘導テキスト | `yudo_txt` | 誘導表示テキスト | - |

### その他設定

| フィールド | name属性 | 説明 | デフォルト |
|-----------|----------|------|-----------|
| サイトコード | `site_code` | サイト識別子 | `izumo` |
| ビューID | `view_id` | 表示形式 | `composite` |
| 公開日 | `public_date` | YYYY-MM-DD形式 | 当日 |
| 固定フラグ | `const_flg` | 固定表示 | `1` |

## 出力

- `success`: 成功/失敗
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| セッション切れ | 再ログイン後リトライ |
| フィールドが見つからない | snapshot確認、代替セレクタ試行 |
| 保存エラー | エラーメッセージ取得、スクリーンショット |

## 使用例

```
/step3

入力:
- site_id: 482
- ppv_id: 10001
- menu_id: monthlyAffinity001.001
- price: 2000
- guide: "彼の本当の気持ちを占います..."
- affinity: 0
- ppv_icon_id: 101
```

## 完了確認（必須）

**STEP 3 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. PPV詳細ページにアクセス
   URL: ?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id}

2. browser_snapshot で各フィールド値を取得

3. 以下を確認:
   - price = 設定値（例: 2000）
   - guide = 商品紹介文が入力済み
   - affinity = 0 or 1
   - dmenu_sid = 00073734509（キャリア固定値）
   - yudo_ppv_id_01, yudo_menu_id_01 = 誘導設定が入力済み
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| price | 設定値と一致 | input[name="price"].value |
| guide | 空でない | textarea[name="guide"].value |
| affinity | 0 or 1 | select[name="affinity"].value |
| dmenu_sid | `00073734509` | input[name="dmenu_sid"].value |
| 誘導01 | 設定済み | yudo_ppv_id_01, yudo_menu_id_01 |

### 確認コード例

```javascript
// browser_evaluate で確認
const checks = {
  price: document.querySelector('input[name="price"]').value,
  guide: document.querySelector('textarea[name="guide"]').value,
  dmenu_sid: document.querySelector('input[name="dmenu_sid"]').value,
};
console.log('STEP 3 確認:', checks);
if (!checks.price || !checks.dmenu_sid) {
  throw new Error('STEP 3 確認失敗');
}
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| 値が空 | 保存未実行 | 「保存」ボタンを再クリック |
| キャリア固定値が空 | 入力漏れ | 固定値を入力して再保存 |
| 保存でエラー | バリデーションエラー | エラーメッセージを確認 |

---

## 依存関係

**STEP 3 は STEP 2 の完了後に実行すること。**
**STEP 3 の完了後に STEP 4 を実行すること（並列実行禁止）。**

### 実行順序
```
STEP 2: メニュー登録（menu_id発行）
    ↓ （完了確認後）
STEP 3: PPV情報登録（?p=cms_ppv）← このスキル
    ↓ （完了確認後）
STEP 4: メニュー設定（?p=cms_menu）
```

### 並列実行禁止の理由
- STEP 3 と STEP 4 は同じセッション・同じCMSを使用
- 並列実行するとセッション競合やデータ不整合が発生
- 必ず順次実行すること

## ⚠️ STEP 4 への影響

**重要: STEP 3 が未完了だと、STEP 4 の保存処理が失敗します。**

| STEP 3 の状態 | STEP 4 の動作 |
|--------------|--------------|
| 登録済み | 正常に保存可能 |
| **未登録** | **保存API が `{status: error}` を返す** |

### STEP 3 完了の確認方法

```
1. ?p=cms_ppv&site_id={site_id}&ppv_id={ppv_id} にアクセス
2. ステータスが「登録済み」であることを確認
3. 「保存しました」メッセージが表示されていること
```

### STEP 3 をスキップした場合のエラー

STEP 4 実行時に以下の症状が発生：
- 数字の入力は成功するが、保存ボタンでエラー
- `{status: error, datas: Array(0)}` がコンソールに表示
- ページ再読み込みで入力値がリセット

**解決方法**: STEP 3 に戻って PPV 情報を登録してから STEP 4 を再実行
