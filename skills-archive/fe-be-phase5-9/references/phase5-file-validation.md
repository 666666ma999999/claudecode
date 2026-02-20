# Phase 5: ファイル検証統合 - 詳細リファレンス

## 基本実装

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

## Phase 5-A: ファイルタイプ判定API（v1.23.13追加）

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

## Phase 5-B: ダウンロード関数の統合（v1.23.13追加）

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
