# Error Handling & Resume Pattern

## 1. エラーコード体系

### 標準エラーコード

```python
class ErrorCode:
    # ユーザー起因
    USER_CANCEL = "USER_CANCEL"           # ユーザーキャンセル
    VALIDATION_ERROR = "VALIDATION_ERROR" # 入力バリデーションエラー

    # ネットワーク関連
    NETWORK_ERROR = "NETWORK_ERROR"       # ネットワーク接続エラー
    TIMEOUT = "TIMEOUT"                   # タイムアウト

    # 認証関連
    AUTH_ERROR = "AUTH_ERROR"             # 認証エラー
    AUTH_EXPIRED = "AUTH_EXPIRED"         # 認証期限切れ
    PERMISSION_DENIED = "PERMISSION_DENIED"  # 権限不足

    # 外部サービス関連
    EXTERNAL_ERROR = "EXTERNAL_ERROR"     # 外部サービスエラー
    EXTERNAL_UNAVAILABLE = "EXTERNAL_UNAVAILABLE"  # 外部サービス利用不可
    RATE_LIMITED = "RATE_LIMITED"         # レート制限

    # システム関連
    SYSTEM_ERROR = "SYSTEM_ERROR"         # 内部エラー
    RESOURCE_EXHAUSTED = "RESOURCE_EXHAUSTED"  # リソース不足
    BROWSER_CLOSE = "BROWSER_CLOSE"       # ブラウザ終了

    # データ関連
    DATA_NOT_FOUND = "DATA_NOT_FOUND"     # データ未発見
    DATA_CONFLICT = "DATA_CONFLICT"       # データ競合
    DATA_CORRUPT = "DATA_CORRUPT"         # データ破損
```

### エラーコードと再開可能性

```python
ERROR_RECOVERY_MAP = {
    # 再開可能
    "USER_CANCEL": {"recoverable": True, "action": "ユーザーが再開を選択"},
    "NETWORK_ERROR": {"recoverable": True, "action": "ネットワーク復旧後に再実行"},
    "TIMEOUT": {"recoverable": True, "action": "再実行（タイムアウト延長を検討）"},
    "AUTH_EXPIRED": {"recoverable": True, "action": "再ログイン後に再開"},
    "EXTERNAL_UNAVAILABLE": {"recoverable": True, "action": "サービス復旧後に再実行"},
    "RATE_LIMITED": {"recoverable": True, "action": "時間をおいて再実行"},
    "BROWSER_CLOSE": {"recoverable": True, "action": "ページを開き直して再開"},

    # 条件付き再開可能
    "EXTERNAL_ERROR": {"recoverable": "depends", "action": "エラー内容を確認して対応"},
    "SYSTEM_ERROR": {"recoverable": "depends", "action": "エラーログを確認"},

    # 再開不可（修正が必要）
    "VALIDATION_ERROR": {"recoverable": False, "action": "入力データを修正して最初から"},
    "PERMISSION_DENIED": {"recoverable": False, "action": "権限を取得してから再実行"},
    "DATA_CORRUPT": {"recoverable": False, "action": "データを修復または再作成"},
    "RESOURCE_EXHAUSTED": {"recoverable": False, "action": "リソースを確保してから再実行"},
}
```

## 2. エラーハンドリングパターン

### 基本パターン

```javascript
async function executeWithErrorHandling(stepNumber, stepName, executor) {
    try {
        return await executor();
    } catch (error) {
        // エラー分類
        const errorCode = classifyError(error);
        const recoveryInfo = ERROR_RECOVERY_MAP[errorCode];

        // エラー情報を構築
        const errorInfo = {
            code: errorCode,
            message: error.message,
            recoverable: recoveryInfo?.recoverable ?? false,
            suggested_action: recoveryInfo?.action ?? null,
            details: {
                name: error.name,
                originalError: error.toString()
            }
        };

        // ステップ状態を更新
        await updateStepStatus(stepNumber, 'error', {
            error: errorInfo.message,
            errorCode: errorInfo.code,
            recoverable: errorInfo.recoverable,
            suggestedAction: errorInfo.suggested_action
        });

        // エラーログ
        await addLog(`${stepName}でエラー: ${error.message}`, {
            level: 'error',
            step: stepNumber,
            data: errorInfo
        });

        throw error;
    }
}

/**
 * エラーを分類してコードを返す
 */
function classifyError(error) {
    const message = error.message.toLowerCase();

    // タイムアウト
    if (message.includes('timeout') || message.includes('timed out')) {
        return 'TIMEOUT';
    }

    // ネットワークエラー
    if (message.includes('network') || message.includes('fetch') ||
        message.includes('connection') || error.name === 'TypeError') {
        return 'NETWORK_ERROR';
    }

    // 認証エラー
    if (message.includes('auth') || message.includes('401') ||
        message.includes('unauthorized')) {
        return 'AUTH_ERROR';
    }

    // 権限エラー
    if (message.includes('403') || message.includes('forbidden') ||
        message.includes('permission')) {
        return 'PERMISSION_DENIED';
    }

    // レート制限
    if (message.includes('429') || message.includes('rate limit') ||
        message.includes('too many')) {
        return 'RATE_LIMITED';
    }

    // バリデーションエラー
    if (message.includes('validation') || message.includes('invalid') ||
        message.includes('required')) {
        return 'VALIDATION_ERROR';
    }

    return 'SYSTEM_ERROR';
}
```

### リトライパターン

```javascript
/**
 * 指定回数リトライを試みる
 */
async function withRetry(executor, options = {}) {
    const {
        maxRetries = 3,
        retryDelay = 1000,
        backoffMultiplier = 2,
        retryableErrors = ['TIMEOUT', 'NETWORK_ERROR', 'RATE_LIMITED']
    } = options;

    let lastError;
    let delay = retryDelay;

    for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
        try {
            return await executor();
        } catch (error) {
            lastError = error;
            const errorCode = classifyError(error);

            // リトライ可能なエラーかチェック
            if (!retryableErrors.includes(errorCode)) {
                throw error;
            }

            // 最後の試行なら諦める
            if (attempt > maxRetries) {
                throw error;
            }

            // リトライログ
            await addLog(`リトライ ${attempt}/${maxRetries}: ${error.message}`, {
                level: 'warn',
                data: { errorCode, nextRetryMs: delay }
            });

            // 待機
            await new Promise(resolve => setTimeout(resolve, delay));
            delay *= backoffMultiplier;
        }
    }

    throw lastError;
}

// 使用例
const result = await withRetry(
    async () => {
        const response = await fetch('/api/data');
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    },
    { maxRetries: 3, retryDelay: 2000 }
);
```

## 3. 再開パターン

### バックエンド: 再開可能性チェック

```python
def can_resume(self, record_id: str) -> Dict:
    """再開可能かチェックし、再開情報を返す"""
    record = self._store.get(record_id)
    if not record:
        return {"can_resume": False, "reason": "Record not found"}

    if record.status == ProcessStatus.COMPLETED:
        return {"can_resume": False, "reason": "Already completed"}

    # エラーステップを特定
    error_steps = [s for s in record.steps if s.status == StepStatus.ERROR]

    if error_steps:
        last_error_step = error_steps[-1]
        if last_error_step.error and not last_error_step.error.recoverable:
            return {
                "can_resume": False,
                "reason": f"Step {last_error_step.step} has non-recoverable error",
                "error_code": last_error_step.error.code,
                "suggested_action": last_error_step.error.suggested_action
            }

    # 再開ステップを決定
    # 成功したステップの次から再開
    completed_steps = [s.step for s in record.steps if s.status == StepStatus.SUCCESS]
    if completed_steps:
        resume_step = max(completed_steps) + 1
    else:
        resume_step = 1

    # 再開ステップが存在するか
    if resume_step > len(record.steps):
        return {"can_resume": False, "reason": "No more steps to execute"}

    return {
        "can_resume": True,
        "resume_from_step": resume_step,
        "resume_step_name": self.step_definitions.get(resume_step, {}).get("name", ""),
        "completed_steps": completed_steps,
        "skipped_steps": [s.step for s in record.steps if s.status == StepStatus.SKIPPED],
        "context": record.context
    }

def prepare_resume(self, record_id: str) -> Optional[ProcessRecord]:
    """再開の準備（エラーステップをpendingに戻す）"""
    record = self._store.get(record_id)
    if not record:
        return None

    # エラー/中断ステップをpendingに戻す
    for step in record.steps:
        if step.status in [StepStatus.ERROR, StepStatus.RUNNING]:
            step.status = StepStatus.PENDING
            step.error = None
            # retry_countは保持（再開回数の追跡用）

    record.status = ProcessStatus.PENDING
    record.interrupt_reason = None
    record.updated_at = datetime.now().isoformat()

    record.logs.append(LogEntry(
        level=LogLevel.INFO,
        message=f"プロセス再開準備完了",
        data={"resume_from_step": record.current_step}
    ))

    self._save_to_disk(record)
    return record
```

### フロントエンド: 再開実行

```javascript
/**
 * プロセスを再開実行
 */
async function resumeAndExecute(recordId) {
    try {
        // 再開情報を取得
        const resumeInfo = await resumeProcess(recordId);

        if (!resumeInfo) {
            throw new Error('再開情報を取得できませんでした');
        }

        const { record, resumeFromStep, resumeStepName } = resumeInfo;

        // 再開準備API呼び出し
        await fetch(`/api/process/${recordId}/prepare-resume`, { method: 'POST' });

        // 通知
        showNotification(
            `STEP ${resumeFromStep}（${resumeStepName}）から再開します`,
            'info'
        );

        // 各ステップを順番に実行（resumeFromStepから）
        for (const stepDef of STEP_DEFINITIONS) {
            if (stepDef.step < resumeFromStep) {
                continue;  // 完了済みステップはスキップ
            }

            await executeStep(
                stepDef.step,
                stepDef.name,
                stepDef.executor,
                stepDef.options
            );
        }

        showNotification('処理が完了しました', 'success');

    } catch (error) {
        showNotification(`再開エラー: ${error.message}`, 'error');
    }
}

/**
 * 特定ステップから実行（スキップ機能付き）
 */
async function executeFromStep(startStep, options = {}) {
    const { skipConfirmation = false } = options;

    if (!skipConfirmation && startStep > 1) {
        const confirmed = await showConfirmDialog(
            `STEP ${startStep}から実行します。\nSTEP 1〜${startStep - 1}はスキップされます。`
        );
        if (!confirmed) return;
    }

    // スキップするステップを記録
    for (let step = 1; step < startStep; step++) {
        await updateStepStatus(step, 'skipped', {
            result: { reason: '再開時スキップ' }
        });
    }

    // 指定ステップから実行
    for (const stepDef of STEP_DEFINITIONS) {
        if (stepDef.step < startStep) continue;

        await executeStep(
            stepDef.step,
            stepDef.name,
            stepDef.executor,
            stepDef.options
        );
    }
}
```

## 4. 中断時のデータ保全

### コンテキスト自動保存

```javascript
/**
 * 定期的にコンテキストを保存（中断に備える）
 */
let contextSaveInterval = null;

function startContextAutoSave(intervalMs = 10000) {
    if (contextSaveInterval) return;

    contextSaveInterval = setInterval(async () => {
        if (processRecord && processRecord.status === 'running') {
            await saveUIToContext();
        }
    }, intervalMs);
}

function stopContextAutoSave() {
    if (contextSaveInterval) {
        clearInterval(contextSaveInterval);
        contextSaveInterval = null;
    }
}

// プロセス開始時に自動保存を開始
async function startProcess(context) {
    await createProcess(context);
    startContextAutoSave();
}

// プロセス完了/中断時に自動保存を停止
async function endProcess() {
    stopContextAutoSave();
    await saveUIToContext();  // 最終状態を保存
}
```

### 中断前の状態保存

```javascript
/**
 * 中断前に必ず呼び出す
 */
async function gracefulInterrupt(reason, errorCode = null) {
    // 現在のUI状態を保存
    await saveUIToContext();

    // ログ追加
    await addLog(`中断準備: ${reason}`, {
        level: 'warn',
        step: processRecord?.current_step
    });

    // 中断を記録
    await interruptProcess(reason, errorCode);

    // 自動保存停止
    stopContextAutoSave();
}

// ユーザーがキャンセルボタンを押した場合
async function handleUserCancel() {
    if (!confirm('処理を中断しますか？途中から再開できます。')) {
        return;
    }

    await gracefulInterrupt('ユーザーによるキャンセル', 'USER_CANCEL');
    showNotification('処理を中断しました。後で再開できます。', 'info');
}
```

## 5. 再開UI/UXパターン

### 再開ダイアログ

```javascript
/**
 * 再開確認ダイアログを表示
 */
async function showResumeDialog(processInfo) {
    return new Promise((resolve) => {
        const dialog = document.createElement('div');
        dialog.className = 'resume-dialog';
        dialog.innerHTML = `
            <div class="resume-dialog-content">
                <h3>未完了のプロセスがあります</h3>
                <div class="resume-info">
                    <p><strong>中断位置:</strong> STEP ${processInfo.current_step} (${processInfo.current_step_name})</p>
                    ${processInfo.interrupt_reason ? `
                        <p><strong>中断理由:</strong> ${processInfo.interrupt_reason}</p>
                    ` : ''}
                    <p><strong>最終更新:</strong> ${formatDateTime(processInfo.updated_at)}</p>
                </div>
                <div class="resume-actions">
                    <button class="btn-resume">途中から再開</button>
                    <button class="btn-restart">最初からやり直す</button>
                    <button class="btn-cancel">キャンセル</button>
                </div>
            </div>
        `;

        dialog.querySelector('.btn-resume').onclick = () => {
            dialog.remove();
            resolve('resume');
        };
        dialog.querySelector('.btn-restart').onclick = () => {
            dialog.remove();
            resolve('restart');
        };
        dialog.querySelector('.btn-cancel').onclick = () => {
            dialog.remove();
            resolve('cancel');
        };

        document.body.appendChild(dialog);
    });
}

// 使用例
async function handlePageLoad() {
    const incompleteProcesses = await checkIncompleteProcesses();

    if (incompleteProcesses.length > 0) {
        const choice = await showResumeDialog(incompleteProcesses[0]);

        switch (choice) {
            case 'resume':
                await resumeAndExecute(incompleteProcesses[0].record_id);
                break;
            case 'restart':
                // 古いプロセスを完了済みにマーク
                await interruptProcess(
                    incompleteProcesses[0].record_id,
                    '新規プロセス開始のため破棄'
                );
                // 新規プロセス開始
                await startNewProcess();
                break;
            case 'cancel':
                // 何もしない
                break;
        }
    }
}
```
