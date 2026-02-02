# コーディング規約（全プロジェクト共通）

## 命名規則

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

## 共通パターンの再利用（重複禁止）

以下のパターンは**既存実装を検索して再利用**すること。新規作成禁止。

| パターン | 検索キーワード | 用途 |
|---------|---------------|------|
| CamelCaseModel | `class CamelCaseModel` | APIレスポンスのcamelCase変換 |
| to_camel | `def to_camel` | snake_case→camelCase変換 |
| ProgressAnimator | `class ProgressAnimator` | 進捗表示UI |
| apiRequest | `function apiRequest` | API呼び出しラッパー |

## 新規プロジェクトでの手順

1. **既存プロジェクトを検索**: `Grep`で上記パターンを検索
2. **見つかった場合**: コピーして使用（または共通ライブラリから参照）
3. **見つからない場合のみ**: 新規作成し、スキルに実装パターンを追記
