# FE/BE統合アーキテクチャスキル

name: fe-be-integration
description: フロントエンドとバックエンドの重複コードを統合し、保守性を向上させるアーキテクチャパターン集。FE/BE間の定数・ロジック・バリデーションの一元管理、構造化データによる信頼性の高いデータ管理を実現する。

## 発動条件

以下のキーワード・状況で自動発動:
- 「FE/BE統合」「フロントエンド・バックエンド統合」
- 「重複コード削減」「DRY原則適用」
- 「定数の一元管理」「バリデーション統合」
- 「API設計」で保守性向上が目的の場合
- FEとBEで同じ処理をしている関数を発見した場合
- 文字列置換でデータ更新が失敗する場合（→ Phase 9: 構造化データ管理）
- 複数データの紐付け管理が必要な場合（→ Phase 9）

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

### Phase 5: ファイル検証統合
**目的**: 添付ファイルのバリデーションとタイプ検出をBE側に統合

```
[Before]
FE: validateAttachedFiles() でMIME判定・枚数チェック
BE: _filter_text_files() で同じ処理

[After]
BE: POST /api/attachments/validate でファイル検証
FE: API結果でUI更新、処理はBEに委譲
```

**実装パターン**:
```python
# BE: attachments.py
def detect_file_type(filename: str, content: Optional[str] = None) -> str:
    """拡張子・MIME・コンテンツからファイルタイプを検出"""
    ext = filename.lower().split('.')[-1]
    if ext in {'txt', 'md', 'csv', 'json'}:
        return 'text'
    elif ext in {'png', 'jpg', 'jpeg', 'gif'}:
        return 'image'
    return 'other'

@router.post("/api/attachments/validate")
async def validate_attachments(request: ValidateAttachmentsRequest):
    rules = ValidationRules.get_attachment_rules(request.section_id)
    files_info = [{"name": f.name, "type": detect_file_type(f.name)} for f in request.files]
    # バリデーション実行...
    return ValidateAttachmentsResponse(valid=..., files_info=files_info, stats=...)
```

### Phase 5-A: ファイルタイプ判定API（v1.23.13追加）
**目的**: FEの簡易判定とBEの高精度判定を統合、エッジケースはBE API使用

```
[Before]
FE: isTextFile(file) → file.type.startsWith('text/')のみ
BE: detect_file_type() → 拡張子・MIME・コンテンツベースの3段階判定

[After]
BE: POST /api/detect-file-type で高精度判定を提供
FE: 明確なケースはローカル判定、不明時はBE API
```

**BE実装**:
```python
# backend/routers/attachments.py
class DetectFileTypeRequest(BaseModel):
    filename: str
    mime_type: Optional[str] = None
    content: Optional[str] = None

class DetectFileTypeResponse(BaseModel):
    file_type: str  # 'text' | 'image' | 'other'
    is_text: bool
    is_image: bool

@router.post("/api/detect-file-type", response_model=DetectFileTypeResponse)
async def detect_file_type_api(request: DetectFileTypeRequest):
    file_type = detect_file_type(request.filename, request.content)
    return DetectFileTypeResponse(
        file_type=file_type,
        is_text=file_type == 'text',
        is_image=file_type == 'image'
    )
```

**FE実装**:
```javascript
// frontend/utils.js
// 同期版（高速・簡易判定）
function isTextFile(file) {
    return file.type.startsWith('text/') ||
           file.name.endsWith('.txt') ||
           file.name.endsWith('.csv');
}

// 非同期版（高精度・BE API使用）
async function getFileType(file) {
    // 高速パス: 明確なケースはローカル判定
    if (file.type.startsWith('text/') || file.name.endsWith('.txt')) {
        return 'text';
    }
    if (file.type.startsWith('image/')) {
        return 'image';
    }
    // 不明な場合はBE API判定
    try {
        const response = await fetch('/api/detect-file-type', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filename: file.name, mime_type: file.type })
        });
        if (response.ok) {
            const data = await response.json();
            return data.file_type;
        }
    } catch (e) {
        console.warn('ファイルタイプ検出API失敗:', e);
    }
    return 'other';
}
```

### Phase 5-B: ダウンロード関数の統合（v1.23.13追加）
**目的**: 複数ファイルに散らばったダウンロード処理をutils.jsに統合

```
[Before]
script.js: downloadBlob(), downloadTextFile() 関数定義
auto.html: インラインでBlob作成・ダウンロード処理

[After]
utils.js: 共通関数として定義
他ファイル: utils.jsの関数を呼び出し
```

**utils.js統合版**:
```javascript
// frontend/utils.js
function downloadBlob(blob, filename) {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.style.display = 'none';
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
}

function downloadTextFile(content, filename, encoding = 'utf-8') {
    const bom = encoding === 'utf-8' ? '\ufeff' : '';
    const blob = new Blob([bom + content], { type: `text/plain;charset=${encoding}` });
    downloadBlob(blob, filename);
}
```

**使用例（auto.html）**:
```javascript
// Before: インライン実装
const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
const url = URL.createObjectURL(blob);
// ...

// After: 共通関数呼び出し
downloadTextFile(content, filename);
```

### Phase 6: 正規表現パース統合
**目的**: FE/BE両方で使用している正規表現パースをBE側に統合

```
[Before]
FE: 複数の正規表現で小見出し抽出
BE: extract_subtitles_from_fortune_result() で同じ処理

[After]
BE: POST /api/fortune/extract-subtitles でパース結果を返す
FE: API結果を使用、正規表現コードを削除
```

**実装パターン**:
```python
# BE: registration.py
@router.post("/api/fortune/extract-subtitles")
async def extract_subtitles_api(request: ExtractSubtitlesRequest):
    # 複数フォーマットに対応したパース
    # パターン1: ・小見出しN: タイトル
    # パターン2: N. タイトル（番号付きリスト）
    # パターン3: 【小見出し】セクション内のテキスト
    subtitles, subtitle_map, matched_pattern = _extract_subtitles_from_text(request.fortune_result)
    return ExtractSubtitlesResponse(
        success=True,
        subtitles=subtitles,
        matched_pattern=matched_pattern
    )
```

### Phase 7: 進捗追跡統合
**目的**: FE側の推定進捗をBE側の実測値ベースに置き換え

```
[Before]
FE: ProgressAnimator で推定時間表示（estimatedSecondsPerCandidate=40）
BE: StepExecutionTracker で実測時間を記録

[After]
BE: GET /api/progress/{session_id} で実測進捗を返す
FE: API進捗をそのまま表示
```

**実装パターン**:
```python
# BE: progress.py
# インメモリセッションストア
_progress_store: Dict[str, SessionProgress] = {}

# ステップ定義（FE/BE共通）
STEP_DEFINITIONS = {
    1: {"name": "原稿生成", "timeout_ms": 300000, "estimated_ms": 60000},
    2: {"name": "メニュー登録", "timeout_ms": 120000, "estimated_ms": 30000},
    # ...
}

@router.get("/api/progress/{session_id}")
async def get_progress(session_id: str):
    session = _progress_store.get(session_id)
    return ProgressResponse(
        current_step=session.current_step,
        steps=[...],  # 各ステップの状態
        percentage=...,
        estimated_remaining_ms=...
    )
```

**重要: FastAPIルート順序**
```python
# 静的パスは動的パス（{session_id}）より先に定義
@router.get("/api/progress/definitions")  # ← 先に定義
async def get_definitions(): ...

@router.get("/api/progress/{session_id}")  # ← 後に定義
async def get_progress(session_id: str): ...
```

### Phase 8: コードクリーンアップ
**目的**: 統合後に不要になったFEコードを整理

**3段階のクリーンアップ**:
```
Phase A: 定数ハードコード削除
- FE側の初期値を空オブジェクトに変更
- API読み込み必須化、エラーハンドリング追加

Phase B: 完全削除
- API版が存在する関数のローカル版を削除
- 使用箇所をAPI版に変更

Phase C: 簡略化
- フォールバック用コードの最小化
- 重複ロジックの統合
```

**削除候補の特定**:
```bash
# Codex MCPで分析
Codex MCPを使って、FE/BE統合後に不要になったコードを特定してください。

# Grepで確認
grep -n "function.*Local" frontend/*.js  # ローカル版
grep -n "let [A-Z_]+ = {" frontend/*.html  # ハードコード定数
```

**削除してはいけないコード**:
- フォールバック関数（API失敗時に使用）
- 後方互換性のためのラッパー
- 複数箇所で使用されるユーティリティ

詳細: `references/cleanup-patterns.md`

#### 8-D: フォールバック廃止（成熟段階）

**目的**: API安定化後、FEフォールバックを完全廃止しBEを唯一のソースに

**いつ実施するか**:
- APIが十分に安定している（3ヶ月以上問題なし）
- フォールバックが実際に発動していない（ログで確認）
- BEダウン時はFEも動作不能で許容される

```javascript
// ❌ Before: フォールバック付き（開発初期）
async function loadAppConfig() {
    try {
        const response = await fetch('/api/config');
        if (response.ok) return await response.json();
    } catch (e) { /* ignore */ }
    // フォールバック: ローカル定数
    return { types: {...}, limits: {...} };
}

// ✅ After: フォールバック廃止（成熟段階）
let CONFIG_LOAD_ERROR = null;

async function loadAppConfig() {
    try {
        const response = await fetch('/api/config', { cache: 'no-store' });
        if (response.ok) return await response.json();
    } catch (e) { /* continue to error */ }

    // フォールバックなし: エラーをスロー
    CONFIG_LOAD_ERROR = new Error('設定の読み込みに失敗。サーバー起動を確認してください。');
    throw CONFIG_LOAD_ERROR;
}

// 設定が必須の箇所
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
const price = parseInt(input.value) || 2000;
const maxId = 999;

// ✅ After: 設定から取得
const config = getRequiredConfig();
const price = parseInt(input.value) || config.registration.default_price;
const maxId = config.registration.site_id_range.max;
```

**移行チェックリスト**:
- [ ] フォールバック発動ログを1ヶ月以上確認（発動ゼロを確認）
- [ ] `isConfigLoaded()` 関数追加
- [ ] 設定必須化（未読み込み時はエラー表示）
- [ ] ハードコード値を設定参照に置換
- [ ] UI初期化を設定読み込み後に移動

### Phase 9: 構造化データ管理
**目的**: 文字列操作からフィールド操作への移行で、データ更新の信頼性向上

```
[Before - 文字列置換方式]
原稿テキスト: "01\t本文内容..."
サマリー追加: text.replace("01\t本文", "01\tサマリー\t本文")
問題: 空白・改行の違いで置換失敗、エラー検知困難

[After - 構造化データ方式]
構造化データ: { codes: [{ code: "01", summary: null, body: "本文" }] }
サマリー追加: codes[0].summary = "サマリー"
テキスト再構築: buildTextFromStructured(data)
利点: フィールド直接更新、失敗検知可能
```

**いつ使うか**:
- 複数の関連データ（ID、タイトル、本文など）を紐付けて管理したい
- 文字列置換でデータ更新しているが、失敗することがある
- データ更新の成功/失敗を確実に検知したい

**データ構造設計パターン**:
```python
# BE: text_analysis.py
def parse_structured(text: str) -> Dict[str, Any]:
    """テキストを構造化データにパース"""
    return {
        "subtitles": [
            {
                "order": 1,
                "title": "小見出しタイトル",
                "codes": [
                    {"code": "01", "summary": None, "body": "本文..."},
                    {"code": "02", "summary": None, "body": "本文..."},
                ]
            }
        ],
        "opening": {"title": "...", "body": "..."},
        "closing": {"title": "...", "body": "..."}
    }

def build_text_from_structured(data: Dict[str, Any]) -> str:
    """構造化データからテキストを再構築"""
    lines = []
    for subtitle in data["subtitles"]:
        lines.append(f"[小見出し{subtitle['order']}]")
        lines.append(subtitle["title"])
        for code_data in subtitle["codes"]:
            if code_data["summary"]:
                lines.append(f"{code_data['code']}\t{code_data['summary']}\t{code_data['body']}")
            else:
                lines.append(f"{code_data['code']}\t{code_data['body']}")
    return '\n'.join(lines)
```

**FEでのフィールド更新パターン**:
```javascript
// FE: structured data management
let structuredData = null;  // メインデータ管理用

// 構造化パース（BE API）
async function parseStructuredAPI(text) {
    const response = await fetch('/api/parse-structured', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: text })
    });
    return (await response.json()).result;
}

// フィールド更新（文字列置換ではない）
function updateFieldInStructured(structured, subtitleOrder, fieldName, value) {
    const subtitle = structured.subtitles.find(s => s.order === subtitleOrder);
    if (!subtitle) {
        return { success: false, error: `小見出し${subtitleOrder}が見つかりません` };
    }

    // 直接フィールドを更新
    const errors = [];
    let updatedCount = 0;

    for (const codeData of subtitle.codes) {
        if (value[codeData.code]) {
            codeData[fieldName] = value[codeData.code];
            updatedCount++;
        } else {
            errors.push(`コード${codeData.code}の値が見つかりません`);
        }
    }

    return {
        success: updatedCount > 0,
        updatedCount,
        errors
    };
}

// テキスト再構築
function buildTextFromStructured(structured) {
    const lines = [];
    for (const subtitle of structured.subtitles) {
        lines.push(`[小見出し${subtitle.order}]`);
        lines.push(subtitle.title);
        for (const codeData of subtitle.codes) {
            if (codeData.summary) {
                lines.push(`${codeData.code}\t${codeData.summary}\t${codeData.body}`);
            } else {
                lines.push(`${codeData.code}\t${codeData.body}`);
            }
        }
    }
    return lines.join('\n');
}
```

**エラー検知と表示**:
```javascript
// フィールド更新時のエラー収集
const updateErrors = [];

for (const item of itemsToUpdate) {
    const result = updateFieldInStructured(structuredData, item.order, 'summary', item.values);
    if (!result.success) {
        updateErrors.push(`${item.order}: ${result.errors.join(', ')}`);
    }
}

// エラーがあればUI表示
if (updateErrors.length > 0) {
    showWarning(`更新エラー: ${updateErrors.length}件`, updateErrors);
}

// テキスト再構築（エラーの有無に関わらず）
finalText = buildTextFromStructured(structuredData);
```

**セッション保存**:
```javascript
// 構造化データとテキスト両方を保存
await updateSession({
    product: {
        manuscript: buildTextFromStructured(structuredData),  // テキスト版（後方互換）
        structured_manuscript: structuredData  // 構造化データ（メイン管理用）
    }
});
```

**BE側セッションモデル**:
```python
# BE: session.py
class ProductInfo(BaseModel):
    manuscript: Optional[str] = None  # テキスト版（後方互換）
    structured_manuscript: Optional[Dict[str, Any]] = None  # 構造化データ
    # ...
```

**移行チェックリスト**:
- [ ] 既存の文字列置換箇所を特定
- [ ] データ構造を設計（どのフィールドを紐付けるか）
- [ ] BEにパース関数・再構築関数を実装
- [ ] FEにフィールド更新関数を実装
- [ ] エラー収集・表示ロジックを追加
- [ ] セッションモデルに構造化データフィールドを追加
- [ ] テスト：更新成功ケース、更新失敗ケース

## 設計原則

### 1. BE側が正（Single Source of Truth）
- 定数・ロジック・バリデーションルールはBE側で定義
- FEはBEのAPIを呼び出して取得・実行

### 2. グレースフルフォールバック
- API失敗時はローカル処理にフォールバック
- ユーザー体験を損なわない

### 3. 後方互換性維持
- 既存の同期関数は残す（ラッパーとして機能）
- 段階的な移行が可能

### 4. エラーと警告の分離
- errors: 処理を中断すべき問題
- warnings: 確認を促すが処理は継続可能

## 分析手順

重複コードを特定するための手順:

1. **定数の重複検索**
```bash
# FE側の定数定義
grep -r "const.*=" frontend/ --include="*.js" --include="*.html"
# BE側の定数定義
grep -r "^[A-Z_]+ = " backend/ --include="*.py"
```

2. **関数名の類似検索**
```bash
# 同じ処理をしていそうな関数名
grep -r "parse\|validate\|convert\|format" frontend/ backend/
```

3. **Codex MCPでの分析**
```
Codex MCPを使って、FEとBEで同じ処理をしている関数を特定し、
BE側で統合するアーキテクト案を作成してください。
```

## チェックリスト

### 統合前
- [ ] 重複している定数を特定
- [ ] 重複しているロジックを特定
- [ ] 重複しているバリデーションを特定
- [ ] **同義語・重複変数名を特定**（同じ値に異なる名前がないか）
- [ ] 優先度を決定（定数→ロジック→バリデーション）

### 統合中
- [ ] BEにAPIエンドポイント追加
- [ ] Pydanticモデルでリクエスト/レスポンス定義
- [ ] **変数名統一**（FE/BEで同じ値には同じ名前、case変換のみ）
- [ ] FEにAPI呼び出し関数追加
- [ ] フォールバック処理実装
- [ ] 既存関数をラッパーに変更
- [ ] 外部システム境界のパラメータ名はコメントで明記

### 統合後
- [ ] APIエンドポイントのテスト
- [ ] FE側のフォールバック動作確認
- [ ] バージョン履歴更新
- [ ] ドキュメント更新

### クリーンアップ（Phase 8）
- [ ] Codex MCPで冗長コード分析
- [ ] Phase A: 定数ハードコード削除
- [ ] Phase B: 不要関数削除（API版に統合）
- [ ] Phase C: 残存コード簡略化
- [ ] サーバー再起動・ヘルスチェック
- [ ] 削減効果の記録（行数・関数数）

### 構造化データ管理（Phase 9）
- [ ] 文字列置換箇所を特定
- [ ] 構造化データ設計（フィールド紐付け）
- [ ] BE: パース関数・再構築関数実装
- [ ] FE: フィールド更新関数実装
- [ ] エラー収集・表示ロジック追加
- [ ] セッションモデルに構造化データフィールド追加
- [ ] テスト（成功・失敗ケース）

## 実装上の注意点

### FastAPIルート順序
動的パス（`{session_id}`など）を含むルートは、静的パスより**後**に定義する。
```python
# ❌ Bad: definitionsがsession_idにマッチしてしまう
@router.get("/api/progress/{session_id}")
@router.get("/api/progress/definitions")

# ✅ Good: 静的パスを先に定義
@router.get("/api/progress/definitions")
@router.get("/api/progress/{session_id}")
```

### インメモリストアの設計
進捗追跡などでインメモリストアを使う場合:
```python
# グローバルストア
_progress_store: Dict[str, SessionProgress] = {}

# クリーンアップ関数を用意
def cleanup_old_sessions(max_age_hours: int = 24):
    now = datetime.now()
    for session_id, session in list(_progress_store.items()):
        if (now - session.created_at).hours > max_age_hours:
            del _progress_store[session_id]
```

### ファイルタイプ検出の優先順位
1. 拡張子ベース（高速・信頼性高）
2. MIMEタイプベース（拡張子不明時）
3. コンテンツベース（最終手段）

## Codex MCPを使った分析

重複コード特定にCodex MCPを活用:
```
Codex MCPを使って、現環境のFEとBEの関数で同じ処理をしている関数を
BE側で統合して保守性を高め、コード量を減らせるアーキテクト案を作成して下さい。
```

Codexが返す分析結果:
- 重複箇所（FEファイル:行番号 ↔ BEファイル:行番号）
- 統合実装案（API設計、レスポンス形式）
- 優先度の提案

## 状態管理パターン

### グローバル変数の問題

FEでグローバル変数を使った状態管理は以下の問題がある:
- **ページリロードで消失**: 処理途中でリロードすると全データ損失
- **複数箇所での参照**: どこで変更されたか追跡困難
- **テスト困難**: モック化が難しい

```javascript
// ❌ Bad: グローバル変数依存
let generatedResult = null;
let ppvId = null;
let menuId = null;
// ... 処理途中でリロード → 全て消失
```

### セッションベース状態管理

**解決策**: BE側でセッション状態を管理し、FEはAPIで状態を取得・更新

```javascript
// ✅ Good: セッションベース
let sessionRecord = null;

async function createSession(context) {
    const response = await fetch('/api/session/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(context)
    });
    sessionRecord = (await response.json()).record;
    return sessionRecord;
}

async function updateSession(partialData) {
    await fetch(`/api/session/${sessionRecord.record_id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partialData)
    });
}

// リロード後も復元可能
async function resumeSession(recordId) {
    const response = await fetch(`/api/session/${recordId}`);
    sessionRecord = (await response.json()).record;
    restoreUIFromSession(sessionRecord);
}
```

### 共通ヘルパー関数の抽出

複数箇所で同じパラメータを抽出している場合、ヘルパー関数に統合:

```javascript
// ❌ Bad: 同じコードが3箇所に
// 場所A
const yudoPpvId01 = yudoResult?.success ? yudoResult.ppv_id_01 : null;
const yudoMenuId01 = yudoResult?.success ? yudoResult.menu_id_01 : null;
// 場所B, 場所C でも同じコード...

// ✅ Good: ヘルパー関数で統一
function getYudoParams() {
    // セッションから取得（優先）
    if (sessionRecord?.distribution?.yudo) {
        return sessionRecord.distribution.yudo;
    }
    // フォールバック: グローバル変数
    return {
        ppv01: yudoResult?.ppv_id_01 || null,
        menu01: yudoResult?.menu_id_01 || null,
        // ...
    };
}

// 使用箇所
const yudo = getYudoParams();
await registerMenu({ yudo_ppv_id_01: yudo.ppv01, ... });
```

**詳細なセッション管理パターンは `process-state-management` スキルを参照**

## 参照ファイル

- `references/api-patterns.md` - APIエンドポイント設計パターン
- `references/fallback-patterns.md` - フォールバック実装パターン
- `references/validation-patterns.md` - バリデーション設計パターン
- `references/progress-patterns.md` - 進捗追跡パターン
- `references/cleanup-patterns.md` - 統合後のコードクリーンアップパターン
- `references/structured-data-patterns.md` - 構造化データ管理パターン（文字列置換からの移行）

## デバッグTip: セッションファイルによるデータフロー追跡

FE→BE→FEのデータ変換で「N個指定したのにM個しか処理されない」問題が発生した場合：

```bash
# セッションファイルで各段階のデータを確認
python3 << 'EOF'
import json
with open('data/sessions/reg_xxx.json') as f:
    data = json.load(f)

# 1. 入力段階（FE→BE）
print(f"入力: {len(data['product']['subtitles'])}件")

# 2. 処理結果（BE内部）
print(f"処理後: {len(data['product']['structured_manuscript']['subtitles'])}件")

# 3. どこで減ったか特定 → パーサーのログを確認
EOF
```

**詳細なパーサーデバッグは `text-parser-patterns` スキルを参照**

## 外部システム/CMSのフィールドマッピング調査

### 問題

外部CMS・APIのフォームフィールド名が想定と異なる場合、自動化が失敗する。

```
想定: input[name='user_id'], input[name='password']
実際: input[name='user'], input[name='pass']
→ ログインが失敗、原因特定に時間がかかる
```

### 解決策: 実装前にフィールド構造を調査

```python
# Playwrightで実際のフォーム構造を調査
async def discover_form_fields(page, url):
    await page.goto(url)
    await page.wait_for_load_state('networkidle')

    return await page.evaluate('''
        () => {
            const result = { inputs: [], textareas: [], selects: [] };
            document.querySelectorAll('input[name]').forEach(el => {
                result.inputs.push({
                    name: el.name,
                    type: el.type,
                    placeholder: el.placeholder
                });
            });
            document.querySelectorAll('textarea[name]').forEach(el => {
                result.textareas.push({ name: el.name });
            });
            document.querySelectorAll('select[name]').forEach(el => {
                result.selects.push({ name: el.name });
            });
            return result;
        }
    ''')
```

### フィールドマッピング設計パターン

```python
# 外部システムのフィールド名を設定で管理
CMS_FIELD_MAPPINGS = {
    "hayatomo_cms": {
        "login": {
            "user_field": "user",      # 実際のname属性
            "pass_field": "pass",
            "submit_selector": "button:has-text('Login')"
        },
        "ppv_detail": {
            "guide_field": "guide",
            "price_field": "price",
            "affinity_field": "affinity"
        }
    },
    "other_cms": {
        "login": {
            "user_field": "user_id",
            "pass_field": "password",
            "submit_selector": "button[type='submit']"
        }
    }
}

# 使用時
async def login(page, cms_type, username, password):
    mapping = CMS_FIELD_MAPPINGS[cms_type]["login"]
    await page.fill(f"input[name='{mapping['user_field']}']", username)
    await page.fill(f"input[name='{mapping['pass_field']}']", password)
    await page.click(mapping['submit_selector'])
```

### チェックリスト

新しい外部システム/CMSと連携する際：

- [ ] Playwrightでログインページのフィールド構造を調査
- [ ] 対象フォームページのフィールド構造を調査
- [ ] フィールドマッピング設定を作成
- [ ] input/textarea/select の3種類すべてを考慮
- [ ] デバッグログで「見つからなかったフィールド」を出力

**詳細なPlaywright操作パターンは `playwright-browser-automation` スキルを参照**

## 関連スキル

- **coding-standards**: 言語別命名規則、CamelCaseModelの基本説明
- **process-state-management**: 複数ステップのプロセス管理、ログ記録、中断・再開機能
- **text-parser-patterns**: テキストパーサー実装、エッジケース処理、デバッグ手法
- **playwright-browser-automation**: ブラウザ自動化、フォームフィールド調査
