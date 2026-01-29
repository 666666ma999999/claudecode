# バリデーション設計パターン

## 1. エラー/警告の分離設計

### 原則
- **エラー (errors)**: 処理を中断すべき問題。修正必須。
- **警告 (warnings)**: 確認を促すが、処理は継続可能。ユーザー判断。
- **自動修正 (corrected_values)**: システムが自動で修正した値。

### 分類ガイドライン

| 種別 | 例 | 分類 |
|------|-----|------|
| 必須項目の未入力 | 名前が空 | エラー |
| 形式不正 | メールアドレスに@がない | エラー |
| 範囲外 | 年齢が-1 | エラー |
| 長すぎる/短すぎる | 文字数超過 | エラー or 警告 |
| 全角/半角の混在 | 全角数字 | 警告 + 自動修正 |
| 異常値（有効だが稀） | 価格が1円 | 警告 |
| 推奨からの逸脱 | 推奨文字数未満 | 警告 |

## 2. バリデーションモデル設計

### Python (Pydantic)

```python
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any
from enum import Enum

class IssueLevel(str, Enum):
    """問題レベル"""
    ERROR = "error"
    WARNING = "warning"
    INFO = "info"

class ValidationIssue(BaseModel):
    """バリデーション問題"""
    field: str = Field(..., description="問題のあるフィールド名")
    level: IssueLevel = Field(default=IssueLevel.ERROR, description="問題レベル")
    message: str = Field(..., description="ユーザー向けメッセージ")
    code: Optional[str] = Field(None, description="エラーコード（プログラム用）")
    suggested_value: Optional[str] = Field(None, description="推奨値")
    metadata: Optional[Dict[str, Any]] = Field(None, description="追加情報")

class ValidateRequest(BaseModel):
    """バリデーションリクエスト"""
    # フィールドはOptionalにして、指定されたものだけバリデーション
    field1: Optional[str] = None
    field2: Optional[int] = None
    field3: Optional[List[str]] = None
    # バリデーションモード
    strict: bool = Field(default=False, description="厳格モード")
    validate_all: bool = Field(default=False, description="全フィールド検証")

class ValidateResponse(BaseModel):
    """バリデーションレスポンス"""
    valid: bool = Field(..., description="エラーなし")
    errors: List[ValidationIssue] = Field(default_factory=list)
    warnings: List[ValidationIssue] = Field(default_factory=list)
    infos: List[ValidationIssue] = Field(default_factory=list)
    corrected_values: Dict[str, Any] = Field(default_factory=dict)

    @property
    def has_errors(self) -> bool:
        return len(self.errors) > 0

    @property
    def has_warnings(self) -> bool:
        return len(self.warnings) > 0
```

## 3. バリデーションルール実装

### 基本バリデータ

```python
from abc import ABC, abstractmethod
from typing import Tuple, Optional, Any

class FieldValidator(ABC):
    """フィールドバリデータ基底クラス"""

    @abstractmethod
    def validate(self, value: Any) -> Tuple[List[ValidationIssue], Optional[Any]]:
        """
        バリデーション実行

        Returns:
            (issues, corrected_value): 問題リストと修正値（修正不要ならNone）
        """
        pass

class RequiredValidator(FieldValidator):
    """必須チェック"""

    def __init__(self, field: str, message: str = "必須項目です"):
        self.field = field
        self.message = message

    def validate(self, value: Any) -> Tuple[List[ValidationIssue], Optional[Any]]:
        if value is None or (isinstance(value, str) and not value.strip()):
            return [ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message=self.message,
                code="REQUIRED"
            )], None
        return [], None

class NumericValidator(FieldValidator):
    """数値チェック"""

    def __init__(self, field: str, min_val: int = None, max_val: int = None):
        self.field = field
        self.min_val = min_val
        self.max_val = max_val

    def validate(self, value: Any) -> Tuple[List[ValidationIssue], Optional[Any]]:
        issues = []
        corrected = None

        # 全角→半角変換
        if isinstance(value, str):
            normalized = normalize_to_halfwidth(value.strip())
            if normalized != value:
                corrected = normalized
                issues.append(ValidationIssue(
                    field=self.field,
                    level=IssueLevel.WARNING,
                    message="全角数字が半角に変換されました",
                    code="FULLWIDTH_CONVERTED",
                    suggested_value=normalized
                ))
            value = normalized

        # 数値チェック
        if not str(value).isdigit():
            issues.append(ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message="数字のみで入力してください",
                code="NOT_NUMERIC"
            ))
            return issues, corrected

        num = int(value)

        # 範囲チェック
        if self.min_val is not None and num < self.min_val:
            issues.append(ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message=f"{self.min_val}以上で入力してください",
                code="BELOW_MIN"
            ))
        if self.max_val is not None and num > self.max_val:
            issues.append(ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message=f"{self.max_val}以下で入力してください",
                code="ABOVE_MAX"
            ))

        return issues, corrected

class LengthValidator(FieldValidator):
    """文字数チェック"""

    def __init__(self, field: str, min_len: int = None, max_len: int = None,
                 warn_min: int = None, warn_max: int = None):
        self.field = field
        self.min_len = min_len
        self.max_len = max_len
        self.warn_min = warn_min
        self.warn_max = warn_max

    def validate(self, value: Any) -> Tuple[List[ValidationIssue], Optional[Any]]:
        if not isinstance(value, str):
            return [], None

        issues = []
        length = len(value)

        # エラー: 範囲外
        if self.min_len and length < self.min_len:
            issues.append(ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message=f"{self.min_len}文字以上で入力してください",
                code="TOO_SHORT"
            ))
        if self.max_len and length > self.max_len:
            issues.append(ValidationIssue(
                field=self.field,
                level=IssueLevel.ERROR,
                message=f"{self.max_len}文字以下で入力してください",
                code="TOO_LONG"
            ))

        # 警告: 推奨範囲外
        if not issues:  # エラーがない場合のみ警告
            if self.warn_min and length < self.warn_min:
                issues.append(ValidationIssue(
                    field=self.field,
                    level=IssueLevel.WARNING,
                    message=f"推奨: {self.warn_min}文字以上",
                    code="BELOW_RECOMMENDED"
                ))
            if self.warn_max and length > self.warn_max:
                issues.append(ValidationIssue(
                    field=self.field,
                    level=IssueLevel.WARNING,
                    message=f"推奨: {self.warn_max}文字以下",
                    code="ABOVE_RECOMMENDED"
                ))

        return issues, None
```

## 4. バリデーション実行

### 複数バリデータの組み合わせ

```python
class FieldValidation:
    """フィールドバリデーション定義"""

    def __init__(self, field: str):
        self.field = field
        self.validators: List[FieldValidator] = []

    def required(self, message: str = None):
        self.validators.append(RequiredValidator(
            self.field, message or f"{self.field}を入力してください"
        ))
        return self

    def numeric(self, min_val: int = None, max_val: int = None):
        self.validators.append(NumericValidator(self.field, min_val, max_val))
        return self

    def length(self, min_len: int = None, max_len: int = None):
        self.validators.append(LengthValidator(self.field, min_len, max_len))
        return self

    def validate(self, value: Any) -> Tuple[List[ValidationIssue], Optional[Any]]:
        all_issues = []
        final_corrected = None

        for validator in self.validators:
            issues, corrected = validator.validate(value)
            all_issues.extend(issues)
            if corrected is not None:
                final_corrected = corrected
                value = corrected  # 次のバリデータには修正値を使用

            # エラーがあれば以降のバリデーションをスキップ
            if any(i.level == IssueLevel.ERROR for i in issues):
                break

        return all_issues, final_corrected

# 使用例
def validate_registration(data: dict) -> ValidateResponse:
    all_issues = []
    corrected_values = {}

    # フィールドごとのバリデーション定義
    validations = {
        'site_id': FieldValidation('site_id').required().numeric(min_val=1, max_val=999),
        'menu_name': FieldValidation('menu_name').required().length(min_len=1, max_len=100),
        'price': FieldValidation('price').numeric(min_val=100, max_val=50000),
    }

    # 実行
    for field, validation in validations.items():
        if field in data:
            issues, corrected = validation.validate(data[field])
            all_issues.extend(issues)
            if corrected is not None:
                corrected_values[field] = corrected

    # 結果を分類
    errors = [i for i in all_issues if i.level == IssueLevel.ERROR]
    warnings = [i for i in all_issues if i.level == IssueLevel.WARNING]
    infos = [i for i in all_issues if i.level == IssueLevel.INFO]

    return ValidateResponse(
        valid=len(errors) == 0,
        errors=errors,
        warnings=warnings,
        infos=infos,
        corrected_values=corrected_values
    )
```

## 5. フロントエンド連携

### バリデーション結果の表示

```javascript
/**
 * バリデーション結果をUIに反映
 */
function displayValidationResult(result) {
    // エラーがあれば処理を中断
    if (!result.valid) {
        const errorMessages = result.errors.map(e => e.message).join('\n');
        showNotification(errorMessages, 'error');

        // フィールドにエラースタイルを適用
        result.errors.forEach(error => {
            const field = document.querySelector(`[name="${error.field}"]`);
            if (field) {
                field.classList.add('input-error');
                // エラーメッセージを表示
                const errorEl = document.createElement('div');
                errorEl.className = 'field-error';
                errorEl.textContent = error.message;
                field.parentNode.appendChild(errorEl);
            }
        });
        return false;
    }

    // 警告があれば表示（処理は継続）
    if (result.warnings && result.warnings.length > 0) {
        result.warnings.forEach(warning => {
            console.log(`⚠️ ${warning.field}: ${warning.message}`);
            // UIに警告スタイルを適用
            const field = document.querySelector(`[name="${warning.field}"]`);
            if (field) {
                field.classList.add('input-warning');
            }
        });
    }

    // 自動修正値を適用
    if (result.correctedValues && Object.keys(result.correctedValues).length > 0) {
        for (const [field, value] of Object.entries(result.correctedValues)) {
            const input = document.querySelector(`[name="${field}"]`);
            if (input) {
                input.value = value;
                input.classList.add('input-corrected');
            }
        }
    }

    return true;
}
```

### CSSスタイル

```css
/* バリデーション状態のスタイル */
.input-error {
    border-color: #dc3545 !important;
    background-color: #fff5f5;
}

.input-warning {
    border-color: #ffc107 !important;
    background-color: #fffbeb;
}

.input-corrected {
    border-color: #17a2b8 !important;
    background-color: #f0f9ff;
}

.field-error {
    color: #dc3545;
    font-size: 0.85em;
    margin-top: 4px;
}

.field-warning {
    color: #856404;
    font-size: 0.85em;
    margin-top: 4px;
}
```

## 6. バリデーションメッセージのi18n

```python
# messages.py
VALIDATION_MESSAGES = {
    "ja": {
        "REQUIRED": "{field}を入力してください",
        "NOT_NUMERIC": "数字のみで入力してください",
        "BELOW_MIN": "{min}以上で入力してください",
        "ABOVE_MAX": "{max}以下で入力してください",
        "TOO_SHORT": "{min}文字以上で入力してください",
        "TOO_LONG": "{max}文字以下で入力してください",
        "FULLWIDTH_CONVERTED": "全角文字が半角に変換されました",
    },
    "en": {
        "REQUIRED": "{field} is required",
        "NOT_NUMERIC": "Please enter numbers only",
        "BELOW_MIN": "Must be at least {min}",
        "ABOVE_MAX": "Must be at most {max}",
        "TOO_SHORT": "Must be at least {min} characters",
        "TOO_LONG": "Must be at most {max} characters",
        "FULLWIDTH_CONVERTED": "Full-width characters converted to half-width",
    }
}

def get_message(code: str, lang: str = "ja", **kwargs) -> str:
    template = VALIDATION_MESSAGES.get(lang, {}).get(code, code)
    return template.format(**kwargs)
```
