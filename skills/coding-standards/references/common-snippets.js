/**
 * 共通コードスニペット集（JavaScript/Frontend）
 * =============================================
 * 新規プロジェクトでこれらのパターンが必要な場合、
 * このファイルからコピーして使用すること。
 */

// =============================================================================
// 1. API呼び出しラッパー
// =============================================================================
// 用途: 認証トークン付きAPI呼び出し、エラーハンドリング統一
// 配置先: frontend/utils/api.js または frontend/script.js

/**
 * API呼び出しラッパー
 * @param {string} path - APIパス（例: '/api/users'）
 * @param {object} options - fetchオプション
 * @param {string} options.method - HTTPメソッド
 * @param {object} options.body - リクエストボディ（自動でJSON.stringify）
 * @param {object} options.headers - 追加ヘッダー
 * @returns {Promise<any>} レスポンスJSON
 * @throws {Error} API失敗時
 */
async function apiRequest(path, options = {}) {
    const { method = 'GET', body, headers = {} } = options;

    const config = {
        method,
        headers: {
            'Content-Type': 'application/json',
            'x-api-token': API_TOKEN,  // グローバル認証トークン
            ...headers
        }
    };

    if (body && method !== 'GET') {
        config.body = JSON.stringify(body);
    }

    const response = await fetch(path, config);

    if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || `API Error: ${response.status}`);
    }

    return response.json();
}


// =============================================================================
// 2. 進捗表示クラス
// =============================================================================
// 用途: 長時間API呼び出し時の進捗アニメーション
// 配置先: frontend/utils/progress.js または frontend/script.js

/**
 * 進捗アニメーション管理クラス
 */
class ProgressAnimator {
    /**
     * @param {HTMLElement} button - 更新するボタン要素
     * @param {number} totalSteps - 総ステップ数
     * @param {number} secondsPerStep - 1ステップあたりの推定秒数
     * @param {string} prefix - 表示テキストのプレフィックス
     */
    constructor(button, totalSteps, secondsPerStep, prefix = '処理中') {
        this.button = button;
        this.totalSteps = totalSteps;
        this.secondsPerStep = secondsPerStep;
        this.prefix = prefix;
        this.currentStep = 0;
        this.intervalId = null;
        this.originalText = button?.textContent || '';
    }

    start() {
        if (!this.button) return;

        this.button.disabled = true;
        this.currentStep = 0;

        this.intervalId = setInterval(() => {
            this.currentStep = Math.min(this.currentStep + 1, this.totalSteps);
            const percent = Math.round((this.currentStep / this.totalSteps) * 100);
            this.button.textContent = `${this.prefix}... ${percent}%`;
        }, this.secondsPerStep * 1000);
    }

    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        if (this.button) {
            this.button.disabled = false;
            this.button.textContent = this.originalText;
        }
    }
}


// =============================================================================
// 3. Async Wrapperパターン
// =============================================================================
// 用途: 同期関数をAPI呼び出しに置き換え、フォールバック付き
// 配置先: 該当機能のファイル

/**
 * API優先、フォールバック付き処理のテンプレート
 * @param {any} input - 入力データ
 * @returns {Promise<any>} 処理結果
 */
async function processWithFallbackTemplate(input) {
    if (!input) return null;

    try {
        const response = await fetch('/api/process', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-token': API_TOKEN
            },
            body: JSON.stringify({ input })
        });

        if (response.ok) {
            const result = await response.json();
            if (result.success) {
                return result.data;
            }
            console.error('❌ API失敗:', result.error);
        }
    } catch (error) {
        console.error('❌ API例外:', error);
    }

    // フォールバック: ローカル関数を使用
    console.warn('⚠️ フォールバック: ローカル関数で処理');
    return processLocalTemplate(input);
}

/**
 * @deprecated processWithFallbackTemplate()を使用してください
 */
function processLocalTemplate(input) {
    // ローカル処理（フォールバック用）
    return input;
}


// =============================================================================
// 4. 設定読み込み（フォールバック廃止版）
// =============================================================================
// 用途: BE設定を必須として読み込み
// 配置先: frontend/config.js

let APP_CONFIG = null;
let CONFIG_LOAD_ERROR = null;

/**
 * アプリケーション設定を読み込み
 * @returns {Promise<object>} 設定オブジェクト
 * @throws {Error} 読み込み失敗時
 */
async function loadAppConfig() {
    if (APP_CONFIG) return APP_CONFIG;

    // 静的ファイルから試す
    try {
        const staticResponse = await fetch('/data/app-config.json', { cache: 'no-store' });
        if (staticResponse.ok) {
            APP_CONFIG = await staticResponse.json();
            console.log('✅ 設定を静的ファイルから読み込み');
            return APP_CONFIG;
        }
    } catch (e) { /* continue */ }

    // APIから試す
    try {
        const response = await fetch('/api/config', { cache: 'no-store' });
        if (response.ok) {
            APP_CONFIG = await response.json();
            console.log('✅ 設定をAPIから読み込み');
            return APP_CONFIG;
        }
    } catch (e) { /* continue */ }

    // フォールバックなし: エラーをスロー
    CONFIG_LOAD_ERROR = new Error('設定読み込み失敗。サーバー起動を確認してください。');
    throw CONFIG_LOAD_ERROR;
}

/**
 * 設定が読み込まれているかチェック
 * @returns {boolean}
 */
function isConfigLoaded() {
    return APP_CONFIG !== null;
}

/**
 * 設定を必須として取得
 * @returns {object} 設定オブジェクト
 * @throws {Error} 未読み込み時
 */
function getRequiredConfig() {
    if (!APP_CONFIG) {
        alert('設定が読み込まれていません。ページをリロードしてください。');
        throw new Error('CONFIG_NOT_LOADED');
    }
    return APP_CONFIG;
}


// =============================================================================
// 5. 通知表示
// =============================================================================
// 用途: ユーザーへの通知メッセージ表示
// 配置先: frontend/utils/notification.js

/**
 * 通知を表示
 * @param {string} message - メッセージ
 * @param {string} type - 通知タイプ ('success' | 'warning' | 'error' | 'info')
 * @param {number} duration - 表示時間（ms）、0で自動消去なし
 */
function showNotification(message, type = 'info', duration = 3000) {
    // 既存の通知を削除
    const existing = document.querySelector('.notification');
    if (existing) existing.remove();

    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 12px 20px;
        border-radius: 8px;
        color: white;
        font-weight: bold;
        z-index: 10000;
        animation: slideIn 0.3s ease;
    `;

    const colors = {
        success: '#4CAF50',
        warning: '#ff9800',
        error: '#f44336',
        info: '#2196F3'
    };
    notification.style.backgroundColor = colors[type] || colors.info;

    document.body.appendChild(notification);

    if (duration > 0) {
        setTimeout(() => notification.remove(), duration);
    }
}
