---
name: step1-manuscript
description: |
  STEP 1: 原稿生成・PPV ID発行（商品登録）
  auto.htmlの機能を使用して原稿を生成し、PPV IDを発行する。
  ブラウザ自動化は不要（API呼び出しのみ）。
  キーワード: STEP1, 原稿生成, PPV ID, 商品登録, API
---

# STEP 1: 原稿生成・PPV ID発行

## 概要

Rohan（auto.html）の原稿生成機能を使用して、占い商品の原稿を生成し、PPV IDを発行する。

## 対象システム

- **URL**: `http://localhost:5558/auto.html` （ローカルサーバー）
- **認証**: 不要
- **方式**: API呼び出し

## 前提条件

1. ローカルサーバーが起動していること
   ```bash
   ./start_unified_server.sh
   ```
2. 以下の入力データが必要:
   - `site_id`: サイトID
   - `site_name`: サイト名
   - `ppv_id`: PPV ID（5桁数字）
   - `ppv_title`: 商品タイトル
   - `manuscript_type`: 原稿タイプ（ppv, monthly, free）
   - `subtitles`: 小見出し情報（CSVまたはJSON）

## 実行フロー

### 1. 入力データ準備

```json
{
  "site_id": 482,
  "site_name": "izumo",
  "ppv_id": "10001",
  "ppv_title": "【恋愛占い】彼の本音",
  "manuscript_type": "ppv",
  "subtitles": [
    {
      "title": "【冒頭/あいさつ】",
      "body": "",
      "order": 1,
      "mid_id": "1026"
    }
  ]
}
```

### 2. 原稿生成API呼び出し

```
POST http://localhost:5558/api/generate-all

Body: 上記JSONデータ
```

### 3. 結果取得

```json
{
  "success": true,
  "ppv_id": "10001",
  "menu_id": "monthlyAffinity001.001",
  "subtitles": [
    {
      "title": "【冒頭/あいさつ】",
      "body": "01\t生成された原稿テキスト...",
      "order": 1,
      "mid_id": "1026"
    }
  ]
}
```

## API エンドポイント

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/api/step1/execute` | POST | STEP1パイプライン一括実行（`mid_id`パラメータでセッションに保存） |
| `/api/generate-all` | POST | 全小見出し一括生成 |
| `/api/generate-sample` | POST | サンプル生成（1件） |
| `/api/generate-single` | POST | 単一小見出し生成 |

### mid_idのセッション保存
- `/api/step1/execute` に `mid_id` を渡すと、セッションの各小見出しに `mid_id` が保存される
- STEP2（オーケストレーター経由）は `record.product.subtitles[].mid_id` から自動取得する
- 冒頭・締めの `mid_id=1026` はSTEP2登録ロジック側でデフォルト設定済み

### site_idの自動保存（2026-02追加）
- `site_id` パラメータは自動的に `int()` に正規化される（文字列で渡しても安全）
- セッションに `site_id` が未設定の場合、STEP1実行時に自動保存される
- `update_session_ids(record_id, site_id=int(site_id))` で永続化

## 入力フォーマット

### 小見出しCSV形式

```csv
order,title,mid_id
1,【冒頭/あいさつ】,1026
2,彼の心の中でのランキング,1027
3,今の彼に必要なこと,1028
```

### 小見出しJSON形式

```json
[
  {"order": 1, "title": "【冒頭/あいさつ】", "mid_id": "1026"},
  {"order": 2, "title": "彼の心の中でのランキング", "mid_id": "1027"}
]
```

## 出力

- `success`: 成功/失敗
- `ppv_id`: 発行されたPPV ID
- `menu_id`: 発行されたmenu_id
- `subtitles`: 生成された原稿（小見出しリスト）
- `session_id`: セッションID（後続STEPで使用）

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| サーバー未起動 | `./start_unified_server.sh` を実行 |
| API エラー | エラーメッセージ確認、入力データ検証 |
| 生成失敗 | Gemini API設定確認 |
| 原稿が空で返る | 自動リトライ（1回）が実装済み。それでも空の場合はfortune_resultのフォーマットを確認 |
| [生成エラー]検出 | 品質ゲートでSTEP 1がerror終了。STEP 1を再実行すること（v1.51.4以降） |
| subtitle_count=0 | 早期リターンで `errorType: "no_subtitles"` を返す。fortune_resultが番号リスト形式であることを確認 |

## 小見出し抽出の対応フォーマット

| パターン | 形式 | 例 |
|----------|------|-----|
| パターン1 | `小見出しN: タイトル` | `・小見出し1: あの人の本音` |
| パターン1.5 | 番号リスト直接形式（3件以上） | `1. あの人の本音` |
| パターン2 | `小見出し一覧`セクション内の番号リスト | `小見出し一覧\n1. あの人の本音` |
| パターン3 | 番号なし（連番自動付与） | セクション内のテキスト行 |

## 速度改善メモ

- yudo-txt と yudo-recommend は `Promise.allSettled` で並列実行される（2026-02-02改善）
- PPV ID発行は原稿生成と依存関係がないため、先行発行も可能
- バッチ処理は `asyncio.gather + Semaphore(2)` で並列実行される（v1.47.0改善）
  - `PARALLEL_BATCHES=2` はGemini API RPM上限120に対して安全なレート
  - Semaphoreにより同時実行数を制限し、RPMリミット超過を防止
- タイムアウト最低値は75秒（v1.53.1改善）
  - 3コードバッチの計算値が50秒→下限60秒だったが75秒に引き上げ
- 後半バッチ（index>=2）にスタガー遅延2秒を追加（v1.53.1改善）
  - セマフォ外で待機しスロット占有を防止
- 個別フォールバックは`asyncio.gather + Semaphore(3)`で並列実行（v1.53.1改善）
  - 逐次処理(135秒)→並列(45秒)に短縮
  - 個別処理のAPIリトライは2回（`max_retries=2`）

## 不変条件（Invariants）

**リファクタリング時に絶対に壊してはならない動作仕様。**

### I1. mid_idのセッション保存
- STEP1実行時に各小見出しの`mid_id`がセッションの`product.subtitles[].mid_id`に保存されること
- STEP2はこの値からmid_idを自動取得する

### I2. site_idの型正規化
- `site_id`パラメータは必ず`int()`に正規化すること
- 文字列で渡された場合もクラッシュしないこと

### I3. 小見出し抽出パターンの優先順位
- パターン1 → パターン1.5 → パターン2 → パターン3 の順で試行
- パターン変更時は既存の全パターンが動作することを検証

### I4. 空原稿の自動リトライ
- 原稿生成結果が空の場合、1回自動リトライする
- `subtitle_count=0`の場合は早期リターン（`errorType: "no_subtitles"`）

### I5. SubtitleInfo型安全性
- STEP 1はdict ではなくSubtitleInfoオブジェクトでsubtitlesを保存（v1.49.0以降）
- dictで代用するとSTEP 3等でdot notationアクセス時にAttributeErrorが発生する

### I6. 原稿品質ゲート（生成エラーブロック）
- STEP 1完了前に以下をチェック:
  - `manuscript_text`内の`[生成エラー]`マーカー数
  - 冒頭文: `generate_opening=True`かつ`opening_text`空かつ`structured["opening"]`未存在
  - 締め文: `generate_closing=True`かつ`closing_text`空かつ`structured["closing"]`未存在
  - サマリー: `_process_special_komis()`の戻り値（失敗項目リスト）
- いずれか1件以上 → STEP 1を`error`ステータスで終了、STEP 2以降をブロック
- 原稿データはセッションに保存済み（再実行時の参考データとして利用可能）
- BE（step1_pipeline.py）/ FE（auto.html）両パスで適用

### I7. 末尾小見出しのkomi_type制約
- 末尾（最後）の小見出しは`komi_normal`禁止（締めメッセージとして使われるため）
- `infer_komi_type_with_gemini()`のreturn前に強制チェック→`komi_jyuyou1`に変更（v1.49.1以降）
- フォールバック（komi_normal埋め）でも末尾が保護される

## 使用例

```
/step1

入力:
- site_id: 482
- site_name: izumo
- ppv_id: 10001
- ppv_title: 【恋愛占い】彼の本音
- manuscript_type: ppv
- subtitles_csv: /path/to/subtitles.csv
```

## 補足

### STEP 1 はブラウザ自動化不要

STEP 1 はローカルAPIを呼び出すだけなので、Playwright MCPは使用しない。
生成された原稿データをSTEP 2以降で使用する。

### セッション管理

STEP 1 で生成されたセッションIDを使用して、STEP 2-8 の進捗を追跡する。

```json
{
  "session_id": "abc12345",
  "step_progress": [
    {"step": 1, "status": "completed", "ppv_id": "10001"}
  ]
}
```

## 完了確認（必須）

**STEP 1 実行後、以下の確認を必ず行うこと：**

### 確認手順

```
1. APIレスポンスまたはセッションデータを確認
   GET http://localhost:5558/api/registration-session/{record_id}

2. 以下を確認:
   - ppv_id が8桁数字で発行されている
   - menu_id が生成されている（例: monthlyAffinity001.001）
   - subtitles の件数が入力と一致
   - 各小見出しにbodyが生成されている
```

### 確認項目

| 項目 | 成功条件 | 確認方法 |
|------|----------|----------|
| ppv_id | 8桁数字（例: 48200038） | セッションデータ |
| menu_id | 形式: {prefix}{number}.{subtitle} | セッションデータ |
| subtitles | 件数が入力と一致 | セッションデータ |
| body | 各小見出しにテキスト生成済み | subtitles配列の各要素 |

### 確認コード例

```bash
# セッションデータ確認
curl -s "http://localhost:5558/api/registration-session/{record_id}" | python3 -m json.tool

# 確認項目
# - ids.ppv_id が8桁数字
# - ids.menu_id が空でない
# - product.subtitles の件数が期待値と一致
```

### 失敗時の対処

| 症状 | 原因 | 対処 |
|------|------|------|
| ppv_id未発行 | 発行API失敗 | /api/ppv-ids/issue を再実行 |
| menu_id未生成 | 原稿生成失敗 | Gemini API設定を確認 |
| subtitles空 | 生成処理失敗 | ログを確認して再実行 |
| サーバーエラー | サーバー未起動 | ./start_unified_server.sh |

---

## 依存関係

**STEP 1 は全フローの起点。完了後に STEP 2 を実行すること。**

### 実行順序
```
STEP 1: 原稿生成・PPV ID発行 ← このスキル
    ↓ （完了確認後）
STEP 2: メニュー登録（原稿管理CMS）
```

### STEP 2への引き渡しデータ
STEP 1 完了時に以下を STEP 2 に引き渡す：
- `ppv_id`: 発行されたPPV ID
- `menu_id`: 発行されたmenu_id
- `subtitles`: 生成された原稿（小見出しリスト）
- `session_id`: セッションID

STEP 1 が失敗した場合、STEP 2 以降は実行不可。
