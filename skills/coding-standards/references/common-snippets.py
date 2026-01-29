"""
共通コードスニペット集
=====================
新規プロジェクトでこれらのパターンが必要な場合、
このファイルからコピーして使用すること。

使用方法:
1. 必要なスニペットをコピー
2. プロジェクトの適切なファイルに貼り付け
3. 必要に応じてカスタマイズ
"""

# =============================================================================
# 1. CamelCaseModel - APIレスポンスのcamelCase自動変換
# =============================================================================
# 用途: FastAPI/PydanticでAPIレスポンスをcamelCaseで返す
# 配置先: backend/models/base.py または backend/utils/models.py

from pydantic import BaseModel, ConfigDict
from typing import Any


def to_camel(string: str) -> str:
    """snake_case を camelCase に変換

    例:
        user_name -> userName
        is_active -> isActive
        created_at -> createdAt
    """
    components = string.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])


class CamelCaseModel(BaseModel):
    """APIレスポンス用ベースモデル

    このクラスを継承すると、JSON出力時に自動でcamelCaseに変換される。

    使用例:
        class UserResponse(CamelCaseModel):
            user_id: str           # JSON: "userId"
            display_name: str      # JSON: "displayName"
            is_active: bool        # JSON: "isActive"
    """
    model_config = ConfigDict(
        alias_generator=to_camel,      # フィールド名をcamelCaseに変換
        populate_by_name=True,          # 元のsnake_case名でも値を受け付ける
        serialize_by_alias=True,        # JSON出力時にcamelCaseを使用
    )


# =============================================================================
# 2. 標準レスポンスモデル
# =============================================================================
# 用途: 一貫したAPIレスポンス形式
# 配置先: backend/models/responses.py

from typing import Optional, List, Dict


class SuccessResponse(CamelCaseModel):
    """成功レスポンスの基本形"""
    success: bool = True
    message: str = ""


class ErrorResponse(CamelCaseModel):
    """エラーレスポンスの基本形"""
    success: bool = False
    error: str
    error_code: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


class PaginatedResponse(CamelCaseModel):
    """ページネーション付きレスポンス"""
    success: bool = True
    items: List[Any] = []
    total_count: int = 0
    page: int = 1
    page_size: int = 20
    has_next: bool = False


# =============================================================================
# 3. バリデーションレスポンス
# =============================================================================
# 用途: エラー/警告を分離したバリデーション結果
# 配置先: backend/models/validation.py


class ValidationIssue(CamelCaseModel):
    """バリデーション問題の詳細"""
    field: str
    message: str
    suggested_value: Optional[str] = None


class ValidationResponse(CamelCaseModel):
    """バリデーション結果"""
    valid: bool
    errors: List[ValidationIssue] = []
    warnings: List[ValidationIssue] = []
    corrected_values: Dict[str, str] = {}


# =============================================================================
# 4. 使用例
# =============================================================================

# --- APIエンドポイントでの使用 ---
"""
from fastapi import APIRouter
from .models import CamelCaseModel, SuccessResponse

router = APIRouter()

class CreateUserRequest(BaseModel):
    # リクエストはBaseModelでOK（snake_caseで受け取る）
    user_name: str
    email: str

class UserResponse(CamelCaseModel):
    # レスポンスはCamelCaseModel（camelCaseで返す）
    user_id: str
    user_name: str
    email: str
    created_at: str

@router.post("/api/users", response_model=UserResponse)
async def create_user(request: CreateUserRequest):
    # ... 処理 ...
    return UserResponse(
        user_id="123",
        user_name=request.user_name,  # snake_caseで代入
        email=request.email,
        created_at="2024-01-01T00:00:00"
    )
    # JSON出力: {"userId": "123", "userName": "...", ...}
"""

# --- FEでの参照 ---
"""
// JavaScript: camelCaseで参照
const response = await fetch('/api/users', { method: 'POST', ... });
const user = await response.json();

console.log(user.userId);      // ✅ camelCase
console.log(user.userName);    // ✅ camelCase
console.log(user.createdAt);   // ✅ camelCase
"""
