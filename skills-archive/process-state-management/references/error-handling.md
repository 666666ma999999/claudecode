# エラーハンドリング詳細

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

## StepExecuteResponse の error_type フィールド (v1.45.0)

`StepExecuteResponse` に `error_type: Optional[str]` フィールドが追加済み。
エラー発生時に以下の分類でFEに通知される（camelCase: `errorType`）:

| error_type | 発生条件 | 再開可能 |
|------------|----------|----------|
| `validation` | ビルダーエラー / HTTP 400,422 | No（入力修正が必要） |
| `timeout` | asyncio.TimeoutError | Yes |
| `network` | ConnectionError / OSError | Yes |
| `auth` | HTTP 401, 403 | Depends |
| `system` | その他の例外 | Maybe |

## セッション更新関数の戻り値 (v1.45.0)

以下の関数は `bool` を返すように変更済み（以前は `None`）:
- `update_session_ids()` → `True`/`False`
- `update_session_product()` → `True`/`False`
- `update_session_distribution()` → `True`/`False`（yudo dict→YudoInfo自動変換付き）
- `update_step_status()` → `True`/`False`（STEP未検出時も警告ログ出力）

セッション未検出時はログに警告を出力する（サイレント失敗を解消）。

## Sentry状態マッピング（任意）

Sentry MCPが有効な場合、プロセス状態とSentry issue状態を以下で対応付ける：

| ProcessRecord status | Sentry issue status |
|---------------------|---------------------|
| `running` | `unresolved` |
| `error` | `unresolved` |
| `interrupted` | `unresolved` |
| `completed` | `resolved` |

| 中断理由コード | Sentry対応 |
|---------------|-----------|
| `NETWORK_ERROR` | Sentryで同一エラーの発生頻度を確認 |
| `AUTH_ERROR` | Sentryで認証関連issueを検索 |
| `SYSTEM_ERROR` | Sentryのスタックトレースで根因特定 |

Sentry未導入時はこのマッピングを無視し、従来のローカル状態管理のみで動作する。

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

## パターン: 段階別データ件数検証

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
```
