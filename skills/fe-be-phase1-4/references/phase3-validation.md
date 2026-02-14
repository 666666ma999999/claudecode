# Phase 3: バリデーション統合 - 詳細

## 実装パターン

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

## 実装済み: Pre-STEP Validator パターン (v1.48.0)

StepHandler dataclass に `validator` フィールドを追加し、execute_step_generic 内でbuilder呼び出し前に自動実行。
- `validate_step3`: distribution の guide_text, category_code, yudo 検証
- `validate_step4`: menu_id 存在検証
- FE側: executeStepUnified が `validationErrors` / `validationWarnings` を自動表示
- バリデーション失敗時は step status を "error" に更新
- 成功時も warnings がある場合はレスポンスに含めて FE に通知
