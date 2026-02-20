# Implementation Example: Registration Flow

Rohanプロジェクトでの実装例を元にした具体的な適用パターン。

## 1. ステップ定義

```python
# backend/routers/registration_session.py

STEP_DEFINITIONS = {
    1: {
        "name": "原稿生成・PPV ID発行",
        "system": "auto.html",
        "timeout": 180,
        "retryable": True
    },
    2: {
        "name": "メニュー登録",
        "system": "原稿管理CMS",
        "timeout": 120,
        "retryable": True
    },
    3: {
        "name": "従量登録",
        "system": "原稿管理CMS",
        "timeout": 60,
        "retryable": True
    },
    4: {
        "name": "売上集計登録",
        "system": "MKBアクセス解析",
        "timeout": 90,
        "retryable": True
    },
    5: {
        "name": "原稿本番アップ",
        "system": "izumo CMS",
        "timeout": 120,
        "retryable": True
    },
    6: {
        "name": "小見出し登録",
        "system": "izumo-dev CMS",
        "timeout": 60,
        "retryable": True
    },
    7: {
        "name": "従量自動更新",
        "system": "izumo-dev CMS",
        "timeout": 60,
        "retryable": True
    }
}
```

## 2. コンテキスト構造

```python
class IdsInfo(BaseModel):
    """ID情報"""
    site_id: Optional[int] = None
    ppv_id: Optional[str] = None
    menu_id: Optional[str] = None
    menu_prefix: Optional[str] = None
    save_id: Optional[int] = None

class ProductInfo(BaseModel):
    """商品情報"""
    title: Optional[str] = None
    manuscript: Optional[str] = None
    subtitles: List[Dict[str, Any]] = []
    opening_text: Optional[str] = None
    closing_text: Optional[str] = None

class DistributionInfo(BaseModel):
    """配信情報"""
    guide_text: Optional[str] = None
    category_code: Optional[str] = None
    person_affinity: Optional[int] = None  # 0=1人用, 1=2人用
    price: Optional[int] = None
    yudo: Optional[Dict[str, Any]] = None  # 誘導情報

class RegistrationRecord(BaseModel):
    """統一登録レコード"""
    record_id: str
    session_id: str
    created_at: str
    updated_at: str
    ids: IdsInfo = IdsInfo()
    product: ProductInfo = ProductInfo()
    distribution: DistributionInfo = DistributionInfo()
    progress: List[StepProgress] = []
    user_input: Optional[Dict[str, Any]] = None
```

## 3. フロントエンドヘルパー（統合版）

```javascript
// ========================================
// 登録セッション管理
// ========================================

let registrationRecord = null;

/**
 * セッション作成
 */
async function createRegistrationSession(options = {}) {
    try {
        const response = await fetch('/api/registration-session/create', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(options)
        });
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                registrationRecord = data.record;
                console.log('✅ セッション作成:', registrationRecord.record_id);
                return registrationRecord;
            }
        }
        throw new Error('セッション作成失敗');
    } catch (e) {
        console.error('❌ セッション作成エラー:', e);
        throw e;
    }
}

/**
 * セッション再開
 */
async function resumeRegistrationSession(recordId) {
    try {
        const response = await fetch(`/api/registration-session/${recordId}`);
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                registrationRecord = data.record;
                console.log('✅ セッション再開:', recordId);
                restoreUIFromRecord(registrationRecord);
                return registrationRecord;
            }
        }
        throw new Error('セッション取得失敗');
    } catch (e) {
        console.error('❌ セッション再開エラー:', e);
        throw e;
    }
}

/**
 * セッション部分更新
 */
async function updateRegistrationSession(partialData) {
    if (!registrationRecord) {
        console.warn('⚠️ セッションが存在しません');
        return null;
    }
    try {
        const response = await fetch(
            `/api/registration-session/${registrationRecord.record_id}`,
            {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(partialData)
            }
        );
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                registrationRecord = data.record;
                return registrationRecord;
            }
        }
    } catch (e) {
        console.error('❌ セッション更新エラー:', e);
    }
    return registrationRecord;
}

/**
 * ステップ状態更新
 */
async function updateStepStatus(step, status, options = {}) {
    if (!registrationRecord) {
        console.warn('⚠️ セッションが存在しません');
        return null;
    }
    try {
        const response = await fetch(
            `/api/registration-session/${registrationRecord.record_id}/step`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    step,
                    status,
                    result: options.result || null,
                    error: options.error || null
                })
            }
        );
        if (response.ok) {
            const data = await response.json();
            if (data.success) {
                registrationRecord = data.record;
                console.log(`✅ STEP${step} → ${status}`);
                return registrationRecord;
            }
        }
    } catch (e) {
        console.error('❌ ステップ更新エラー:', e);
    }
    return registrationRecord;
}

/**
 * UIからセッションを復元
 */
function restoreUIFromRecord(record) {
    if (!record) return;

    // ID情報
    if (record.ids) {
        if (record.ids.site_id) {
            const el = document.getElementById('input-site-id');
            if (el) el.value = record.ids.site_id;
        }
    }

    // 商品情報（グローバル変数に復元）
    if (record.product) {
        if (record.product.manuscript) {
            generatedManuscript = record.product.manuscript;
        }
        if (record.product.opening_text || record.product.closing_text) {
            openingClosingResult = {
                success: true,
                opening_text: record.product.opening_text,
                closing_text: record.product.closing_text
            };
        }
    }

    // 配信情報
    if (record.distribution) {
        if (record.distribution.guide_text) {
            guideResult = { success: true, guide_text: record.distribution.guide_text };
        }
        if (record.distribution.category_code) {
            categoryCodeResult = { success: true, category_code: record.distribution.category_code };
        }
    }

    console.log('✅ UIを復元しました');
}

/**
 * 共通パラメータ取得ヘルパー（コード重複削減）
 */
function getYudoParams() {
    if (registrationRecord?.distribution?.yudo) {
        return registrationRecord.distribution.yudo;
    }
    // フォールバック
    return {
        txt: yudoTxtResult?.generated_text || null,
        ppv01: yudoRecommendResult?.yudo_ppv_id_01 || null,
        menu01: yudoRecommendResult?.yudo_menu_id_01 || null,
        ppv02: yudoRecommendResult?.yudo_ppv_id_02 || null,
        menu02: yudoRecommendResult?.yudo_menu_id_02 || null
    };
}
```

## 4. ステップ実行パターン

```javascript
// STEP 1: 原稿生成
async function executeStep1() {
    // セッション作成
    await createRegistrationSession({
        site_id: parseInt(document.getElementById('input-site-id').value) || null,
        user_input: { input_a, input_b, mode }
    });
    await updateStepStatus(1, 'running');

    try {
        // ... 原稿生成処理 ...

        // セッションに結果を保存
        await updateRegistrationSession({
            product: {
                manuscript: generatedManuscript,
                subtitles: subtitlesArray,
                opening_text: openingClosingResult?.opening_text,
                closing_text: openingClosingResult?.closing_text
            },
            distribution: {
                guide_text: guideResult?.guide_text,
                category_code: categoryCodeResult?.category_code,
                person_affinity: personTypeResult?.isDual ? 1 : 0
            }
        });

        await updateStepStatus(1, 'success', {
            result: { subtitle_count: subtitlesArray.length }
        });

    } catch (error) {
        await updateStepStatus(1, 'error', { error: error.message });
        throw error;
    }
}

// STEP 2-4: メニュー登録フロー
async function executeRegistration() {
    await updateStepStatus(2, 'running');

    try {
        // PPV ID発行
        const ppvId = await issuePpvId(siteId);
        await updateRegistrationSession({ ids: { ppv_id: ppvId } });

        // メニュー登録
        const menuResult = await registerMenu(/* ... */);
        await updateRegistrationSession({ ids: { menu_id: menuResult.menu_id } });
        await updateStepStatus(2, 'success', { result: { menu_id: menuResult.menu_id } });

        // STEP 3: 従量登録
        await updateStepStatus(3, 'running');
        const yudo = getYudoParams();  // ヘルパー使用
        await registerCmsMenu({
            yudo_ppv_id_01: yudo.ppv01,
            yudo_menu_id_01: yudo.menu01,
            // ...
        });
        await updateStepStatus(3, 'success');

        // STEP 4: 従量管理詳細
        await updateStepStatus(4, 'running');
        await registerPpvDetail({
            yudo_txt: yudo.txt,
            yudo_ppv_id_01: yudo.ppv01,
            // ...
        });
        await updateStepStatus(4, 'success');

    } catch (error) {
        // 現在のステップでエラーを記録
        const currentStep = registrationRecord.current_step;
        await updateStepStatus(currentStep, 'error', { error: error.message });
        throw error;
    }
}
```

## 5. 再開バナーUI

```html
<!-- セッション再開バナー -->
<div class="resume-banner" id="resume-banner">
    <button class="resume-banner-close" onclick="closeResumeBanner()">&times;</button>
    <div class="resume-banner-title">
        <span>⚠️</span>
        <span>未完了の登録セッションがあります</span>
    </div>
    <div class="resume-banner-sessions" id="resume-sessions-list">
        <!-- JavaScriptで動的に生成 -->
    </div>
</div>
```

```javascript
// ページ読み込み時に未完了セッションを確認
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
                <div class="resume-session-info">
                    <div><strong>Site ID: ${session.site_id || '未設定'}</strong>
                        ${session.ppv_id ? `/ PPV ID: ${session.ppv_id}` : ''}
                    </div>
                    <div class="resume-session-step">
                        STEP ${session.current_step}: ${session.current_step_name}
                    </div>
                </div>
                <button class="resume-session-btn"
                        onclick="resumeSession('${session.record_id}')">
                    再開
                </button>
            </div>
        `).join('');

        document.getElementById('resume-banner').classList.add('active');
    } catch (e) {
        console.warn('未完了セッション確認エラー:', e);
    }
}

async function resumeSession(recordId) {
    try {
        await resumeRegistrationSession(recordId);
        closeResumeBanner();
        showNotification(`セッション ${recordId} を再開しました`, 'success');
    } catch (e) {
        showNotification('再開失敗: ' + e.message, 'error');
    }
}
```

## 6. 効果測定

### 実装前後の比較

| 項目 | Before | After | 削減率 |
|------|--------|-------|--------|
| yudoパラメータ抽出コード | 3箇所（各8行） | 1ヘルパー（12行） | 50% |
| step-complete呼び出し | 7箇所（各15行） | 統一API（1関数） | 85% |
| グローバル変数依存 | 多数 | セッションに集約 | - |
| 中断時のデータ損失 | 全損失 | 復元可能 | 100% |

### チェックリスト

- [x] 統一データモデル（RegistrationRecord）
- [x] セッションAPI（CRUD + ステップ更新）
- [x] ファイル永続化（data/sessions/）
- [x] FEヘルパー関数
- [x] 再開バナーUI
- [x] コード重複削減（getYudoParams）
- [x] 旧API完全削除
