# Logging Pattern

## 1. ログレベルの使い分け

| レベル | 用途 | 例 |
|--------|------|-----|
| DEBUG | 開発時のデバッグ情報 | 変数の値、内部状態 |
| INFO | 通常の処理フロー | ステップ開始/完了、処理結果 |
| WARN | 注意が必要だが続行可能 | リトライ発生、デフォルト値使用 |
| ERROR | 処理失敗、要対応 | API呼び出し失敗、バリデーションエラー |

## 2. ログ出力タイミング

### 必須ログポイント

```
プロセス開始
│
├─ STEP 1 開始 (INFO)
│   ├─ 重要な判断点 (DEBUG)
│   ├─ 外部API呼び出し前 (DEBUG)
│   ├─ 外部API呼び出し後 (INFO/ERROR)
│   └─ STEP 1 完了/失敗 (INFO/ERROR)
│
├─ STEP 2 開始 (INFO)
│   └─ ...
│
└─ プロセス完了/中断 (INFO/WARN)
```

### ログ出力テンプレート

```javascript
// ステップ開始
await addLog(`STEP ${step}: ${stepName}を開始`, {
    level: 'info',
    step: step
});

// 外部API呼び出し
await addLog(`外部API呼び出し: ${apiName}`, {
    level: 'debug',
    step: step,
    data: { endpoint, params: sanitizeParams(params) }
});

// 処理結果
await addLog(`${stepName}完了`, {
    level: 'info',
    step: step,
    data: { resultSummary }
});

// エラー
await addLog(`${stepName}でエラー: ${error.message}`, {
    level: 'error',
    step: step,
    data: {
        errorCode,
        errorType: error.name,
        recoverable: true
    }
});

// 警告（リトライ）
await addLog(`${stepName}リトライ (${retryCount}/${maxRetries})`, {
    level: 'warn',
    step: step,
    data: { reason: 'タイムアウト' }
});
```

## 3. 機密情報のマスキング

```javascript
/**
 * ログ用にパラメータをサニタイズ
 */
function sanitizeParams(params) {
    const sensitiveKeys = [
        'password', 'token', 'api_key', 'secret',
        'credit_card', 'ssn', 'phone', 'email'
    ];

    const sanitized = { ...params };

    for (const key of Object.keys(sanitized)) {
        const lowerKey = key.toLowerCase();
        if (sensitiveKeys.some(sk => lowerKey.includes(sk))) {
            sanitized[key] = '***MASKED***';
        }
    }

    return sanitized;
}

/**
 * エラーメッセージからURLパラメータをマスク
 */
function sanitizeErrorMessage(message) {
    // URLのクエリパラメータをマスク
    return message.replace(/([?&](token|key|secret|password)=)[^&]*/gi, '$1***');
}
```

## 4. ログの構造化

### 推奨ログ形式

```json
{
    "timestamp": "2026-01-27T09:30:00.123Z",
    "level": "info",
    "step": 2,
    "message": "データ処理完了",
    "data": {
        "processed_count": 150,
        "duration_ms": 1234,
        "warnings": []
    }
}
```

### ログデータの標準フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| duration_ms | number | 処理時間（ミリ秒） |
| count | number | 処理件数 |
| success_count | number | 成功件数 |
| error_count | number | エラー件数 |
| warnings | array | 警告メッセージ一覧 |
| retry_count | number | リトライ回数 |
| error_code | string | エラーコード |

## 5. ログの永続化と参照

### バックエンド: ログ参照API

```python
@router.get("/api/process/{record_id}/logs")
async def get_logs(
    record_id: str,
    level: str = None,      # フィルタ: debug, info, warn, error
    step: int = None,       # フィルタ: ステップ番号
    from_time: str = None,  # フィルタ: 開始時刻
    to_time: str = None,    # フィルタ: 終了時刻
    limit: int = 100        # 最大件数
):
    record = process_store.get(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")

    logs = record.logs

    # フィルタ適用
    if level:
        level_priority = {'debug': 0, 'info': 1, 'warn': 2, 'error': 3}
        min_priority = level_priority.get(level, 0)
        logs = [l for l in logs if level_priority.get(l.level.value, 0) >= min_priority]

    if step is not None:
        logs = [l for l in logs if l.step == step]

    if from_time:
        logs = [l for l in logs if l.timestamp >= from_time]

    if to_time:
        logs = [l for l in logs if l.timestamp <= to_time]

    # 最新N件
    logs = logs[-limit:]

    return {
        "success": True,
        "total": len(record.logs),
        "filtered": len(logs),
        "logs": [l.dict() for l in logs]
    }

@router.get("/api/process/{record_id}/logs/export")
async def export_logs(record_id: str, format: str = "json"):
    """ログをファイルとしてエクスポート"""
    record = process_store.get(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Process not found")

    if format == "json":
        content = json.dumps([l.dict() for l in record.logs], ensure_ascii=False, indent=2)
        media_type = "application/json"
        filename = f"{record_id}_logs.json"
    elif format == "csv":
        lines = ["timestamp,level,step,message"]
        for log in record.logs:
            lines.append(f"{log.timestamp},{log.level.value},{log.step or ''},{log.message}")
        content = "\n".join(lines)
        media_type = "text/csv"
        filename = f"{record_id}_logs.csv"
    else:
        raise HTTPException(status_code=400, detail="Unsupported format")

    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
```

### フロントエンド: ログビューア

```javascript
/**
 * ログを取得して表示
 */
async function showProcessLogs(recordId, options = {}) {
    const params = new URLSearchParams();
    if (options.level) params.set('level', options.level);
    if (options.step) params.set('step', options.step);
    if (options.limit) params.set('limit', options.limit);

    const response = await fetch(`/api/process/${recordId}/logs?${params}`);
    const data = await response.json();

    if (!data.success) return;

    const container = document.getElementById('log-viewer');
    container.innerHTML = data.logs.map(log => `
        <div class="log-entry log-${log.level}">
            <span class="log-time">${formatTime(log.timestamp)}</span>
            <span class="log-level">${log.level.toUpperCase()}</span>
            ${log.step ? `<span class="log-step">STEP ${log.step}</span>` : ''}
            <span class="log-message">${escapeHtml(log.message)}</span>
            ${log.data ? `<pre class="log-data">${JSON.stringify(log.data, null, 2)}</pre>` : ''}
        </div>
    `).join('');
}

// CSS
const logViewerStyles = `
.log-entry {
    padding: 8px 12px;
    border-bottom: 1px solid #eee;
    font-family: monospace;
    font-size: 0.9em;
}
.log-entry.log-debug { background: #f5f5f5; }
.log-entry.log-info { background: #e3f2fd; }
.log-entry.log-warn { background: #fff3e0; }
.log-entry.log-error { background: #ffebee; }
.log-time { color: #666; margin-right: 10px; }
.log-level {
    display: inline-block;
    width: 50px;
    font-weight: bold;
}
.log-step {
    background: #e0e0e0;
    padding: 2px 6px;
    border-radius: 3px;
    margin-right: 8px;
}
.log-data {
    margin: 5px 0 0 20px;
    padding: 8px;
    background: #f5f5f5;
    border-radius: 4px;
    font-size: 0.85em;
}
`;
```

## 6. エラー分析用ログパターン

### エラー発生時の詳細ログ

```javascript
async function logError(step, error, context = {}) {
    const errorInfo = {
        name: error.name,
        message: error.message,
        stack: error.stack?.split('\n').slice(0, 5).join('\n'),  // スタック上位5行
        timestamp: new Date().toISOString(),
        step,
        context: sanitizeParams(context),
        browser: {
            userAgent: navigator.userAgent,
            online: navigator.onLine,
            language: navigator.language
        }
    };

    await addLog(`エラー詳細: ${error.name}`, {
        level: 'error',
        step,
        data: errorInfo
    });

    // 開発環境ではコンソールにも出力
    if (window.location.hostname === 'localhost') {
        console.error('Error details:', errorInfo);
    }
}
```

### デバッグ用コンテキストログ

```javascript
/**
 * 処理開始時にコンテキストをログ
 */
async function logProcessContext(processName) {
    await addLog(`${processName}開始 - コンテキスト情報`, {
        level: 'debug',
        data: {
            url: window.location.href,
            timestamp: new Date().toISOString(),
            processRecord: processRecord ? {
                id: processRecord.record_id,
                status: processRecord.status,
                currentStep: processRecord.current_step
            } : null,
            localStorage: {
                hasData: Object.keys(localStorage).length > 0
            }
        }
    });
}
```
