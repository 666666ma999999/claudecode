---
name: fe-be-phase5-9
description: |
  FE/BE統合 Phase 5〜9の詳細実装パターン。
  ファイル検証統合、正規表現パース統合、進捗追跡統合、コードクリーンアップ、構造化データ管理。
disable-model-invocation: true
---

# FE/BE統合 Phase 5〜9

このスキルはPhase 5（ファイル検証統合）からPhase 9（構造化データ管理）までの詳細実装パターンを提供します。

## Phase 5: ファイル検証統合
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

## Phase 6: 正規表現パース統合
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

## Phase 7: 進捗追跡統合
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

## Phase 8: コードクリーンアップ
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

### 8-D: フォールバック廃止（成熟段階）

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

## Phase 9: 構造化データ管理
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

## 関連スキル

- **fe-be-phase0-4**: Phase 0-4（定数統合、ロジック統合、バリデーション統合、ファイル名生成統合）
- **coding-standards**: 言語別命名規則、CamelCaseModelの基本説明
- **process-state-management**: 複数ステップのプロセス管理、ログ記録、中断・再開機能
- **text-parser-patterns**: テキストパーサー実装、エッジケース処理、デバッグ手法
- **playwright-browser-automation**: ブラウザ自動化、フォームフィールド調査
