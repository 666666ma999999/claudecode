# 命名規則（全プロジェクト共通）

## 言語別ルール

| 言語/領域 | 規則 | 例 |
|-----------|------|-----|
| Python変数・関数 | snake_case | `user_name`, `get_user_data()` |
| Pythonクラス | PascalCase | `UserResponse`, `CamelCaseModel` |
| JavaScript変数・関数 | camelCase | `userName`, `getUserData()` |
| JavaScriptクラス | PascalCase | `ProgressAnimator` |
| API JSONレスポンス | camelCase | `{"userId": 1, "displayName": "..."}` |
| HTMLのid/class | kebab-case | `user-name`, `input-section` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRIES`, `API_TOKEN` |

## FE/BE境界のルール

```
BE内部(Python)     →  API JSON      →  FE(JavaScript)
snake_case            camelCase         camelCase
user_name          →  userName       →  userName
is_active          →  isActive       →  isActive
```

**実装方法**: `CamelCaseModel`ベースクラスを使用

## 新規API作成時の必須チェック

- [ ] レスポンスモデルが`CamelCaseModel`を継承しているか
- [ ] フィールド名がsnake_caseで定義されているか（自動変換される）
- [ ] FE側でcamelCaseで参照しているか
