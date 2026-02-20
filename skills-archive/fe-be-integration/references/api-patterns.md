# APIエンドポイント設計パターン

## 1. 設定配信API

### パターン: 静的設定の配信

```python
# backend/routers/config.py
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Dict, Any

router = APIRouter(tags=["config"])

# 共有定数（BE側で一元管理）
SHARED_CONFIG = {
    "types": {
        "type_a": {"name": "タイプA", "code": "A", "endpoint": "/api/process-a"},
        "type_b": {"name": "タイプB", "code": "B", "endpoint": "/api/process-b"},
    },
    "limits": {
        "max_items": 100,
        "max_length": 1000,
    },
    "messages": {
        "success": "処理が完了しました",
        "error": "エラーが発生しました",
    }
}

@router.get("/api/config")
async def get_config() -> Dict[str, Any]:
    """アプリケーション設定を取得"""
    return SHARED_CONFIG

@router.get("/api/config/{section}")
async def get_config_section(section: str) -> Dict[str, Any]:
    """特定セクションの設定を取得"""
    if section not in SHARED_CONFIG:
        return {"error": f"Unknown section: {section}"}
    return SHARED_CONFIG[section]
```

### サーバー起動時の静的ファイル生成

```python
# main.py
import json
from pathlib import Path
from routers.config import SHARED_CONFIG

def generate_config_json(frontend_dir: Path):
    """FE用の静的設定ファイルを生成"""
    config_path = frontend_dir / "data" / "app-config.json"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(SHARED_CONFIG, f, ensure_ascii=False, indent=2)

# サーバー起動時に実行
generate_config_json(Path("frontend"))
```

## 2. データ処理API

### パターン: 変換・パース処理

```python
# backend/routers/processing.py
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any

router = APIRouter(tags=["processing"])

class ProcessRequest(BaseModel):
    """処理リクエスト"""
    content: str = Field(..., description="処理対象コンテンツ")
    options: Dict[str, Any] = Field(default_factory=dict, description="オプション")

class ProcessedItem(BaseModel):
    """処理結果アイテム"""
    id: int
    name: str
    value: Any
    metadata: Optional[Dict[str, Any]] = None

class ProcessResponse(BaseModel):
    """処理レスポンス"""
    success: bool
    items: List[ProcessedItem] = []
    count: int = 0
    error: str = ""

@router.post("/api/process", response_model=ProcessResponse)
async def process_content(request: ProcessRequest):
    """コンテンツを処理"""
    try:
        if not request.content:
            return ProcessResponse(success=False, error="コンテンツが空です")

        # 処理ロジック
        items = parse_and_process(request.content, request.options)

        return ProcessResponse(
            success=True,
            items=items,
            count=len(items)
        )
    except Exception as e:
        return ProcessResponse(success=False, error=str(e))
```

### パターン: バッチ処理

```python
class BatchRequest(BaseModel):
    """バッチ処理リクエスト"""
    items: List[str] = Field(..., description="処理対象リスト")
    parallel: bool = Field(default=True, description="並列処理")

class BatchResultItem(BaseModel):
    """バッチ結果アイテム"""
    index: int
    success: bool
    result: Optional[Any] = None
    error: Optional[str] = None

class BatchResponse(BaseModel):
    """バッチ処理レスポンス"""
    success: bool
    results: List[BatchResultItem] = []
    total: int = 0
    succeeded: int = 0
    failed: int = 0

@router.post("/api/process/batch", response_model=BatchResponse)
async def process_batch(request: BatchRequest):
    """バッチ処理"""
    results = []
    succeeded = 0

    for idx, item in enumerate(request.items):
        try:
            result = process_single(item)
            results.append(BatchResultItem(index=idx, success=True, result=result))
            succeeded += 1
        except Exception as e:
            results.append(BatchResultItem(index=idx, success=False, error=str(e)))

    return BatchResponse(
        success=succeeded > 0,
        results=results,
        total=len(request.items),
        succeeded=succeeded,
        failed=len(request.items) - succeeded
    )
```

## 3. バリデーションAPI

### パターン: 段階的バリデーション

```python
from enum import Enum

class ValidationLevel(str, Enum):
    ERROR = "error"      # 処理を中断すべき
    WARNING = "warning"  # 確認を促す
    INFO = "info"        # 情報提供

class ValidationIssue(BaseModel):
    """バリデーション問題"""
    field: str
    level: ValidationLevel
    message: str
    code: Optional[str] = None
    suggested_value: Optional[str] = None

class ValidateRequest(BaseModel):
    """バリデーションリクエスト"""
    data: Dict[str, Any]
    strict: bool = Field(default=False, description="厳格モード")

class ValidateResponse(BaseModel):
    """バリデーションレスポンス"""
    valid: bool
    issues: List[ValidationIssue] = []
    corrected_data: Dict[str, Any] = {}

@router.post("/api/validate", response_model=ValidateResponse)
async def validate_data(request: ValidateRequest):
    """データをバリデーション"""
    issues = []
    corrected = {}

    # 各フィールドをバリデーション
    for field, value in request.data.items():
        field_issues, field_corrected = validate_field(field, value, request.strict)
        issues.extend(field_issues)
        if field_corrected is not None:
            corrected[field] = field_corrected

    has_errors = any(i.level == ValidationLevel.ERROR for i in issues)

    return ValidateResponse(
        valid=not has_errors,
        issues=issues,
        corrected_data=corrected
    )
```

## 4. ユーティリティ関数

### 全角→半角変換

```python
def normalize_to_halfwidth(text: str) -> str:
    """全角数字・記号を半角に変換"""
    result = []
    for char in text:
        code = ord(char)
        # 全角数字 (０-９) → 半角 (0-9)
        if 0xFF10 <= code <= 0xFF19:
            result.append(chr(code - 0xFF10 + ord('0')))
        # 全角英字 (Ａ-Ｚ, ａ-ｚ) → 半角
        elif 0xFF21 <= code <= 0xFF3A:
            result.append(chr(code - 0xFF21 + ord('A')))
        elif 0xFF41 <= code <= 0xFF5A:
            result.append(chr(code - 0xFF41 + ord('a')))
        # 全角ハイフン類 → 半角ハイフン
        elif char in '－―—':
            result.append('-')
        else:
            result.append(char)
    return ''.join(result)
```

## 5. エラーハンドリング

### 統一エラーレスポンス

```python
from fastapi import HTTPException
from fastapi.responses import JSONResponse

class APIError(BaseModel):
    """APIエラーレスポンス"""
    success: bool = False
    error_code: str
    message: str
    details: Optional[Dict[str, Any]] = None

@router.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content=APIError(
            error_code="INTERNAL_ERROR",
            message=str(exc)
        ).dict()
    )
```
