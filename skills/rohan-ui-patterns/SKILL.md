---
name: rohan-ui-patterns
description: |
  Rohanプロジェクト専用のUI実装パターン集。新機能追加時に既存の関数・パターンを再利用するためのガイド。
  以下の場面で使用:
  (1) ドラッグ&ドロップファイル入力の実装
  (2) 進捗表示付きの長時間API呼び出し
  (3) 複数候補からの選択UI
  (4) AI生成結果の保持→後続処理での使用
  (5) 新しいセクション・フォームの追加
  キーワード: ドラッグ&ドロップ, 進捗表示, ProgressAnimator, ingestFiles, attachedFiles, セクション追加, 生成結果保持, グローバル変数
---

# Rohan UI実装パターン

Rohanプロジェクトで新機能を追加する際の実装パターン集。**既存関数を最大限活用**すること。

## 1. ドラッグ&ドロップファイル入力

### 必須条件
- グローバルハンドラー（`setupGlobalDragAndDrop`）が`.dropzone`クラスを許可していること
- `setupEventHandlers`関数内でイベントリスナーを設定すること

### 実装手順

**HTML:**
```html
<div class="file-upload-area dropzone" id="my-dropzone">
    <input type="file" id="my-file-input" accept=".txt" class="hidden-input">
    <div class="dropzone-content">
        <span class="dropzone-icon">📄</span>
        <span class="dropzone-text">ここにファイルをドラッグ&ドロップ</span>
        <span class="dropzone-or">または</span>
        <button class="btn file-button" onclick="document.getElementById('my-file-input').click()">ファイル選択</button>
    </div>
    <div id="attached-files-list-my-section" class="attached-files-list"></div>
</div>
```

**JavaScript（setupEventHandlers関数内に追加）:**
```javascript
// attachedFilesセクション初期化（グローバルスコープ）
window.attachedFiles['my-section'] = [];

// setupEventHandlers関数内に以下を追加
const myDropZone = document.getElementById('my-dropzone');
if (myDropZone) {
    myDropZone.addEventListener('dragover', function(e) {
        e.preventDefault();
        e.stopPropagation();
        this.style.borderColor = '#4CAF50';
        this.style.backgroundColor = '#f0fff0';
    });
    myDropZone.addEventListener('dragleave', function(e) {
        e.preventDefault();
        e.stopPropagation();
        this.style.borderColor = '#ccc';
        this.style.backgroundColor = '';
    });
    myDropZone.addEventListener('drop', function(e) {
        e.preventDefault();
        e.stopPropagation();
        this.style.borderColor = '#ccc';
        this.style.backgroundColor = '';
        window.attachedFiles['my-section'] = [];
        document.getElementById('attached-files-list-my-section').innerHTML = '';
        ingestFiles(e.dataTransfer.files, 'my-section', 'drag');
    });
}
```

**ファイル内容取得:**
```javascript
function getMyFileContent() {
    const files = window.attachedFiles['my-section'] || [];
    return files.length > 0 ? files.map(f => f.content).join('\n') : null;
}
```

### ingestFiles関数の機能（v1.23.13更新）

`ingestFiles`関数は以下の機能を提供:
- **重複チェック**: 同名ファイルは自動スキップ
- **セクション除外**: `opening-closing`セクションでは「あいさつ」「メッセージ」「導入」ファイルを自動除外
- **ファイルタイプ判定**: `isTextFile()`/`isImageFile()`で自動分類

```javascript
// ingestFilesの使用例
await ingestFiles(files, 'my-section', 'drag');
// → 重複ファイルは自動スキップ
// → テキスト/画像ファイルを自動分類
```

### ダウンロード関数（v1.23.13追加）

ファイルダウンロードは`utils.js`の共通関数を使用:
```javascript
// テキストファイルダウンロード
downloadTextFile(content, 'filename.txt');

// Blobダウンロード（ZIP等）
downloadBlob(zipBlob, 'archive.zip');
```

## 2. 進捗表示付きAPI呼び出し

### 既存クラス: ProgressAnimator

```javascript
// 使用例
const progressAnimator = new ProgressAnimator(
    buttonElement,      // 更新するボタン要素
    totalSteps,         // 総ステップ数
    secondsPerStep,     // 1ステップあたりの推定秒数
    'プレフィックス'     // 表示テキスト（例: '生成中'）
);

progressAnimator.start();  // 開始
// ... API呼び出し ...
progressAnimator.stop();   // 停止（finallyブロックで）
```

### 完全な実装例

```javascript
async function myLongProcess() {
    const button = document.getElementById('my-button');
    const container = document.getElementById('my-container');
    const itemCount = 5;
    const secondsPerItem = 40;

    // 進捗表示開始
    const progressAnimator = new ProgressAnimator(button, itemCount, secondsPerItem, '処理中');
    progressAnimator.start();

    // 画面の進捗テキストも更新
    container.innerHTML = '<p class="loading-text" id="my-progress">処理中...</p>';
    const progressText = document.getElementById('my-progress');
    const progressInterval = setInterval(() => {
        if (progressText) {
            progressText.innerHTML = `処理中... <strong>(${progressAnimator.currentStep}/${itemCount})</strong>`;
        }
    }, 1000);

    try {
        const data = await apiRequest('/api/my-endpoint', {
            method: 'POST',
            body: { count: itemCount }
        });
        // 成功処理
        renderResults(data);
    } catch (error) {
        container.innerHTML = `<p style="color: red;">エラー: ${error.message}</p>`;
    } finally {
        progressAnimator.stop();
        clearInterval(progressInterval);
        button.textContent = '実行';
        button.disabled = false;
    }
}
```

## 3. 複数候補選択UI

### HTML構造
```html
<div id="candidates-container" class="product-candidates-container">
    <!-- 動的に生成 -->
</div>
<div class="button-row" id="actions" style="display: none;">
    <button onclick="copySelected()">選択した候補をコピー</button>
</div>
```

### JavaScript
```javascript
// グローバル変数で候補データを保持
window.myCandidates = [];

function renderCandidates(candidates) {
    window.myCandidates = candidates;
    const container = document.getElementById('candidates-container');
    container.innerHTML = candidates.map((c, i) => `
        <div class="product-candidate">
            <div class="candidate-header">
                <input type="checkbox" id="candidate-${i}" class="candidate-checkbox" data-index="${i}">
                <label for="candidate-${i}">候補 ${i + 1}</label>
            </div>
            <div class="candidate-content">${c.title}</div>
        </div>
    `).join('');
    document.getElementById('actions').style.display = 'flex';
}

function copySelected() {
    const checked = document.querySelectorAll('.candidate-checkbox:checked');
    const selected = Array.from(checked).map(cb => window.myCandidates[cb.dataset.index]);
    // 処理...
}
```

## 4. AI生成結果の保持→後続処理使用パターン

### 概要
AI生成機能（レコメンド、自動補完等）の結果を保持し、後続の登録処理で使用するパターン。

### 実装構造

```javascript
// 1. グローバル変数で結果を保持
let myGeneratedResult = null;

// 2. 生成API呼び出し＆結果保持
async function generateMyData() {
    const response = await apiRequest('/api/my-generate', {
        method: 'POST',
        body: { input: someInput }
    });
    myGeneratedResult = response;  // グローバルに保持
    displayMyResult(response);     // 即座に表示
}

// 3. 表示関数
function displayMyResult(result) {
    const el = document.getElementById('my-result-inline');
    if (result && result.success) {
        el.style.display = 'block';
        el.innerHTML = `
            <span class="label">生成結果</span>
            <div>${result.field1} / ${result.field2}</div>
        `;
    } else {
        el.style.display = 'none';
    }
}

// 4. 後続処理で使用（★重要：初回呼び出しとretry両方で参照）
async function registerData() {
    const body = {
        // 通常のフィールド
        title: document.getElementById('title').value,
        // 生成結果を参照
        generated_field1: myGeneratedResult?.success ? myGeneratedResult.field1 : null,
        generated_field2: myGeneratedResult?.success ? myGeneratedResult.field2 : null,
    };
    await apiRequest('/api/register', { method: 'POST', body });
}

// 5. リトライ関数でも同様に参照（★漏れやすいので注意）
async function retryRegister() {
    const body = {
        title: document.getElementById('title').value,
        // ★ここでも生成結果を参照することを忘れない
        generated_field1: myGeneratedResult?.success ? myGeneratedResult.field1 : null,
        generated_field2: myGeneratedResult?.success ? myGeneratedResult.field2 : null,
    };
    await apiRequest('/api/register', { method: 'POST', body });
}
```

### 重要：後続処理への統合チェックリスト

生成機能を追加した際、以下をすべて確認すること：

1. **初回登録処理**: 生成結果のフィールドがbodyに含まれているか
2. **リトライ処理**: retry関数にも同じフィールドが含まれているか
3. **手動編集モード**: 手動入力時も生成結果を使用する場合は対応しているか
4. **エラー時のフォールバック**: `myGeneratedResult?.success` で安全に参照しているか

### 4-B. Getter/Setter パターン（registrationRecord同期）

**概要**: グローバル変数への直接代入・読み取りをgetter/setter関数に置き換え、`registrationRecord`（セッション状態）と即時同期するパターン。セッション再開時にグローバル変数が消失する問題を根本解決する。

**対象変数（auto.html実装済み）**:

| 変数 | Getter | Setter | データソース |
|------|--------|--------|-------------|
| `komiTypeResult` | `getKomiTypeResult()` | `setKomiTypeResult(result)` | `registrationRecord.product.subtitles` |
| `yudoTxtResult` | `getYudoTxtResult()` | `setYudoTxtResult(result)` | `registrationRecord.distribution.yudo.txt` |
| `yudoRecommendResult` | `getYudoRecommendResult()` | `setYudoRecommendResult(result)` | `registrationRecord.distribution.yudo.ppv01` etc. |
| `komiRegeneratedResults` | `getKomiRegeneratedResults()` | `pushKomiRegeneratedResult(entry)` / `clearKomiRegeneratedResults()` | `registrationRecord.product.subtitles[].regenerated_text` |
| `categoryCodeResult` | `getCategoryCodeResult()` | `setCategoryCodeResult(result)` | `registrationRecord.distribution.category_code` |
| `guideResult` | `getGuideResult()` | `setGuideResult(result)` | `registrationRecord.distribution.guide_text` |
| `personTypeResult` | `getPersonTypeResult()` | `setPersonTypeResult(result)` | `registrationRecord.distribution.person_type` |

**Getter実装ルール**:
```javascript
// GetterはregistrationRecord優先、グローバル変数にフォールバック
function getMyResult() {
    if (registrationRecord?.path?.to?.data) {
        return { success: true, field: registrationRecord.path.to.data };
    }
    return myResult;  // グローバル変数（フォールバック）
}
```

**Setter実装ルール**:
```javascript
// Setterはグローバル変数 + registrationRecordを同時更新
function setMyResult(result) {
    myResult = result;
    // nullクリア時はregistrationRecordもクリア
    if (!result && registrationRecord?.path?.to) {
        registrationRecord.path.to.data = null;
    }
    if (registrationRecord?.path && result?.field) {
        registrationRecord.path.to.data = result.field;
    }
}
```

**重要な注意点**:

1. **Getterに`success`フィールドを含める**: display関数が`result.success`をチェックするため、getterで再構築する際に`success: true`を含めること
2. **Setterでnullクリア時にregistrationRecordもクリア**: `setMyResult(null)`でregistrationRecordの対応データもクリアしないと、getterが古いデータを返す
3. **配列型のclearer**: `komiRegeneratedResults`のような配列は`clearKomiRegeneratedResults()`でregistrationRecordの各エントリもクリアする
4. **セッション復元時はsetterを使用**: `restoreFromSession()`内で直接代入せずsetterを経由し、registrationRecordとの一貫性を保つ

**移行チェックリスト**:
- [ ] 全てのグローバル変数代入箇所をsetterに置換
- [ ] 全てのグローバル変数読み取り箇所をgetterに置換
- [ ] `restoreFromSession()`内の代入をsetterに変更
- [ ] display関数呼び出し時にgetterから取得した値を渡す
- [ ] nullクリア（`= null`、`= []`）もsetter/clearerを使用

**よくある漏れ:**
- 初回処理には追加したがretry関数に追加し忘れる
- 複数の登録経路がある場合に一部のみ対応

## 5. 新セクション追加チェックリスト

1. **HTML** (`frontend/index.html`)
   - `<div class="input-section" id="sec-xxx">` または `<div class="output-section" id="sec-xxx">`
   - `attached-files-list-xxx`（ファイル添付がある場合）

2. **JavaScript** (`frontend/script.js`)
   - `window.attachedFiles['xxx'] = []`（グローバルスコープ）
   - イベントリスナーは`setupEventHandlers`関数内に追加
   - 既存関数を使用: `ingestFiles`, `apiRequest`, `showNotification`, `ProgressAnimator`

3. **CSS** (`frontend/styles.css`)
   - `.dropzone`関連スタイルは既存のものを使用

4. **バックエンド** (`backend/routers/xxx.py`)
   - `main.py`にimportとinclude_router追加
   - `set_dependencies`関数を定義
   - 既存の`call_gemini_with_fallback`を使用

5. **バージョン履歴** (`frontend/data/VERSION_HISTORY.md`)
   - 機能追加を記録

## 重要な既存関数

| 関数名 | 用途 | ファイル |
|--------|------|----------|
| `ingestFiles(files, section, source)` | ファイル読み込み・添付 | script.js |
| `apiRequest(path, options)` | API呼び出し | script.js |
| `showNotification(msg, type)` | 通知表示 | script.js |
| `ProgressAnimator` | 進捗表示 | script.js |
| `readTextFile(file)` | テキストファイル読み込み（API経由） | utils.js |
| `call_gemini_with_fallback` | Gemini API呼び出し | gemini_helpers.py |
| `loadAppConfig()` | BE設定の動的読み込み | config.js |
| `validateRegistrationAPI()` | バリデーションAPI呼び出し | auto.html |

## 6. BE設定の動的読み込み（FE/BE統合）

### 概要
FE側の定数をBE APIから動的に取得し、ハードコードを削減するパターン。

### 実装パターン

**BE側（config.py）:**
```python
# 共有定数を一元管理
SHARED_CONSTANTS = {
    "types": {
        "type_a": {"name": "タイプA", "endpoint": "/api/a"},
        "type_b": {"name": "タイプB", "endpoint": "/api/b"},
    },
    "limits": {"max_items": 100}
}

@router.get("/api/config")
async def get_config():
    return SHARED_CONSTANTS
```

**FE側（初期化時に読み込み）:**
```javascript
// グローバル変数（初期値）
let MY_TYPES = {};

// 即時実行関数でBE設定を上書き
(async function initConfig() {
    try {
        const config = await loadAppConfig();  // config.js提供
        if (config.types) {
            MY_TYPES = {};
            for (const [key, value] of Object.entries(config.types)) {
                MY_TYPES[key] = {
                    name: value.name,
                    endpoint: value.endpoint
                };
            }
            console.log('✅ 設定をBEから適用');
        }
    } catch (e) {
        console.warn('⚠️ デフォルト設定を使用:', e);
    }
})();
```

### 適用場面
- FE/BE両方で同じ定数を使用している場合
- 定数の変更頻度が高い場合
- 定数の不整合バグを防ぎたい場合

## 7. API優先・フォールバック処理

### 概要
BE APIを優先的に使用し、失敗時はFEローカル処理にフォールバックするパターン。

### 実装パターン

```javascript
/**
 * API優先、フォールバック付き処理
 */
async function processWithFallback(input) {
    // 1. まずBE APIを試す
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
        }
    } catch (e) {
        console.warn('⚠️ APIエラー:', e);
    }

    // 2. フォールバック: ローカル処理
    console.log('📝 ローカル処理にフォールバック');
    return processLocal(input);
}

// 同期版ラッパー（後方互換用）
function processSync(input) {
    return processLocal(input);  // 同期版は常にローカル
}
```

### 適用場面
- パース処理のBE統合時
- バリデーション処理のBE統合時
- API障害時もFE単独で動作させたい場合

## 8. バリデーションAPI連携

### 概要
登録前バリデーションをBE APIで実行し、エラー/警告を分離して表示するパターン。

### BE側レスポンス形式

```json
{
    "valid": false,
    "errors": [
        {"field": "site_id", "message": "必須項目です"}
    ],
    "warnings": [
        {"field": "price", "message": "価格が低い可能性があります"}
    ],
    "corrected_values": {
        "site_id": "123"  // 全角→半角の自動修正
    }
}
```

### FE側実装

```javascript
async function executeRegistration() {
    // 入力値を収集
    const data = {
        site_id: document.getElementById('site-id').value,
        menu_name: document.getElementById('menu-name').value
    };

    // バリデーションAPI呼び出し
    const validation = await validateRegistrationAPI(data);

    // エラーがあれば中断
    if (!validation.valid) {
        const errorMsg = validation.errors.map(e => e.message).join('\n');
        showNotification(errorMsg, 'warning');
        return;
    }

    // 警告はログ出力（処理は継続）
    validation.warnings?.forEach(w => console.log(`⚠️ ${w.message}`));

    // 登録処理を続行...
}
```

### エラー/警告の分類基準

| 種別 | 例 | 処理 |
|------|-----|------|
| エラー | 必須未入力、形式不正 | 処理中断 |
| 警告 | 値が異常（有効だが稀）、自動修正 | 処理継続、ログ出力 |

## 7. セッション再開バナー

未完了の処理セッションがある場合にバナーを表示し、再開を促すUI。

### CSS

```css
.resume-banner {
    display: none;
    background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
    border: 2px solid #ff9800;
    border-radius: 8px;
    padding: 12px 16px;
    margin-bottom: 15px;
    position: relative;
}
.resume-banner.active { display: block; }
.resume-banner-title {
    font-weight: bold;
    color: #e65100;
    margin-bottom: 8px;
}
.resume-session-item {
    display: flex;
    justify-content: space-between;
    background: white;
    padding: 8px 12px;
    border-radius: 6px;
    border: 1px solid #ffcc80;
    margin-top: 8px;
}
.resume-session-btn {
    background: #ff9800;
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    cursor: pointer;
}
```

### HTML

```html
<div class="resume-banner" id="resume-banner">
    <button class="resume-banner-close" onclick="closeResumeBanner()">&times;</button>
    <div class="resume-banner-title">⚠️ 未完了のセッションがあります</div>
    <div id="resume-sessions-list"></div>
</div>
```

### JavaScript

```javascript
// ページ読み込み時に自動チェック
document.addEventListener('DOMContentLoaded', async () => {
    await checkIncompleteSessions();
});

async function checkIncompleteSessions() {
    try {
        const response = await fetch('/api/registration-session/incomplete/list');
        const data = await response.json();
        if (!data.success || data.count === 0) return;

        const listEl = document.getElementById('resume-sessions-list');
        listEl.innerHTML = data.sessions.map(session => `
            <div class="resume-session-item">
                <div>
                    <strong>Site ID: ${session.site_id || '未設定'}</strong>
                    <div style="font-size:0.85em;color:#666;">
                        STEP ${session.current_step}: ${session.current_step_name}
                    </div>
                </div>
                <button class="resume-session-btn"
                        onclick="resumeSession('${session.record_id}')">再開</button>
            </div>
        `).join('');

        document.getElementById('resume-banner').classList.add('active');
    } catch (e) {
        console.warn('未完了セッション確認エラー:', e);
    }
}

async function resumeSession(recordId) {
    await resumeRegistrationSession(recordId);
    closeResumeBanner();
    showNotification(`セッション ${recordId} を再開しました`, 'success');
}

function closeResumeBanner() {
    document.getElementById('resume-banner').classList.remove('active');
}
```

### 配置場所
- ページのメインコンテンツの直前（ヘッダーの後）
- 他のコンテンツの上に表示されるよう配置

### 関連
- 詳細なセッション管理は `process-state-management` スキル参照

## 7. CamelCaseModel APIレスポンスの取り扱い注意

### 問題パターン
Backend APIが `CamelCaseModel` を使用しているため、Pythonの `snake_case` フィールドがJSONレスポンスでは `camelCase` に変換される。FE側で `snake_case` で参照すると `undefined` になる。

### よくある間違い
```javascript
// ❌ NG: APIレスポンスをsnake_caseで参照
const text = result.opening_text;  // undefined!
const type = item.komi_type;       // undefined!

// ✅ OK: camelCaseで参照
const text = result.openingText;
const type = item.komiType;
```

### 安全なパターン（両対応）
FEで内部変数にもsnake_caseを使っている場合、APIレスポンス受信時に正規化する:
```javascript
// API応答を内部形式に正規化
const normalized = {
    ...apiResponse,
    opening_text: apiResponse.openingText || apiResponse.opening_text || '',
    closing_text: apiResponse.closingText || apiResponse.closing_text || '',
};
```

### チェックリスト
- [ ] APIレスポンスのフィールド参照が `camelCase` になっているか
- [ ] セッション保存時に `snake_case` ↔ `camelCase` の変換が正しいか
- [ ] `CamelCaseModel` のネストされたオブジェクト（例: `KomiTypeResultSimple`）も `camelCase` になることに注意
