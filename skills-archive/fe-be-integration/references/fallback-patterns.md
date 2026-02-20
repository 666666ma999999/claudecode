# フォールバック実装パターン

## 1. 基本パターン: API優先、ローカルフォールバック

```javascript
/**
 * API優先でデータを取得、失敗時はローカル処理にフォールバック
 * @param {any} input - 入力データ
 * @returns {Promise<any>} 処理結果
 */
async function processWithFallback(input) {
    // まずBE APIを試す
    try {
        const response = await fetch('/api/process', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content: input })
        });

        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                console.log('✅ BE API使用');
                return data.result;
            }
            // API成功だがビジネスロジックエラー
            console.warn('⚠️ APIビジネスエラー:', data.error);
        }
    } catch (e) {
        console.warn('⚠️ API通信エラー:', e.message);
    }

    // フォールバック: ローカル処理
    console.log('📝 ローカル処理にフォールバック');
    return processLocal(input);
}
```

## 2. 設定読み込みパターン

```javascript
// グローバル設定変数
let APP_CONFIG = null;
let CONFIG_LOADED = false;

/**
 * 設定を読み込む（API優先、キャッシュ付き）
 */
async function loadAppConfig() {
    if (CONFIG_LOADED && APP_CONFIG) {
        return APP_CONFIG;
    }

    try {
        // 1. APIから取得を試みる
        const response = await fetch('/api/config');
        if (response.ok) {
            APP_CONFIG = await response.json();
            CONFIG_LOADED = true;
            console.log('✅ 設定をAPIから読み込み');
            return APP_CONFIG;
        }
    } catch (e) {
        console.warn('⚠️ API設定取得エラー:', e);
    }

    try {
        // 2. 静的ファイルから取得を試みる
        const staticResponse = await fetch('/data/app-config.json');
        if (staticResponse.ok) {
            APP_CONFIG = await staticResponse.json();
            CONFIG_LOADED = true;
            console.log('✅ 設定を静的ファイルから読み込み');
            return APP_CONFIG;
        }
    } catch (e) {
        console.warn('⚠️ 静的ファイル取得エラー:', e);
    }

    // 3. デフォルト値を使用
    console.log('📝 デフォルト設定を使用');
    APP_CONFIG = getDefaultConfig();
    CONFIG_LOADED = true;
    return APP_CONFIG;
}

/**
 * デフォルト設定（ハードコード）
 */
function getDefaultConfig() {
    return {
        types: {
            type_a: { name: 'タイプA', code: 'A' },
            type_b: { name: 'タイプB', code: 'B' },
        },
        limits: {
            max_items: 100,
        }
    };
}
```

## 3. 同期/非同期ラッパーパターン

```javascript
/**
 * 非同期版（API使用）
 */
async function parseDataAsync(content) {
    const apiResult = await callParseAPI(content);
    if (apiResult.success) {
        return apiResult.data;
    }
    return parseDataLocal(content);
}

/**
 * 同期版（後方互換用、ローカル処理のみ）
 */
function parseData(content) {
    // 同期版は常にローカル処理
    return parseDataLocal(content);
}

/**
 * ローカル処理（純粋関数）
 */
function parseDataLocal(content) {
    // 実際のパースロジック
    const lines = content.split('\n');
    return lines.map((line, idx) => ({
        index: idx,
        text: line.trim()
    }));
}

/**
 * API呼び出し
 */
async function callParseAPI(content) {
    try {
        const response = await fetch('/api/parse', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content })
        });
        if (response.ok) {
            return await response.json();
        }
    } catch (e) {
        console.warn('Parse API error:', e);
    }
    return { success: false };
}
```

## 4. バリデーションフォールバックパターン

```javascript
/**
 * バリデーション（API優先）
 * @param {object} data - バリデーション対象
 * @returns {Promise<object>} { valid, errors, warnings, correctedValues }
 */
async function validateData(data) {
    // BE APIでバリデーション
    const apiResult = await validateViaAPI(data);
    if (apiResult) {
        // 自動修正値があればログ出力
        if (apiResult.corrected_values) {
            for (const [field, value] of Object.entries(apiResult.corrected_values)) {
                console.log(`📝 自動修正: ${field} → ${value}`);
            }
        }
        return {
            valid: apiResult.valid,
            errors: apiResult.errors || [],
            warnings: apiResult.warnings || [],
            correctedValues: apiResult.corrected_values || {}
        };
    }

    // フォールバック: ローカルバリデーション
    return validateLocal(data);
}

async function validateViaAPI(data) {
    try {
        const response = await fetch('/api/validate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        if (response.ok) {
            return await response.json();
        }
    } catch (e) {
        console.warn('Validation API error:', e);
    }
    return null;
}

function validateLocal(data) {
    const errors = [];
    const warnings = [];

    // 基本的なバリデーションのみ
    if (data.required_field !== undefined && !data.required_field) {
        errors.push({ field: 'required_field', message: '必須項目です' });
    }

    return {
        valid: errors.length === 0,
        errors,
        warnings,
        correctedValues: {}
    };
}
```

## 5. リトライ付きフォールバック

```javascript
/**
 * リトライ付きAPI呼び出し
 * @param {function} apiFn - API呼び出し関数
 * @param {number} maxRetries - 最大リトライ回数
 * @param {number} baseDelay - 基本遅延（ms）
 */
async function withRetry(apiFn, maxRetries = 3, baseDelay = 1000) {
    let lastError;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            return await apiFn();
        } catch (e) {
            lastError = e;
            if (attempt < maxRetries - 1) {
                // 指数バックオフ
                const delay = baseDelay * Math.pow(2, attempt);
                console.log(`リトライ ${attempt + 1}/${maxRetries}、${delay}ms後...`);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }

    throw lastError;
}

// 使用例
async function fetchWithRetryAndFallback(url, fallbackFn) {
    try {
        return await withRetry(async () => {
            const response = await fetch(url);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            return await response.json();
        });
    } catch (e) {
        console.warn('リトライ失敗、フォールバック実行:', e);
        return fallbackFn();
    }
}
```

## 6. 初期化時の設定適用パターン

```javascript
// グローバル変数（初期値）
let TYPES = {
    type_a: { name: 'タイプA', code: 'A' },
    type_b: { name: 'タイプB', code: 'B' },
};

// 即時実行関数で設定を上書き
(async function initializeConfig() {
    try {
        const config = await loadAppConfig();
        if (config.types) {
            // BE設定でローカル変数を上書き
            TYPES = {};
            for (const [key, value] of Object.entries(config.types)) {
                TYPES[key] = {
                    name: value.name,
                    code: value.code,
                    // FE固有のプロパティを追加
                    cssClass: `type-${key}`
                };
            }
            console.log('✅ 設定をBEから適用:', Object.keys(TYPES).length, '件');
        }
    } catch (e) {
        console.warn('⚠️ 設定適用エラー、デフォルト使用:', e);
    }
})();
```

## 7. フォールバック廃止パターン（成熟段階）

API安定化後、フォールバックを完全廃止しBEを唯一のソースにするパターン。

**前提条件**:
- APIが3ヶ月以上安定稼働
- フォールバック発動ログがゼロ
- BEダウン時のFE停止が許容される

```javascript
// 設定ローダー: フォールバック廃止版
let APP_CONFIG = null;
let CONFIG_LOAD_ERROR = null;

async function loadAppConfig() {
    if (APP_CONFIG) return APP_CONFIG;

    try {
        // 1. 静的ファイルから試す（キャッシュ対応）
        const staticResponse = await fetch('/data/app-config.json', { cache: 'no-store' });
        if (staticResponse.ok) {
            APP_CONFIG = await staticResponse.json();
            console.log('✅ 設定を静的ファイルから読み込み');
            return APP_CONFIG;
        }
    } catch (e) { /* continue */ }

    try {
        // 2. APIから試す
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
 */
function isConfigLoaded() {
    return APP_CONFIG !== null;
}

/**
 * 設定を必須として取得（未読み込み時はエラー）
 */
function getRequiredConfig() {
    if (!APP_CONFIG) {
        alert('設定が読み込まれていません。ページをリロードしてください。');
        throw new Error('CONFIG_NOT_LOADED');
    }
    return APP_CONFIG;
}
```

**ハードコード値の設定参照化**:
```javascript
// ❌ Before: ハードコード
const defaultPrice = 2000;
const maxSiteId = 999;

// ✅ After: 設定参照
const config = getRequiredConfig();
const defaultPrice = config.registration.default_price;
const maxSiteId = config.registration.site_id_range.max;
```

**UI初期化の設定依存化**:
```javascript
// 設定読み込み完了後にUI初期化
async function initializeUI() {
    try {
        await loadAppConfig();
        const config = getRequiredConfig();

        // UI要素の初期化
        document.getElementById('max-id-hint').textContent =
            `(1-${config.registration.site_id_range.max})`;
        document.getElementById('default-price').value =
            config.registration.default_price;
    } catch (e) {
        document.body.innerHTML = `
            <div class="error-box">
                ⚠️ 設定の読み込みに失敗しました<br>
                <small>サーバーが起動していることを確認してください</small>
            </div>`;
    }
}

document.addEventListener('DOMContentLoaded', initializeUI);
```

## 8. エラーハンドリングパターン

```javascript
/**
 * 統一エラーハンドラー
 */
function handleAPIError(error, context) {
    // ネットワークエラー
    if (error instanceof TypeError && error.message.includes('fetch')) {
        console.error(`[${context}] ネットワークエラー:`, error.message);
        return { type: 'network', recoverable: true };
    }

    // タイムアウト
    if (error.name === 'AbortError') {
        console.error(`[${context}] タイムアウト`);
        return { type: 'timeout', recoverable: true };
    }

    // サーバーエラー
    if (error.status >= 500) {
        console.error(`[${context}] サーバーエラー:`, error.status);
        return { type: 'server', recoverable: true };
    }

    // クライアントエラー
    if (error.status >= 400) {
        console.error(`[${context}] クライアントエラー:`, error.status);
        return { type: 'client', recoverable: false };
    }

    // 不明なエラー
    console.error(`[${context}] 不明なエラー:`, error);
    return { type: 'unknown', recoverable: false };
}
```
