# Frontend Implementation Pattern

## 1. グローバル状態とヘルパー関数

```javascript
// ========================================
// プロセス状態管理
// ========================================

// 現在のプロセスレコード
let processRecord = null;

/**
 * プロセスを新規作成
 * @param {object} context - プロセス固有のコンテキスト
 * @returns {Promise<object>} 作成されたProcessRecord
 */
async function createProcess(context = {}) {
    try {
        const response = await fetch('/api/process/create', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ context })
        });
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                processRecord = data.record;
                console.log('✅ プロセス作成:', processRecord.record_id);
                return processRecord;
            }
        }
        throw new Error('プロセス作成失敗');
    } catch (e) {
        console.error('❌ プロセス作成エラー:', e);
        throw e;
    }
}

/**
 * プロセスを再開（中断からの復帰）
 * @param {string} recordId - レコードID
 * @returns {Promise<object>} 復元されたProcessRecord
 */
async function resumeProcess(recordId) {
    try {
        // 再開可能かチェック
        const canResumeRes = await fetch(`/api/process/${recordId}/can-resume`);
        const canResumeData = await canResumeRes.json();

        if (!canResumeData.can_resume) {
            throw new Error(canResumeData.reason || '再開不可');
        }

        // プロセスを取得
        const response = await fetch(`/api/process/${recordId}`);
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                processRecord = data.record;
                console.log('✅ プロセス再開:', recordId, `STEP ${canResumeData.resume_from_step}から`);

                // UIにコンテキストを復元
                restoreUIFromContext(processRecord.context);

                return {
                    record: processRecord,
                    resumeFromStep: canResumeData.resume_from_step,
                    resumeStepName: canResumeData.resume_step_name
                };
            }
        }
        throw new Error('プロセス取得失敗');
    } catch (e) {
        console.error('❌ プロセス再開エラー:', e);
        throw e;
    }
}

/**
 * コンテキストを部分更新
 * @param {object} partialContext - 更新するコンテキスト
 * @returns {Promise<object>} 更新後のProcessRecord
 */
async function updateProcessContext(partialContext) {
    if (!processRecord) {
        console.warn('⚠️ プロセスが存在しません');
        return null;
    }
    try {
        const response = await fetch(`/api/process/${processRecord.record_id}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(partialContext)
        });
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                processRecord = data.record;
                console.log('✅ コンテキスト更新:', processRecord.record_id);
                return processRecord;
            }
        }
    } catch (e) {
        console.error('❌ コンテキスト更新エラー:', e);
    }
    return processRecord;
}

/**
 * ステップ状態を更新
 * @param {number} step - ステップ番号
 * @param {string} status - ステータス (pending, running, success, error, skipped)
 * @param {object} options - オプション（result, error）
 * @returns {Promise<object>} 更新後のProcessRecord
 */
async function updateStepStatus(step, status, options = {}) {
    if (!processRecord) {
        console.warn('⚠️ プロセスが存在しません');
        return null;
    }
    try {
        const body = {
            step,
            status,
            result: options.result || null
        };

        // エラー情報の構築
        if (options.error) {
            body.error = {
                code: options.errorCode || 'UNKNOWN',
                message: typeof options.error === 'string' ? options.error : options.error.message,
                recoverable: options.recoverable !== false,
                suggested_action: options.suggestedAction || null
            };
        }

        const response = await fetch(`/api/process/${processRecord.record_id}/step`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                processRecord = data.record;
                console.log(`✅ STEP${step} → ${status}`);
                return processRecord;
            }
        }
    } catch (e) {
        console.error('❌ ステップ更新エラー:', e);
    }
    return processRecord;
}

/**
 * ログを追加
 * @param {string} message - ログメッセージ
 * @param {object} options - オプション（level, step, data）
 */
async function addLog(message, options = {}) {
    if (!processRecord) return;

    try {
        await fetch(`/api/process/${processRecord.record_id}/log`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                level: options.level || 'info',
                step: options.step || null,
                message,
                data: options.data || null
            })
        });
    } catch (e) {
        console.warn('ログ追加エラー:', e);
    }
}

/**
 * プロセスを中断
 * @param {string} reason - 中断理由
 * @param {string} errorCode - エラーコード
 */
async function interruptProcess(reason, errorCode = null) {
    if (!processRecord) return;

    try {
        const response = await fetch(`/api/process/${processRecord.record_id}/interrupt`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ reason, error_code: errorCode })
        });
        if (response.ok) {
            const data = await response.json();
            processRecord = data.record;
            console.log('⚠️ プロセス中断:', reason);
        }
    } catch (e) {
        console.error('❌ 中断処理エラー:', e);
    }
}

/**
 * コンテキストからUIを復元（プロジェクト固有の実装が必要）
 * @param {object} context - ProcessRecordのcontext
 */
function restoreUIFromContext(context) {
    if (!context) return;

    // 例: IDフィールドの復元
    // if (context.site_id) {
    //     document.getElementById('input-site-id').value = context.site_id;
    // }

    console.log('✅ UIを復元しました');
}

/**
 * 現在のUI状態をコンテキストに保存（プロジェクト固有の実装が必要）
 * @returns {Promise<object>} 更新後のProcessRecord
 */
async function saveUIToContext() {
    if (!processRecord) return null;

    const context = {
        // 例: フォームからの値収集
        // site_id: parseInt(document.getElementById('input-site-id')?.value) || null,
    };

    return await updateProcessContext(context);
}
```

## 2. 未完了プロセス検出・再開UI

### CSS

```css
/* プロセス再開バナー */
.resume-banner {
    display: none;
    background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
    border: 2px solid #ff9800;
    border-radius: 8px;
    padding: 12px 16px;
    margin-bottom: 15px;
    position: relative;
}
.resume-banner.active {
    display: block;
}
.resume-banner-title {
    font-weight: bold;
    color: #e65100;
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    gap: 8px;
}
.resume-banner-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
}
.resume-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: white;
    padding: 10px 12px;
    border-radius: 6px;
    border: 1px solid #ffcc80;
}
.resume-item-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
}
.resume-item-step {
    font-size: 0.85em;
    color: #666;
}
.resume-item-reason {
    font-size: 0.8em;
    color: #d32f2f;
    margin-top: 2px;
}
.resume-item-btn {
    background: #ff9800;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9em;
    transition: background 0.2s;
}
.resume-item-btn:hover {
    background: #f57c00;
}
.resume-item-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
}
.resume-banner-close {
    position: absolute;
    top: 8px;
    right: 8px;
    background: none;
    border: none;
    font-size: 1.2em;
    cursor: pointer;
    color: #999;
}
.resume-banner-close:hover {
    color: #666;
}
```

### HTML

```html
<!-- プロセス再開バナー -->
<div class="resume-banner" id="resume-banner">
    <button class="resume-banner-close" onclick="closeResumeBanner()">&times;</button>
    <div class="resume-banner-title">
        <span>⚠️</span>
        <span>未完了のプロセスがあります</span>
    </div>
    <div class="resume-banner-list" id="resume-list">
        <!-- JavaScriptで動的に生成 -->
    </div>
</div>
```

### JavaScript

```javascript
/**
 * 未完了プロセスを確認して表示
 */
async function checkIncompleteProcesses() {
    try {
        const response = await fetch('/api/process/incomplete/list');
        if (!response.ok) return;

        const data = await response.json();
        if (!data.success || data.count === 0) return;

        const listEl = document.getElementById('resume-list');
        listEl.innerHTML = '';

        data.processes.forEach(proc => {
            const item = document.createElement('div');
            item.className = 'resume-item';

            // 中断理由に応じたメッセージ
            let reasonHtml = '';
            if (proc.interrupt_reason) {
                reasonHtml = `<div class="resume-item-reason">⚠️ ${proc.interrupt_reason}</div>`;
            }

            // 再開可能かどうかでボタンを変える
            const canResume = !proc.error_info || proc.error_info.recoverable !== false;
            const btnDisabled = canResume ? '' : 'disabled';
            const btnText = canResume ? '再開' : '再開不可';

            item.innerHTML = `
                <div class="resume-item-info">
                    <div><strong>${proc.context_summary?.name || proc.record_id}</strong></div>
                    <div class="resume-item-step">STEP ${proc.current_step}: ${proc.current_step_name}</div>
                    ${reasonHtml}
                </div>
                <button class="resume-item-btn" ${btnDisabled} onclick="handleResume('${proc.record_id}')">
                    ${btnText}
                </button>
            `;
            listEl.appendChild(item);
        });

        document.getElementById('resume-banner').classList.add('active');
    } catch (e) {
        console.warn('未完了プロセス確認エラー:', e);
    }
}

/**
 * 再開ボタンクリック時の処理
 */
async function handleResume(recordId) {
    try {
        const result = await resumeProcess(recordId);
        closeResumeBanner();

        // 通知表示
        showNotification(`STEP ${result.resumeFromStep}（${result.resumeStepName}）から再開します`, 'info');

        // 再開処理を実行（プロジェクト固有の実装）
        // executeFromStep(result.resumeFromStep);
    } catch (e) {
        showNotification('再開に失敗しました: ' + e.message, 'error');
    }
}

/**
 * 再開バナーを閉じる
 */
function closeResumeBanner() {
    document.getElementById('resume-banner').classList.remove('active');
}

// ページ読み込み時に未完了プロセスを確認
document.addEventListener('DOMContentLoaded', () => {
    checkIncompleteProcesses();
});
```

## 3. ステップ実行テンプレート

```javascript
/**
 * ステップ実行のテンプレート
 * @param {number} stepNumber - ステップ番号
 * @param {string} stepName - ステップ名（UI表示用）
 * @param {function} executor - 実際の処理を行う非同期関数
 * @param {object} options - オプション（retryCount, timeout, onError）
 */
async function executeStep(stepNumber, stepName, executor, options = {}) {
    const { retryCount = 0, timeout = 60000, onError = null } = options;

    // ステップ開始
    updateProgress(stepNumber, `${stepName}...`);
    await updateStepStatus(stepNumber, 'running');
    await addLog(`${stepName}を開始`, { step: stepNumber });

    try {
        // タイムアウト付き実行
        const result = await Promise.race([
            executor(),
            new Promise((_, reject) =>
                setTimeout(() => reject(new Error('タイムアウト')), timeout)
            )
        ]);

        // 成功
        await updateStepStatus(stepNumber, 'success', { result });
        await addLog(`${stepName}が完了`, { step: stepNumber, data: result });
        return result;

    } catch (error) {
        // エラー判定
        const errorCode = error.message.includes('タイムアウト') ? 'TIMEOUT' :
                          error.message.includes('network') ? 'NETWORK_ERROR' :
                          'UNKNOWN';

        const recoverable = ['TIMEOUT', 'NETWORK_ERROR'].includes(errorCode);

        await updateStepStatus(stepNumber, 'error', {
            error: error.message,
            errorCode,
            recoverable,
            suggestedAction: recoverable ? '再実行してください' : null
        });

        await addLog(`${stepName}でエラー: ${error.message}`, {
            level: 'error',
            step: stepNumber,
            data: { errorCode }
        });

        // カスタムエラーハンドラがあれば実行
        if (onError) {
            await onError(error, stepNumber);
        }

        throw error;
    }
}

// 使用例
async function runProcess() {
    try {
        // プロセス作成
        await createProcess({ name: 'サンプル処理' });

        // STEP 1
        const step1Result = await executeStep(1, 'データ取得', async () => {
            const response = await fetch('/api/data');
            return await response.json();
        }, { timeout: 30000 });

        // STEP 2
        await executeStep(2, 'データ処理', async () => {
            return processData(step1Result);
        });

        // STEP 3
        await executeStep(3, '結果保存', async () => {
            await saveResults();
            return { saved: true };
        });

        showNotification('処理が完了しました', 'success');

    } catch (error) {
        showNotification(`エラー: ${error.message}`, 'error');
    }
}
```

## 4. ブラウザリロード/クローズ対策

```javascript
// ページを離れる前の確認
window.addEventListener('beforeunload', (e) => {
    if (processRecord && processRecord.status === 'running') {
        // 中断を記録（同期的に送信）
        navigator.sendBeacon(
            `/api/process/${processRecord.record_id}/interrupt`,
            JSON.stringify({
                reason: 'ブラウザが閉じられました',
                error_code: 'BROWSER_CLOSE'
            })
        );

        // 確認ダイアログ表示
        e.preventDefault();
        e.returnValue = '処理中です。ページを離れると中断されます。';
    }
});

// ネットワーク切断検知
window.addEventListener('offline', async () => {
    if (processRecord && processRecord.status === 'running') {
        await addLog('ネットワーク切断を検知', { level: 'warn' });
        showNotification('ネットワーク接続が切断されました', 'warning');
    }
});

// ネットワーク復帰検知
window.addEventListener('online', async () => {
    if (processRecord) {
        await addLog('ネットワーク復帰', { level: 'info' });
        showNotification('ネットワーク接続が復帰しました', 'info');
    }
});
```
