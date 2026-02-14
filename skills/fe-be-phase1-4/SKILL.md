---
name: fe-be-phase1-4
description: |
  FE/BE統合 Phase 1〜4の詳細実装パターン。定数統合、ロジック統合、バリデーション統合、ファイル名生成統合の具体的な実装手順とコード例を提供する。
  使用タイミング:
  (1) FE/BE間で重複している定数をBE側に一元化するとき（Phase 1: 定数統合）
  (2) FE/BEで同じ変換・パース処理を統合するとき（Phase 2: ロジック統合）
  (3) CamelCaseModelの導入・命名規則不整合の検出・修正をするとき
  (4) FE→BE間のデータ受け渡し（camelCase/snake_case変換、Order番号ずれ、セッション欠損）を修正するとき
  (5) 入力バリデーションをBE側に一元化するとき（Phase 3: バリデーション統合）
  (6) ファイル名・タイムスタンプ生成をBE側に統合するとき（Phase 4: ファイル名生成統合）
  キーワード: 定数統合, ロジック統合, バリデーション統合, ファイル名生成統合, CamelCaseModel, 同義語統一, Async Wrapper, snake_case変換, Order番号ずれ, Pre-STEP Validator
disable-model-invocation: true
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

## 統合アプローチ（7フェーズ）

### Phase 1: 定数統合
**目的**: FE/BE両方で定義されている定数をBE側で一元管理

```
[Before]
FE: const TYPES = { a: 1, b: 2 }
BE: TYPES = { "a": 1, "b": 2 }

[After]
BE: /api/config で定数を配信
FE: 起動時にAPIから取得、ローカル変数に格納
```

**実装パターン**:
```python
# BE: config.py
SHARED_CONSTANTS = {
    "types": {...},
    "limits": {...},
    "messages": {...}
}

@router.get("/api/config")
async def get_config():
    return SHARED_CONSTANTS
```

```javascript
// FE: 起動時に読み込み
let APP_CONFIG = null;
(async function initConfig() {
    const response = await fetch('/api/config', { cache: 'no-store' });
    APP_CONFIG = await response.json();
})();
```

**⚠️ 落とし穴: ブラウザキャッシュ**

開発中に設定値（バージョン番号など）を変更してもFEに反映されない場合、ブラウザキャッシュが原因。

```javascript
// ❌ Bad: キャッシュされる可能性あり
fetch('/api/config')

// ✅ Good: キャッシュバイパス
fetch('/api/config', { cache: 'no-store' })

// ✅ Alternative: クエリ文字列でバイパス
fetch(`/api/config?_=${Date.now()}`)
```

### Phase 2: ロジック統合
**目的**: FE/BE両方で実装されている変換・パース処理をBE側に統合

```
[Before]
FE: parseData(text) → { ... }
BE: parse_data(text) → { ... }

[After]
BE: POST /api/parse で処理を提供
FE: API優先、失敗時はローカルフォールバック
```

#### 2-A: 同義語・重複変数名の統一（重要）

**目的**: 同じ値を表す変数が、FEとBEで異なる名前になっているケースを検出・統一

**問題パターン**:
```
❌ 危険な状態:
FE: menuId変数 → APIに save_id パラメータとして送信
BE: save_id で受信 → セッションに menu_id として保存
→ 同じ値に2つの名前が存在し、混乱・バグの温床
```

**チェック方法**:
1. FEのAPI呼び出しパラメータ名を確認
2. BEのリクエストモデルのフィールド名を確認
3. 同じ値を表す変数が異なる名前になっていないか確認
4. セッション/状態管理で同じ値に複数のキーがないか確認

**統一ルール**:
| 危険パターン | 正しい対応 |
|-------------|-----------|
| FE: `menuId` / BE: `save_id` | → 統一: `menu_id` (BE) / `menuId` (FE) |
| FE: `userId` / BE: `member_id` | → どちらかに統一（意味が明確な方を選択） |
| FE: `itemName` / BE: `product_title` | → どちらかに統一 |

**外部システム境界の例外**:
```python
# 内部変数名は統一（menu_id）
def register(menu_id: int):
    # 外部システムへのURLパラメータは外部仕様に従う（変更不可）
    url = f"https://cms.example.com/edit?save_id={menu_id}"
    # ↑ 外部CMSの仕様なので save_id= のまま維持
```

**後方互換性（データ移行時）**:
```python
# 新しい名前を優先、古い名前にフォールバック
menu_id = data.get('menu_id') or data.get('save_id')
```

**教訓（2025-01-27）**:
- snake_case/camelCase変換だけでは不十分
- 「同じ値なのに違う名前」は将来的にバグの温床
- 統合作業時は**同義語チェック**を必ず実施

#### 2-B: CamelCaseModel パターン（命名規則統一）

**目的**: BE内部はsnake_case、APIレスポンスはcamelCaseで統一

```python
# BE: Pydanticベースモデル定義
from pydantic import BaseModel, ConfigDict

def to_camel(string: str) -> str:
    """snake_case を camelCase に変換"""
    components = string.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

class CamelCaseModel(BaseModel):
    """camelCaseでJSONを出力するベースモデル"""
    model_config = ConfigDict(
        alias_generator=to_camel,      # フィールド名変換
        populate_by_name=True,          # 元の名前でも受け付け
        serialize_by_alias=True,        # JSON出力時にalias使用
    )

# 使用例
class UserResponse(CamelCaseModel):
    user_id: str           # → JSON: "userId"
    display_name: str      # → JSON: "displayName"
    is_active: bool        # → JSON: "isActive"
```

```javascript
// FE: camelCaseで参照
const response = await fetch('/api/user');
const data = await response.json();
console.log(data.userId);      // ✅ camelCase
console.log(data.displayName); // ✅ camelCase
```

**メリット**:
- BE内部はPython規約（snake_case）を維持
- FEはJavaScript規約（camelCase）で自然に参照
- 手動変換不要、エラー削減

#### 2-E: 命名規則不整合の検出・修正（v1.23.17追加）

**目的**: FE/BE統合後に残存するsnake_case参照を体系的に検出・修正

**背景**: CamelCaseModelを導入しても、以下のケースで不整合が残りやすい:
- 辞書リテラルで直接returnしている箇所
- ネストした辞書のキー（親は修正、子は漏れ）
- BaseModelのまま残っているレスポンスモデル

**検出パターン（Grep）**:
```bash
# FE側: snake_case参照を検出
grep -E 'data\.[a-z]+_[a-z]+|result\.[a-z]+_[a-z]+' frontend/*.{js,html}

# BE側: CamelCaseModelに変更すべきResponseモデル
grep -E 'class.*Response\(BaseModel\)' backend/**/*.py

# BE側: 辞書リテラルのsnake_caseキー
grep -E '"[a-z]+_[a-z]+":' backend/**/*.py
```

**漏れやすいパターン**:

| パターン | 例 | 対処 |
|---------|-----|------|
| ネストした辞書 | `data.header_info.generated_at` | 親子両方をcamelCase化 |
| 状態更新データ | `{ filled_fields: result.filled_fields }` | 内部キーもcamelCase |
| エラーケースのreturn | `return {"error": e, "updated_rows": 0}` | 成功/失敗両方を確認 |
| 非Responseモデル | 辞書リテラルで直接return | CamelCaseModel使用またはキー変換 |

**修正手順**:

1. **BE側: Responseモデルの確認**
```python
# ❌ Before: BaseModel継承
class ParseMetadataResponse(BaseModel):
    expected_code_count: int = 0

# ✅ After: CamelCaseModel継承
class ParseMetadataResponse(CamelCaseModel):
    expected_code_count: int = 0  # → expectedCodeCount
```

2. **BE側: 辞書リテラルの確認**
```python
# ❌ Before: snake_caseキー
return {
    "header_info": header_info,
    "prompt_a": prompt_a,
    "created_at": timestamp
}

# ✅ After: camelCaseキー
return {
    "headerInfo": header_info,
    "promptA": prompt_a,
    "createdAt": timestamp
}
```

3. **BE側: ネストした辞書の確認**
```python
# ❌ Before: 親は修正、子は漏れ
header_info = {
    "generated_at": "2026-01-28",  # 漏れ
    "user": "test"
}
return {"headerInfo": header_info}  # 親は修正済み

# ✅ After: 子も修正
header_info = {
    "generatedAt": "2026-01-28",
    "user": "test"
}
return {"headerInfo": header_info}
```

4. **FE側: 参照の修正**
```javascript
// ❌ Before
const count = metadata.expected_code_count;
if (data.header_info.generated_at) { ... }

// ✅ After
const count = metadata.expectedCodeCount;
if (data.headerInfo.generatedAt) { ... }
```

**例外（修正不要なケース）**:
- ローカルフォーム検証関数内のデータ（API由来でない）
- 内部処理用の変数（APIレスポンスに含まれない）
- 外部システムのパラメータ名（変更不可）

**チェックリスト**:
- [ ] 全ResponseモデルがCamelCaseModel継承か確認
- [ ] 辞書リテラルで直接returnしている箇所を確認
- [ ] ネストした辞書のキーを確認
- [ ] 成功ケース・エラーケース両方のreturnを確認
- [ ] FEでの参照が全てcamelCaseか確認
- [ ] サーバー再起動・ヘルスチェック実施

#### 2-F: FE→BE データ受け渡し時の3大落とし穴（v1.25.2追加）

**目的**: CamelCaseModel APIレスポンスをFEで受け取り、別のBE APIに再送信する際のデータ不整合を防止

**背景**: FEがBE API-Aからデータを受け取り（camelCase）、そのままBE API-Bに送信すると、API-BのBaseModelがsnake_caseを期待しているため、フィールドが認識されずデフォルト値になる。

##### 落とし穴1: CamelCase→snake_case変換漏れ（リレー問題）

```
BE API-A (CamelCaseModel) → FE → BE API-B (BaseModel)
  komiType: "komi_honne1"  →  komi_type: "" (デフォルト値!)
```

**原因**: API-AのレスポンスはcamelCase、API-BのリクエストモデルはBaseModel（snake_case期待）

**修正パターン**:
```javascript
// ❌ Bad: API-Aのレスポンスをそのまま送信
body: JSON.stringify({
    komi_types: apiAResult.results  // camelCaseのまま!
})

// ✅ Good: snake_caseに明示的に変換してから送信
body: JSON.stringify({
    komi_types: apiAResult.results.map(k => ({
        order: k.order,
        komi_type: k.komiType || k.komi_type || 'default',
        komi_name: k.komiName || k.komi_name || ''
    }))
})
```

**チェックリスト**:
- [ ] FEでAPI-Aの結果をAPI-Bに転送する箇所を特定
- [ ] API-BのリクエストモデルがBaseModelかCamelCaseModelか確認
- [ ] BaseModelの場合、FE側でsnake_caseに変換するmapを追加

##### 落とし穴2: Order番号オフセットずれ

```
FE (モーダルUI):  冒頭=1, 小見出し1=2, 小見出し2=3, ...
BE (処理ロジック): 冒頭なし → 小見出し1=1, 小見出し2=2, ...
→ midid_map[1] で冒頭のID(1026)が小見出し1に適用される!
```

**原因**: FEとBEでオプション要素（冒頭/締め）の有無が異なる場合、order番号がずれる

**修正パターン**:
```python
# BE: オフセット検出と補正
midid_offset = 0
if not structured.get("opening"):
    # FEは冒頭込みでorder送信、BEは冒頭なし
    opening_mid_id = CONSTANTS["opening_closing_mid_id"]
    if midid_map and any(
        v == opening_mid_id for k, v in midid_map.items() if k == 1
    ):
        midid_offset = 1
        logger.info(f"midid_offset={midid_offset}: FE冒頭ありBE冒頭なし検出")

# 使用時
mid_id = midid_map.get(order + midid_offset, "")
```

**チェックリスト**:
- [ ] FEのorder付与ロジック（冒頭/締め含むか）を確認
- [ ] BEのorder計算ロジック（冒頭/締めがない場合の開始値）を確認
- [ ] 不一致がある場合、オフセット変数で補正

##### 落とし穴3: セッション保存/復元時のデータ欠損

```
STEP 1完了時: structuredManuscript = { subtitles: [...] }  ← opening/closingなし
  openingClosingResult = { opening_text: "...", closing_text: "..." }  ← 別変数
セッション保存: structured_manuscript にはopening/closingが含まれない
ページリロード後: openingClosingResult = null (グローバル変数消失)
STEP 2実行: fullStructuredManuscript にopening/closingが追加されない!
```

**原因**: 関連データが別々のグローバル変数に分散し、セッション保存時に統合されない

**修正パターン**:
```javascript
// ✅ セッション保存時にデータを統合
await updateSession({
    product: {
        structured_manuscript: (() => {
            if (!structuredData) return null;
            const sm = JSON.parse(JSON.stringify(structuredData));
            if (relatedResult?.field_a) {
                sm.section_a = { title: "...", body: relatedResult.field_a };
            }
            if (relatedResult?.field_b) {
                sm.section_b = { title: "...", body: relatedResult.field_b };
            }
            return sm;
        })(),
    }
});

// ✅ セッション復元時に両方復元
if (record.product.structured_manuscript) {
    structuredData = record.product.structured_manuscript;
}
if (record.product.field_a || record.product.field_b) {
    relatedResult = {
        success: true,
        field_a: record.product.field_a,
        field_b: record.product.field_b
    };
}
```

**チェックリスト**:
- [ ] STEP間で引き継ぐデータが全てセッションに保存されているか
- [ ] グローバル変数に依存しているデータがページリロードで消失しないか
- [ ] セッション復元時に関連するグローバル変数も復元されるか
- [ ] セッション保存時に分散データが統合されているか

##### デバッグ用ログ追加パターン

FE→BE間のデータ不整合を早期発見するため：

```python
# BE: リクエスト受信時にデータ構造をログ出力
logger.info(f"structured_manuscript: opening={bool(structured.get('opening'))}, "
            f"closing={bool(structured.get('closing'))}, "
            f"subtitles={len(structured.get('subtitles', []))}")
logger.info(f"midid_map keys={list(midid_map.keys())}, "
            f"komi_type_map keys={list(komi_type_map.keys())}")

# subtitle_contentsの最終結果を検証
for sc in subtitle_contents:
    logger.info(f"SubtitleContent: order={sc.order}, "
                f"mid_id={sc.mid_id}, komi_type={sc.komi_type}, "
                f"title={sc.title[:30]}...")
```

#### 2-C: Async Wrapperパターン（同期→非同期変換）

**目的**: FE既存の同期関数をAPI呼び出しに置き換え、フォールバック付き

```javascript
// Step 1: 元の同期関数を*Local付きでリネーム＆@deprecated化
/**
 * @deprecated buildDataAsync()を使用してください
 */
function buildDataLocal(input) {
    // 元のローカル処理（フォールバック用に保持）
    return processLocally(input);
}

// Step 2: 非同期ラッパー関数を追加
async function buildDataAsync(input) {
    if (!input) return null;

    try {
        const response = await fetch('/api/build-data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
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
    return buildDataLocal(input);
}

// Step 3: 呼び出し箇所を更新（async contextが必要）
// Before: const result = buildData(input);
// After:  const result = await buildDataAsync(input);
```

#### 2-D: 標準実装パターン

```python
# BE: router.py
class ParseRequest(BaseModel):
    content: str

class ParseResponse(CamelCaseModel):  # ← CamelCaseModel継承
    success: bool
    result: dict
    error: str = ""

@router.post("/api/parse")
async def parse_content(request: ParseRequest):
    try:
        result = parse_logic(request.content)
        return ParseResponse(success=True, result=result)
    except Exception as e:
        return ParseResponse(success=False, error=str(e))
```

```javascript
// FE: API優先、フォールバック付き
async function parseDataAsync(content) {
    // まずBE APIを試す
    try {
        const response = await fetch('/api/parse', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content })
        });
        if (response.ok) {
            const data = await response.json();
            if (data.success) return data.result;
        }
    } catch (e) {
        console.warn('API fallback:', e);
    }
    // フォールバック: ローカル処理
    return parseDataLocal(content);
}
```

### Phase 3: バリデーション統合
**目的**: 入力検証をBE側で一元化、エラー/警告の分離

```
[Before]
FE: if (!value) { alert('必須です'); return; }
BE: if not value: raise HTTPException(...)

[After]
BE: POST /api/validate でバリデーション結果を返す
FE: 登録前にAPIでチェック、結果に応じてUI表示
```

**実装パターン**:
```python
# BE: validation.py
class ValidationIssue(BaseModel):
    field: str
    message: str
    suggested_value: Optional[str] = None

class ValidateResponse(BaseModel):
    valid: bool
    errors: List[ValidationIssue] = []
    warnings: List[ValidationIssue] = []
    corrected_values: Dict[str, str] = {}

@router.post("/api/validate")
async def validate_input(request: ValidateRequest):
    errors, warnings, corrected = [], [], {}

    # バリデーションロジック
    if not request.field1:
        errors.append(ValidationIssue(field="field1", message="必須項目です"))

    # 自動修正（全角→半角など）
    if has_fullwidth(request.field2):
        corrected["field2"] = to_halfwidth(request.field2)
        warnings.append(ValidationIssue(
            field="field2",
            message="全角が半角に変換されました",
            suggested_value=corrected["field2"]
        ))

    return ValidateResponse(
        valid=len(errors) == 0,
        errors=errors,
        warnings=warnings,
        corrected_values=corrected
    )
```

#### 実装済み: Pre-STEP Validator パターン (v1.48.0)

StepHandler dataclass に `validator` フィールドを追加し、execute_step_generic 内でbuilder呼び出し前に自動実行。
- `validate_step3`: distribution の guide_text, category_code, yudo 検証
- `validate_step4`: menu_id 存在検証
- FE側: executeStepUnified が `validationErrors` / `validationWarnings` を自動表示
- バリデーション失敗時は step status を "error" に更新
- 成功時も warnings がある場合はレスポンスに含めて FE に通知

### Phase 4: ファイル名生成統合
**目的**: タイムスタンプやファイル名フォーマットをBE側で一元管理

```
[Before]
FE: formatTimestampLocal() でYYYYMMDD形式生成
BE: format_timestamp_for_filename() で同じ処理

[After]
BE: /api/timestamp/filename/{file_type} でファイル名を生成
FE: API結果をそのまま使用
```

**実装パターン**:
```python
# BE: config.py
FILENAME_PATTERNS = {
    "manuscript": "{prefix}_{timestamp}.txt",
    "csv": "{prefix}_{timestamp}.csv",
}

@router.get("/api/timestamp/filename/{file_type}")
async def get_download_filename(file_type: str, prefix: str = "download"):
    timestamp = format_timestamp_for_filename("datetime")
    pattern = FILENAME_PATTERNS.get(file_type, "{prefix}_{timestamp}.txt")
    return {"filename": pattern.format(prefix=prefix, timestamp=timestamp)}
```
