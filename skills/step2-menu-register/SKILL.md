---
name: step2-menu-register
description: |
  STEP 2: メニュー登録（原稿管理CMS）
  原稿管理CMSにログインし、新規原稿を登録する。
  Playwright MCPを使用してブラウザ操作を自動化。
  キーワード: STEP2, メニュー登録, 原稿管理, CMS, Playwright MCP
---

# STEP 2: メニュー登録

## 概要

原稿管理CMS（hayatomo2-dev.ura9.com）にログインし、商品原稿を登録する。

## 対象システム

- **URL**: `https://hayatomo2-dev.ura9.com/manuscript/`
- **認証**: フォームログイン
- **認証情報**: 環境変数 `MANUSCRIPT_CMS_USER`, `MANUSCRIPT_CMS_PASSWORD`

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
2. 以下の入力データが必要:
   - `site_id`: サイトID
   - `ppv_id`: PPV ID
   - `ppv_title`: 商品タイトル
   - `subtitles`: 小見出しリスト（タイトル、本文、mid_id）

## 実行フロー

### 1. ログイン

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=login

1. browser_navigate → ログインページ
2. browser_snapshot → フォーム要素確認
3. browser_type (ref: ユーザーID入力欄) → ユーザーID入力
4. browser_type (ref: パスワード入力欄) → パスワード入力
5. browser_click (ref: ログインボタン) → ログイン実行
6. browser_wait_for (text: "サイト選択") → ログイン完了確認
```

### 2. サイト選択・新規原稿作成

```
URL: https://hayatomo2-dev.ura9.com/manuscript/?p=site&site_id={site_id}

1. browser_navigate → サイトページ
2. browser_snapshot → メニュー確認
3. browser_click (ref: "新規原稿作成") → 新規作成画面へ
```

### 3. 原稿情報入力

```
URL: ?p=save&site_id={site_id}

1. browser_snapshot → 入力フォーム確認
2. browser_type (ref: PPV ID入力欄) → PPV ID入力
3. browser_type (ref: タイトル入力欄) → 商品タイトル入力
4. browser_select_option (ref: 原稿タイプ) → "ppv" 選択
```

### 4. 小見出し登録（ループ）

各小見出しについて:

```
1. browser_click (ref: "小見出し追加") → 小見出し追加
2. browser_type (ref: 小見出しタイトル) → タイトル入力
3. browser_select_option (ref: mid_id) → mid_id選択
4. browser_type (ref: 本文) → 原稿本文入力
5. browser_click (ref: "保存") → 保存
```

### 5. 原稿アップロード

```
1. browser_click (ref: "チェック") → 原稿チェック
2. browser_wait_for (text: "原稿チェック完了") → チェック完了
3. browser_click (ref: "原稿UP") → 原稿アップロード
4. browser_wait_for (text: "アップロード完了") → 完了確認
```

## セレクタ参照

### ログインページ

| 要素 | role/セレクタ | 説明 |
|------|--------------|------|
| ユーザーID | `textbox[name="user-id"]` | ユーザーID入力欄 |
| パスワード | `textbox[name="password"]` | パスワード入力欄 |
| ログインボタン | `button "Click to Login"` | ログイン実行 |

### 原稿登録ページ

| 要素 | role/セレクタ | 説明 |
|------|--------------|------|
| PPV ID | `input[name="target_ppv_id"]` | PPV ID入力 |
| 小見出しタイトル | `input[name="title"]` | 小見出しタイトル |
| mid_id | `select[name="mid_id"]` | mid_id選択 |
| 本文 | `textarea[name="body"]` | 原稿本文 |
| 保存ボタン | `button "保存"` | 保存実行 |
| チェックボタン | `button "チェック"` | 原稿チェック |
| 原稿UPボタン | `button "原稿UP"` | アップロード実行 |

## 出力

- `ppv_id`: 登録されたPPV ID
- `menu_id`: 発行されたmenu_id
- `success`: 成功/失敗
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| ログイン失敗 | 認証情報確認を促す |
| タイムアウト | スクリーンショット取得、リトライ |
| 要素が見つからない | snapshot再取得、代替セレクタ試行 |

## 使用例

```
/step2

入力:
- site_id: 482
- ppv_id: 10001
- ppv_title: 【恋愛占い】彼の本音
- subtitles: [...]
```

## 完了確認（必須）

**STEP 2 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. UP済み一覧にアクセス
   URL: https://hayatomo2-dev.ura9.com/manuscript/?p=up&site_id={site_id}

2. browser_snapshot で一覧を取得

3. 以下を確認:
   - ppv_id が一覧に表示されている
   - ステータスが「登録済み」または「UP済み」
   - 小見出し数が期待値と一致
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| ppv_id表示 | 一覧にppv_idが存在 | snapshot内を検索 |
| ステータス | 「登録済み」「UP済み」 | 該当行のステータス列 |
| 小見出し数 | 期待値と一致 | 詳細画面で確認 |

### 確認コード例

```javascript
// snapshotから確認
const rows = snapshot.match(/48200038.*?(登録済み|UP済み)/);
if (!rows) {
  throw new Error('STEP 2 確認失敗: ppv_idが一覧に見つかりません');
}
console.log('✅ STEP 2 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| ppv_id未表示 | 登録未完了 | STEP 2を再実行 |
| ステータスが「未登録」 | 原稿UPが未実行 | 「原稿UP」ボタンをクリック |
| 小見出し数不一致 | 入力漏れ | 詳細画面で追加登録 |

---

## 依存関係

**STEP 2 は STEP 1 の完了後に実行すること。**
**STEP 2 の完了後に STEP 3 を実行すること。**

### 実行順序
```
STEP 1: 原稿生成・PPV ID発行
    ↓ （完了確認後）
STEP 2: メニュー登録（原稿管理CMS）← このスキル
    ↓ （完了確認後）
STEP 3: PPV情報登録（?p=cms_ppv）
```

### STEP 1からの受け取りデータ
- `ppv_id`: STEP 1で発行されたPPV ID
- `menu_id`: STEP 1で発行されたmenu_id
- `subtitles`: STEP 1で生成された原稿

### STEP 3への引き渡しデータ
- `menu_id`: 登録確定したmenu_id（STEP 3以降で使用）
- セッションは維持されるため、同じブラウザでSTEP 3に進む
