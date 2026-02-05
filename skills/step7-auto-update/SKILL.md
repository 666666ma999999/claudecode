---
name: step7-auto-update
description: |
  STEP 7: 従量自動更新（izumo-dev CMS）
  izumo CMSで従量コンテンツの自動更新を実行する。
  Playwright MCPを使用してブラウザ操作を自動化。
  ※Basic認証はURLに埋め込んで対応
  キーワード: STEP7, 従量自動更新, izumo, 自動更新, Basic認証, Playwright MCP
---

# STEP 7: 従量自動更新（izumo-dev CMS）

## 概要

izumo CMS（izumo-dev.uranai-gogo.com）で従量コンテンツの自動更新を実行する。

## 対象システム

- **URL**: `https://izumo-dev.uranai-gogo.com/admin/`
- **認証**: Basic認証
- **認証情報**: 環境変数 `IZUMO_USER`, `IZUMO_PASSWORD`

## Basic認証の対応方法

URLに認証情報を埋め込んでアクセス:

```
https://{IZUMO_USER}:{IZUMO_PASSWORD}@izumo-dev.uranai-gogo.com/admin/
```

## 前提条件

1. Playwright MCP (`mcp__playwright-mkb__*`) が有効
2. STEP 1-6 が完了していること
3. 認証情報が環境変数に設定済み

## 実行フロー

### 1. 管理画面にアクセス

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/

1. browser_navigate → Basic認証付きURL
2. browser_snapshot → 管理画面確認
```

### 2. 自動更新設定画面へ移動

```
1. browser_click (ref: "従量管理" メニュー) → 従量管理画面へ
2. browser_snapshot → 自動更新設定確認
```

### 3. 自動更新実行

```
1. browser_click (ref: "自動更新" ボタン) → 更新実行
2. browser_wait_for (text: "更新完了") → 完了確認
3. browser_take_screenshot → 結果スクリーンショット
```

### 4. 更新結果確認

```
1. browser_snapshot → 更新結果一覧
2. 更新されたmenu_idリストを取得
```

## セレクタ参照

### 管理画面

| 要素 | セレクタ/テキスト | 説明 |
|------|------------------|------|
| 従量管理メニュー | `link "従量管理"` | 従量管理画面へ |
| 自動更新ボタン | `button "自動更新"` | 更新実行 |
| 更新結果テーブル | `table.update-result` | 結果一覧 |

## 従量自動更新登録フォーム

### 登録ページ

```
URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/ppv_automation_opener_edit.html
```

### フォームフィールド

| フィールド | セレクタ | 入力例 | 説明 |
|-----------|---------|--------|------|
| PPV_ID | `select` (combobox) | `48200015` | ドロップダウンから選択 |
| 出現タイミング | `input[name="login_day"]` | `0` | 入会後X日。0=全員公開 |
| 出力先テーマ | `checkbox` (1〜4) | テーマ2をチェック | 複数選択可 |
| 公開開始日 | `#sdate` | `2026-01-28` | YYYY-MM-DD形式（type="date"） |
| 公開開始時間 | `#stime` | `00:00` | HH:MM形式（type="time"） |

### 出力先テーマ

| テーマID | 名称 |
|---------|------|
| 1 | あの人との恋 |
| 2 | 複雑な恋 |
| 3 | 出逢いと結婚 |
| 4 | 人生と仕事 |

### 商品カテゴリコード → 出力先テーマ マッピング（重要）

`auto_generated.category_code` から自動的に出力先テーマを決定：

| カテゴリコード | アイコン名 | 出力先テーマ |
|--------------|-----------|-------------|
| 01 | 無料 | 選択なし |
| 02 | あの人の気持ち | 1 : あの人との恋 |
| 03 | 相性 | 1 : あの人との恋 |
| 04 | 片想い | 1 : あの人との恋 |
| 05 | 恋の行方 | 1 : あの人との恋 |
| 06 | 秘密の恋 | 2 : 複雑な恋 |
| 07 | 復縁 | 2 : 複雑な恋 |
| 08 | 夜の相性 | 1 : あの人との恋 |
| 09 | 豪華恋愛 | 1 : あの人との恋 |
| 10 | 恋愛パック | 1 : あの人との恋 |
| 11 | 結婚 | 3 : 出逢いと結婚 |
| 12 | 出逢い | 3 : 出逢いと結婚 |
| 13 | そばにある恋 | 3 : 出逢いと結婚 |
| 14 | 豪華結婚 | 3 : 出逢いと結婚 |
| 15 | 豪華出逢い | 3 : 出逢いと結婚 |
| 16 | 人生 | 4 : 人生と仕事 |
| 17 | 仕事 | 4 : 人生と仕事 |
| 18 | 豪華人生 | 4 : 人生と仕事 |
| 19 | 人生パック | 4 : 人生と仕事 |
| 20 | 年運 | 4 : 人生と仕事 |

### マッピング関数

```javascript
function getThemeIdFromCategoryCode(categoryCode) {
    const CATEGORY_TO_THEME = {
        // テーマ1: あの人との恋
        '02': 1, '03': 1, '04': 1, '05': 1, '08': 1, '09': 1, '10': 1,
        // テーマ2: 複雑な恋
        '06': 2, '07': 2,
        // テーマ3: 出逢いと結婚
        '11': 3, '12': 3, '13': 3, '14': 3, '15': 3,
        // テーマ4: 人生と仕事
        '16': 4, '17': 4, '18': 4, '19': 4, '20': 4,
        // 無料は選択なし
        '01': null,
    };
    return CATEGORY_TO_THEME[categoryCode] || null;
}
```

## 自動更新の内容

以下の項目が自動更新される:

1. **公開日時**: 設定された公開スケジュールに基づいて更新
2. **表示フラグ**: 公開/非公開の切り替え
3. **料金情報**: キャンペーン料金の適用
4. **誘導設定**: 自動誘導先の切り替え

## 出力

- `success`: 成功/失敗
- `updated_count`: 更新件数
- `updated_menu_ids`: 更新されたmenu_idリスト
- `message`: 結果メッセージ
- `screenshot`: 完了時スクリーンショット

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| 認証失敗 (401) | 認証情報確認、URLを再構成 |
| 更新対象なし | 正常（更新が不要な状態） |
| 更新エラー | エラーメッセージ取得、詳細確認 |

## 不変条件（Invariants）

**リファクタリング時に絶対に壊してはならない動作仕様。**

### I1. category_code → theme_idマッピング
- マッピングテーブル（CATEGORY_TO_THEME）を変更しないこと
- カテゴリコードは0パディング2桁文字列（"02", "06"等）
- `01`（無料）はテーマ選択なし

### I2. 既登録PPVの検出
- ドロップダウンに存在しないPPVは既登録
- 既登録の場合は成功として返す（エラーにしない）

### I3. 公開日のフォーマット
- `#sdate`はYYYY-MM-DD形式、`#stime`はHH:MM形式
- type="date" / type="time"の入力要素

### I4. Basic認証はURLに埋め込み
- izumo CMSへのアクセスはURL埋め込みBasic認証

## 使用例

```
/step8

※引数不要（設定に基づいて自動更新を実行）
```

## 補足

### 自動更新のタイミング

- 通常は日次バッチで自動実行される
- 手動実行は即時反映が必要な場合に使用

### 更新対象の条件

- 公開日時が現在以前のコンテンツ
- 自動更新フラグが有効なコンテンツ
- 変更が検出されたコンテンツ

### STEP 8 の位置づけ

STEP 8 は運用フェーズの機能で、STEP 1-7 とは独立して実行可能。
新規商品登録フロー完了後に実行することで、即座に公開状態にできる。

### 既登録PPVの扱い

- `ppv_automation_opener_edit.html` のドロップダウンには**未登録PPVのみ**表示される
- 既に自動更新登録済みのPPVはドロップダウンに存在しない
- 既登録の場合は `?id={ppv_id}` で編集ページに遷移可能
- API (`register_ppv_step8`) は既登録を自動検出し、成功として返す

## 完了確認（必須）

**STEP 8 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. 自動更新一覧ページにアクセス
   URL: https://{user}:{pass}@izumo-dev.uranai-gogo.com/admin/ppv_automation_opener.html

2. browser_snapshot で一覧を取得

3. 以下を確認:
   - ppv_id が一覧に存在
   - 公開日が正しく設定されている
   - テーマが正しく選択されている
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| 登録メッセージ | 「登録しました」表示 | snapshot内を検索 |
| ppv_id存在 | 一覧にppv_idあり | 一覧ページで検索 |
| テーマ設定 | カテゴリに対応したテーマ | 該当行のテーマ列 |
| 公開日 | 設定した日付 | 該当行の公開日列 |

### 確認コード例

```javascript
// snapshotから確認
const hasRegisterComplete = snapshot.includes('登録しました') || snapshot.includes('更新完了');
const hasPpvId = snapshot.includes('{ppv_id}');
if (!hasPpvId) {
  throw new Error('STEP 8 確認失敗: ppv_idが一覧に見つかりません');
}
console.log('✅ STEP 8 完了確認OK');
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| ppv_id選択不可 | STEP 6,7未完了 | STEP 6,7を先に完了 |
| テーマ不一致 | カテゴリマッピングエラー | カテゴリコードを再確認 |
| 公開日エラー | 日付フォーマット不正 | YYYY-MM-DD形式に修正 |
| 認証エラー | Basic認証失敗 | 認証情報をURL再構成 |

---

## 統一APIエンドポイント

STEP 8はセッション駆動の統一APIでも実行可能:

```
POST /api/step/8/execute
{
  "session_id": "xxx",
  "overrides": {"category_code": "02", "publish_date": "2026-02-15"}
}
```

- STEP 7がSUCCESSでないと実行不可
- セッションのppv_id, category_codeを自動使用
- 既存API `/api/izumo/auto-update` も引き続き利用可能

---

## 依存関係

**STEP 8 は STEP 7 の完了後に実行すること（並列実行禁止）。**

### 実行順序
```
STEP 7: 小見出し登録（izumo反映）
    ↓ （完了確認後）
STEP 8: 従量自動更新 ← このスキル
```

### 並列実行禁止の理由
- STEP 7 と STEP 8 は同じizumo CMSを使用
- STEP 7 の反映が完了する前に自動更新すると、未反映のデータで更新される
- STEP 7 の完了（"反映完了"メッセージ）を確認してから STEP 8 を実行すること

### 独立実行時の注意
STEP 8 を単独で実行する場合（日次バッチ等）は、STEP 7 との依存関係は不要。
register-all で連続実行する場合のみ、順次実行が必須。
