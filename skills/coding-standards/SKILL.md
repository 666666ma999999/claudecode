---
name: coding-standards
description: |
  プログラミング言語・フレームワーク別の命名規則と実装標準。新規コード生成時・既存コードレビュー時に自動適用。
  発動条件: 新規ファイル作成、API設計、コードレビュー、「命名規則」「コーディング規約」言及時
---

# Coding Standards Skill

## 発動条件

以下の場面で自動適用:
- 新規Python/JavaScriptファイル作成
- APIエンドポイント設計・Pydanticモデル定義
- コードレビュー・リファクタリング
- 「命名規則」「コーディング規約」「naming convention」言及時

## 命名規則クイックリファレンス

| 言語 | 変数・関数 | クラス | 定数 | ファイル名 |
|------|-----------|--------|------|-----------|
| Python | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.py |
| JS/TS | camelCase | PascalCase | UPPER_SNAKE_CASE | camelCase.js / PascalCase.tsx |
| HTML/CSS | - | - | - | kebab-case |
| SQL | snake_case | - | - | snake_case.sql |
| API URL | kebab-case | - | - | `/api/user-profiles` |
| JSON応答 | camelCase | - | - | `{"userId": 123}` |

> 詳細: `references/naming-conventions.md`

## コア原則

### 1. 新規コード: 標準規則を適用

言語ごとの標準命名規則に従う。詳細は各referenceファイルを参照。

### 2. 既存コード改修: 周辺コードに合わせる

**新規コードの命名規則より既存の一貫性を優先**する。ただしAPI境界は常に標準規則を適用。

命名規則変更が許可されるケース: ユーザーによるリファクタリング明示指示、ファイル全体書き直し、新規プロジェクト移行のみ。

### 3. FE/BE境界: CamelCaseModelで自動変換

```python
class CamelCaseModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        serialize_by_alias=True,
    )
```

BE内部(snake_case) -> API(camelCase) -> FE(camelCase)。手動変換は禁止。

> 詳細: `references/python-standards.md`

### 4. 同義語・重複変数名チェック（必須）

同じ値に異なる名前がついていないか確認。Case変換では検出できない。
FE/BEで同じ概念を表す変数を列挙し、名前の一致を検証すること。

> 詳細: `references/naming-conventions.md`

### 5. 識別子変更時: Grepで全影響範囲を特定

STEP番号・フィールド名・定数名の変更前に `grep -rn "変更前の値"` で全ファイル検索。1ファイルでも漏れると不整合が発生する。

> 詳細: `references/naming-conventions.md`

## 言語別詳細リファレンス

| ファイル | 内容 |
|---------|------|
| `references/python-standards.md` | Python命名規則、CamelCaseModel、チェックリスト、既存コード改修ルール、Disconnected Pipe Pattern |
| `references/javascript-standards.md` | JS/TS/HTML/CSS命名規則、チェックリスト、落とし穴パターン、セキュリティ（OWASP） |
| `references/api-standards.md` | API命名規則、3層タイムアウト設計、プロジェクト別カスタマイズ |
| `references/naming-conventions.md` | 命名規則マトリクス完全版、同義語検出、識別子変更時の整合性チェック |

## 共通スニペット（コピー用）

| ファイル | 内容 |
|---------|------|
| `references/common-snippets.py` | CamelCaseModel, ValidationResponse, 標準レスポンス |
| `references/common-snippets.js` | apiRequest, ProgressAnimator, loadAppConfig |

### 使用手順

1. **検索**: プロジェクト内で既存実装を検索
2. **見つかった場合**: 既存実装をインポート/参照
3. **見つからない場合**: `references/common-snippets.*` からコピー

## コード品質チェックリスト（Codexレビュー知見）

### Disconnected Pipe Pattern（最重要）

Optional引数チェーンで中間関数がパラメータを渡し忘れてもdefault値で動く問題。パラメータ追加時は `grep -rn "関数名"` で全呼び出し元を検索し伝搬確認。

> 詳細: `references/python-standards.md`

### JavaScript落とし穴（要約）

- `if (value)` で `0` を見逃す -> `value != null` を使う
- Dict値表示で `[object Object]` -> `JSON.stringify()` を使う
- ハードコード件数 -> 動的取得に変更

> 詳細: `references/javascript-standards.md`

### セキュリティ（要約）

- inline onclick + 文字列補間 -> XSSリスク
- ユーザー入力のファイルパス使用 -> Path Traversalリスク
- API応答に内部パス -> 情報漏洩リスク

> 詳細: `references/javascript-standards.md`

## 関連スキル

- **fe-be-integration**: FE/BE統合パターン、CamelCaseModelの詳細実装
- **process-state-management**: セッションデータの構造設計
