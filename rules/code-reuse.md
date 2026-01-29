# コード再利用ルール

## 共通パターンの重複禁止

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
