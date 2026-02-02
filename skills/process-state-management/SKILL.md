# Process State Management Skill

name: process-state-management
description: 複数ステップのプロセスを管理し、ログ記録・中断理由追跡・途中再開を可能にするパターン集。コンテキスト設計原則、エラー収集パターンも含む。新規プロジェクトでマルチステップ処理を実装する際に使用。

## 使用タイミング

以下の場面でこのスキルを発動:
- 複数ステップの処理フローを実装する
- プロセスの中断・再開機能が必要
- 処理ログを記録したい
- エラー発生時の原因追跡が必要
- 「ステップ管理」「プロセス状態」「再開機能」などのキーワードが出た
- 文字列置換でデータ結合が失敗する（→ コンテキスト設計原則）
- 複数操作のエラーをまとめて報告したい（→ エラー収集パターン）
- Step間でデータを渡す際にパースエラーが発生（→ ステップ間データ共有原則）

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────┐
│                   ProcessRecord                          │
├─────────────────────────────────────────────────────────┤
│ record_id: string          # 一意識別子                  │
│ created_at: datetime       # 作成日時                    │
│ updated_at: datetime       # 更新日時                    │
│ status: enum               # overall/running/completed/  │
│                            #   error/interrupted         │
│ current_step: number       # 現在のステップ番号          │
│ steps: StepProgress[]      # 各ステップの状態            │
│ context: object            # プロセス固有のコンテキスト   │
│ logs: LogEntry[]           # 詳細ログ                    │
│ interrupt_reason: string   # 中断理由（あれば）          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   StepProgress                           │
├─────────────────────────────────────────────────────────┤
│ step: number               # ステップ番号                │
│ name: string               # ステップ名                  │
│ status: enum               # pending/running/success/    │
│                            #   error/skipped             │
│ started_at: datetime       # 開始日時                    │
│ completed_at: datetime     # 完了日時                    │
│ result: object             # 成功時の結果データ          │
│ error: ErrorInfo           # エラー情報                  │
│ retry_count: number        # リトライ回数                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   LogEntry                               │
├─────────────────────────────────────────────────────────┤
│ timestamp: datetime        # ログ日時                    │
│ level: enum                # debug/info/warn/error       │
│ step: number               # 関連ステップ（任意）        │
│ message: string            # ログメッセージ              │
│ data: object               # 追加データ（任意）          │
└─────────────────────────────────────────────────────────┘
```

## 実装パターン

### 1. バックエンド（Python/FastAPI）

詳細は `references/backend-pattern.md` を参照。

主要コンポーネント:
- `ProcessRecord` Pydanticモデル
- `ProcessStore` クラス（メモリ + ファイル永続化）
- REST APIエンドポイント群

### 2. フロントエンド（JavaScript）

詳細は `references/frontend-pattern.md` を参照。

主要コンポーネント:
- `processRecord` グローバル変数
- ヘルパー関数群
- 再開バナーUI

### 3. ログ記録パターン

詳細は `references/logging-pattern.md` を参照。

## クイックスタート

### 新規プロジェクトへの適用手順

1. **ステップ定義の作成**
```python
STEP_DEFINITIONS = {
    1: {"name": "初期化", "timeout": 30, "retryable": True},
    2: {"name": "データ取得", "timeout": 60, "retryable": True},
    3: {"name": "処理実行", "timeout": 120, "retryable": False},
    4: {"name": "結果保存", "timeout": 30, "retryable": True},
}
```

2. **ProcessRecordモデルのカスタマイズ**
   - `context` フィールドにプロジェクト固有のデータ構造を定義

3. **APIエンドポイントの追加**
   - `/api/process/create`
   - `/api/process/{record_id}`
   - `/api/process/{record_id}/step`
   - `/api/process/{record_id}/log`
   - `/api/process/incomplete/list`

4. **FEヘルパー関数の追加**
   - `createProcess()`
   - `updateStepStatus()`
   - `addLog()`
   - `resumeProcess()`

5. **再開バナーUIの追加**

## 中断理由の分類

| 分類 | コード | 説明 | 再開可能 |
|------|--------|------|----------|
| ユーザー中断 | USER_CANCEL | ユーザーが明示的にキャンセル | Yes |
| タイムアウト | TIMEOUT | 処理時間超過 | Yes |
| ネットワークエラー | NETWORK_ERROR | 通信障害 | Yes |
| 認証エラー | AUTH_ERROR | 認証切れ/無効 | Depends |
| バリデーションエラー | VALIDATION_ERROR | 入力データ不正 | No |
| システムエラー | SYSTEM_ERROR | 予期せぬエラー | Maybe |
| 外部サービスエラー | EXTERNAL_ERROR | 外部API障害 | Yes |
| リソース不足 | RESOURCE_EXHAUSTED | メモリ/ストレージ不足 | No |

## 実装上の注意: モデル重複禁止

`StepProgress` と `StepStatus` は `backend/utils/models.py` に統一定義済み。
各routerでは `from utils.models import StepProgress, StepStatus` でインポートすること。
ローカル再定義は禁止。

## ベストプラクティス

1. **ステップの粒度**
   - 1ステップ = 1つの論理的な処理単位
   - 再開時に途中から実行できる粒度にする
   - 長すぎるステップは分割を検討

2. **コンテキストの保存**
   - 各ステップ完了時に中間結果を保存
   - 再開時に必要な情報が復元できること

3. **ログの活用**
   - 重要な判断点でログを記録
   - エラー時は詳細情報を含める
   - 個人情報はマスキング

4. **エラーハンドリング**
   - リトライ可能なエラーとそうでないものを区別
   - エラー情報には対処法を含める

## コンテキスト設計原則

### データ紐付けの原則

**問題**: 関連するデータを別々に保存し、実行時に文字列操作で結合しようとすると失敗しやすい

```python
# ❌ Bad: 関連データが分離、実行時に文字列で紐付け
context = {
    "text": "01\t本文内容...",           # テキストだけ
    "metadata": {"01": "追加情報"}        # 別管理
}
# 実行時: text.replace("01\t本文", f"01\t{metadata['01']}\t本文")
# → 空白・改行の違いで失敗、エラー検知困難

# ✅ Good: 最初から構造的に紐付け
context = {
    "structured_data": {
        "items": [
            {"code": "01", "metadata": None, "body": "本文内容"}
        ]
    }
}
# 実行時: items[0]["metadata"] = "追加情報"
# → フィールド直接更新、失敗は例外で検知可能
```

### 設計スメルの検知

以下のパターンが見られたら、データモデルの再設計を検討：

| スメル | 症状 | 解決策 |
|--------|------|--------|
| 文字列置換で結合 | `replace()` で関連データを結合 | 構造化データで紐付け |
| 正規表現で抽出 | 実行時に `regex` でデータを取り出す | パース済みフィールドで保持 |
| IDで別オブジェクト参照 | `data1[id]` と `data2[id]` を突合 | 1オブジェクトにまとめる |
| 同期ずれ | 片方だけ更新されて不整合 | 単一データソースで管理 |

### 構造化コンテキストの例

```python
# ProcessRecordのcontext設計例
class ProcessContext(BaseModel):
    # ❌ 避けるべき: フラットで関連性が見えない
    # manuscript_text: str
    # subtitle_list: List[str]
    # summary_map: Dict[str, str]

    # ✅ 推奨: 構造的に紐付け
    structured_manuscript: Optional[Dict[str, Any]] = Field(
        default=None,
        description="構造化原稿データ（小見出し・コード・本文を紐付け）"
    )
    # structured_manuscript = {
    #     "subtitles": [
    #         {
    #             "order": 1,
    #             "title": "小見出し",
    #             "codes": [
    #                 {"code": "01", "summary": None, "body": "本文"}
    #             ]
    #         }
    #     ]
    # }
```

## ステップ間データ共有原則

### 問題: テキスト変換→再パースの罠

Step NからStep N+1へデータを渡す際、テキスト形式に変換して再パースすると情報が失われるリスクがある。

```
❌ Bad: テキスト経由
STEP 1: 構造化データ生成 → テキストに変換 → 保存
STEP 2: テキスト取得 → 再パース → 使用
問題: 空白・改行・フォーマットの違いでパース失敗

✅ Good: 構造化データ直接渡し
STEP 1: 構造化データ生成 → そのまま保存
STEP 2: 構造化データ取得 → そのまま使用
利点: データの一貫性保証、変換エラーなし
```

### 実装パターン

**セッションでの保存**:
```javascript
// STEP 1: 構造化データを保存
await updateSession({
    context: {
        structured_data: generatedData,  // 構造化データ（メイン）
        text_version: buildText(generatedData)  // テキスト版（表示用）
    }
});
```

**APIでの受け渡し**:
```python
# API: 構造化データを優先、テキストはフォールバック
class StepRequest(BaseModel):
    structured_data: Optional[Dict[str, Any]] = None  # 優先
    text_content: str = ""  # フォールバック

@router.post("/api/step2")
async def step2(request: StepRequest):
    if request.structured_data:
        # 構造化データから直接処理（推奨）
        data = request.structured_data
    elif request.text_content:
        # フォールバック: テキストをパース（後方互換）
        data = parse_text(request.text_content)
```

**FEでの送信**:
```javascript
// STEP 2: 構造化データを優先して送信
const response = await fetch('/api/step2', {
    method: 'POST',
    body: JSON.stringify({
        structured_data: sessionRecord.context.structured_data,  // 優先
        text_content: sessionRecord.context.text_version  // フォールバック
    })
});
```

### チェックリスト

- [ ] Step間でテキスト変換→再パースしている箇所を特定
- [ ] APIが構造化データを直接受け入れるよう拡張
- [ ] FEが構造化データを優先して送信
- [ ] テキスト版はフォールバック・表示用として残す

## STEP間共通データの永続化

### 問題

複数STEPで共通して使用するデータが、セッション中断→再開時に失われる。

**よくある失敗パターン:**
```javascript
// STEP 1で生成
let productTitle = extractedData.title;  // ローカル変数

// STEP 2-7で使用
// → セッション中断後、productTitleはundefined
```

### 解決策：グローバル変数 + セッション保存 + 復元

**1. グローバル変数を定義:**
```javascript
// ファイル先頭でグローバル変数を定義
let productTitle = '';       // 商品タイトル
let guideResult = null;      // 商品紹介文
let categoryCodeResult = null;  // カテゴリコード
```

**2. セッション保存時にグローバル変数を含める:**
```javascript
// STEP 1完了時
productTitle = extractedData.title;  // グローバル変数に保存

await updateSession({
    product: {
        title: productTitle,          // ← 必ず含める
        manuscript: generatedManuscript
    },
    distribution: {
        guide_text: guideResult?.guide_text,
        category_code: categoryCodeResult?.category_code
    }
});
```

**3. セッション復元時にグローバル変数を復元:**
```javascript
function restoreFromSession(record) {
    if (record.product?.title) {
        productTitle = record.product.title;  // ← グローバル変数を復元
    }
    if (record.distribution?.guide_text) {
        guideResult = { success: true, guide_text: record.distribution.guide_text };
    }
}
```

### STEP間共通データの設計例

| データ | 生成STEP | 使用STEP | 保存先 |
|--------|----------|----------|--------|
| productTitle | STEP 1 | STEP 2-7 | product.title |
| guide_text | STEP 1 | STEP 3 | distribution.guide_text |
| category_code | STEP 1 | STEP 3 | distribution.category_code |
| price | STEP 1 | STEP 3 | distribution.price |
| ppv_id | STEP 1 | STEP 2-7 | ids.ppv_id |
| menu_id | STEP 2 | STEP 3-7 | ids.menu_id |

### チェックリスト

- [ ] 複数STEPで使用するデータをリストアップ
- [ ] 各データにグローバル変数を用意
- [ ] セッション保存にすべてのグローバル変数を含める
- [ ] セッション復元でグローバル変数を復元
- [ ] 各STEPでグローバル変数を参照（ローカル変数にコピーしない）

## エラー収集パターン

### Fail-Fast vs Error Collection

| アプローチ | 使い所 | 特徴 |
|------------|--------|------|
| Fail-Fast | 致命的エラー、依存関係あり | 最初のエラーで即停止 |
| Error Collection | 独立した複数操作 | 全て実行後にまとめて報告 |

### Error Collectionの実装

複数の独立した操作を行う場合、全てのエラーを収集してから報告：

```javascript
// ✅ Good: エラー収集パターン
async function processMultipleItems(items) {
    const errors = [];
    const results = [];

    for (const item of items) {
        try {
            const result = await processItem(item);
            if (!result.success) {
                // 失敗を記録して継続
                errors.push({
                    item: item.id,
                    error: result.error
                });
            } else {
                results.push(result);
            }
        } catch (e) {
            errors.push({
                item: item.id,
                error: e.message
            });
        }
    }

    // 最後にまとめて報告
    return {
        success: errors.length === 0,
        results,
        errors,
        summary: `${results.length}件成功, ${errors.length}件失敗`
    };
}
```

```python
# BE: 同様のパターン
def process_batch(items: List[Item]) -> BatchResult:
    errors = []
    results = []

    for item in items:
        try:
            result = process_item(item)
            results.append(result)
        except ProcessingError as e:
            errors.append(ErrorInfo(
                item_id=item.id,
                message=str(e),
                recoverable=e.recoverable
            ))

    return BatchResult(
        success=len(errors) == 0,
        processed_count=len(results),
        error_count=len(errors),
        errors=errors
    )
```

### UI表示パターン

```javascript
// エラーがあってもUIに警告表示して処理継続
function showBatchResult(result) {
    if (result.errors.length > 0) {
        const warningDiv = document.getElementById('warnings');
        warningDiv.innerHTML = `
            <div class="warning-box">
                ⚠️ ${result.errors.length}件のエラー
                <ul>
                    ${result.errors.slice(0, 5).map(e =>
                        `<li>${e.item}: ${e.error}</li>`
                    ).join('')}
                    ${result.errors.length > 5 ?
                        `<li>...他${result.errors.length - 5}件</li>` : ''}
                </ul>
            </div>
        `;
        warningDiv.style.display = 'block';
    }

    // 成功分は表示
    if (result.results.length > 0) {
        showResults(result.results);
    }
}
```

### ログへの記録

```python
# エラー収集結果をログに記録
def log_batch_result(record_id: str, result: BatchResult):
    if result.errors:
        add_log(
            record_id=record_id,
            level="warn",
            message=f"バッチ処理完了: {result.error_count}件のエラー",
            data={
                "processed": result.processed_count,
                "errors": [e.dict() for e in result.errors]
            }
        )
    else:
        add_log(
            record_id=record_id,
            level="info",
            message=f"バッチ処理完了: {result.processed_count}件成功"
        )
```

---

## パターン4: 段階別データ件数検証

「N件指定したのにM件しか処理されない」問題のデバッグパターン。

### 各段階でのカウント記録

```python
def process_with_count_validation(input_items: list, expected_count: int):
    """入力→処理→出力の各段階で件数を検証"""

    # 1. 入力段階
    logger.info(f"入力: {len(input_items)}件 (期待: {expected_count}件)")

    # 2. 処理段階
    processed = []
    for i, item in enumerate(input_items):
        result = process_item(item)
        if result:
            processed.append(result)
        else:
            logger.warning(f"項目{i+1}の処理失敗: {item[:50]}...")

    # 3. 出力段階 - 件数検証
    if len(processed) != expected_count:
        logger.warning(
            f"⚠️ 件数不一致: 期待{expected_count} vs 実際{len(processed)}"
        )

    return processed
```

### セッションデータでの追跡

```python
# セッションに各段階のカウントを記録
session_data = {
    "counts": {
        "input": len(input_items),      # FEからの入力
        "parsed": len(parsed_items),    # パース後
        "generated": len(generated),    # 生成後
        "registered": len(registered),  # 登録後
    }
}
# → 後から「どの段階で減ったか」を特定可能

## セッション復元時の注意点

### グローバル変数復元後はUI更新関数を呼ぶ

セッションからグローバル変数（例: `komiTypeResult`）を復元した場合、変数への代入だけではUIに反映されない。復元直後に対応する表示関数（例: `displayKomiTypes()`）を必ず呼び出すこと。

```javascript
// BAD: 変数復元のみ → UIに反映されない
komiTypeResult = { success: true, results: [...] };

// GOOD: 変数復元 + UI更新
komiTypeResult = { success: true, results: [...] };
displayKomiTypes(komiTypeResult);
```

### 派生フィールドはセッションに保存する

`KOMI_GENERATE_MODES[type].name`のようにマスターデータから導出される値は、セッション保存時に一緒に保存しておく。復元時にマスターデータの読み込みタイミングに依存しなくて済む。ただしフォールバックとしてマスターデータ参照も残す。

```javascript
// 保存時: 導出値も含める
{ komi_type: 'komi_special', komi_name: '特殊' }

// 復元時: 保存値優先、フォールバックでマスター参照
komiName: s.komi_name || KOMI_GENERATE_MODES[s.komi_type]?.name || '通常'
```
