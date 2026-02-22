---
name: test-fixing
description: |
  テスト失敗を効率的に修正するスキル。言語・フレームワークを問わず、
  体系的なアプローチでテストを修正する。
  キーワード: テスト修正, テスト失敗, デバッグ, TDD
allowed-tools: "Bash Read Write Edit Glob Grep"
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: testing-qa
  tags: [testing, debugging, tdd]
---

# Test Fixing

テスト失敗を効率的に修正するためのスキル。言語・フレームワークを問わず、体系的なアプローチでテストを修正します。

## トリガー

以下のフレーズで発動します：
- 「テストを修正」「テストが失敗」「テストを直して」
- 「test fix」「failing test」
- 「アサーションエラー」「assertion error」

## 修正フロー

### 1. エラーの分類

テスト失敗は以下のカテゴリに分類される：

| カテゴリ | 原因 | 対応 |
|----------|------|------|
| **アサーション失敗** | 期待値と実際値の不一致 | 期待値の更新 or 実装の修正 |
| **型エラー** | 型の不一致、undefined | 型定義の修正、null チェック追加 |
| **モック/スタブ問題** | モックの設定不備 | モックの更新、戻り値の修正 |
| **インポートエラー** | モジュール解決失敗 | パス修正、依存関係確認 |
| **タイムアウト** | 非同期処理の遅延 | タイムアウト延長、await 確認 |
| **環境依存** | 環境変数、ファイルパス | 環境設定、フィクスチャ確認 |

### 2. 診断手順

```
1. エラーメッセージを読む
   ↓
2. 失敗したテストファイルを特定
   ↓
3. 該当テストケースを確認
   ↓
4. テスト対象の実装コードを確認
   ↓
5. 原因を特定（テストが間違い or 実装が間違い）
   ↓
6. 修正を実施
   ↓
7. テストを再実行して確認
```

### 3. 修正の判断基準

**テストを修正すべき場合：**
- 仕様変更により期待値が変わった
- テストの前提条件が古い
- モックが実際のAPIと乖離している
- テストの書き方自体に問題がある

**実装を修正すべき場合：**
- テストが正しい仕様を反映している
- リグレッション（既存機能の破壊）
- バグの発見

## 言語別コマンド

### Python (pytest)

```bash
# 全テスト実行
pytest

# 特定ファイル
pytest tests/test_example.py

# 特定テスト関数
pytest tests/test_example.py::test_function_name

# 特定クラス
pytest tests/test_example.py::TestClass

# 失敗したテストのみ再実行
pytest --lf

# 詳細出力
pytest -v

# 最初の失敗で停止
pytest -x

# 出力をキャプチャしない（print文を表示）
pytest -s
```

### JavaScript (Jest)

```bash
# 全テスト実行
npm test
# または
jest

# 特定ファイル
jest path/to/test.spec.js

# 特定テスト名
jest -t "test name pattern"

# watch モード
jest --watch

# カバレッジ
jest --coverage

# 詳細出力
jest --verbose
```

### JavaScript (Vitest)

```bash
# 全テスト実行
npx vitest run

# watch モード
npx vitest

# 特定ファイル
npx vitest run src/utils.test.ts

# UI モード
npx vitest --ui
```

### TypeScript

```bash
# 型チェック
npx tsc --noEmit

# 特定ファイルの型チェック
npx tsc --noEmit path/to/file.ts
```

## 修正パターン

### アサーション修正

**Python (pytest)**
```python
# Before: 期待値が古い
assert result == "old value"

# After: 新しい期待値
assert result == "new value"

# より詳細なアサーション
assert result == expected, f"Expected {expected}, got {result}"
```

**JavaScript (Jest)**
```javascript
// Before
expect(result).toBe("old value");

// After
expect(result).toBe("new value");

// オブジェクト比較
expect(result).toEqual({ key: "value" });

// 部分一致
expect(result).toMatchObject({ key: "value" });
```

### モック修正

**Python (pytest)**
```python
# モックの戻り値を更新
@patch("module.function")
def test_example(mock_func):
    mock_func.return_value = "new return value"
    # ...

# 非同期モック
@patch("module.async_function")
async def test_async(mock_func):
    mock_func.return_value = AsyncMock(return_value="value")
```

**JavaScript (Jest)**
```javascript
// モックの戻り値を更新
jest.mock("./module", () => ({
  functionName: jest.fn().mockReturnValue("new value"),
}));

// 非同期モック
jest.mock("./api", () => ({
  fetchData: jest.fn().mockResolvedValue({ data: "value" }),
}));

// 実装をリセット
beforeEach(() => {
  jest.clearAllMocks();
});
```

### 型エラー修正

**TypeScript**
```typescript
// Before: 型エラー
const result: string = getValue(); // getValue() returns string | undefined

// After: null チェック追加
const result = getValue();
expect(result).toBeDefined();
if (result) {
  expect(result).toBe("expected");
}

// または型アサーション（テスト内のみ）
const result = getValue() as string;
```

**Python (型ヒント)**
```python
# Before: Optional 型の扱い
def get_value() -> Optional[str]:
    ...

# After: None チェック追加
result = get_value()
assert result is not None
assert result == "expected"
```

### 非同期テスト修正

**Python**
```python
# Before: sync テスト
def test_example():
    result = my_async_function()  # エラー

# After: async テスト
@pytest.mark.asyncio
async def test_example():
    result = await my_async_function()
    assert result == expected
```

**JavaScript**
```javascript
// Before: Promise が解決されない
test("example", () => {
  const result = asyncFunction();
  expect(result).toBe(expected); // エラー
});

// After: async/await
test("example", async () => {
  const result = await asyncFunction();
  expect(result).toBe(expected);
});
```

### インポートエラー修正

```python
# Before: 相対インポートの問題
from utils import helper  # ModuleNotFoundError

# After: 正しいパス
from src.utils import helper
# または
from .utils import helper
```

```javascript
// Before: パスエラー
import { helper } from "utils"; // Cannot find module

// After: 正しいパス
import { helper } from "../utils";
// または（エイリアス設定後）
import { helper } from "@/utils";
```

### 環境依存の修正

```python
# フィクスチャで環境変数を設定
@pytest.fixture
def env_setup(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key")
    yield

def test_with_env(env_setup):
    # テスト実行
    pass
```

```javascript
// 環境変数のモック
beforeEach(() => {
  process.env.API_KEY = "test-key";
});

afterEach(() => {
  delete process.env.API_KEY;
});
```

## 複数テスト失敗時の対応

### 優先順位

1. **インポート/型エラー** → 他のテストに影響するため最優先
2. **setup/fixture エラー** → 複数テストの前提条件
3. **個別のアサーション失敗** → 1つずつ対応

### 効率的な修正フロー

```bash
# 1. まず1つだけ実行して修正
pytest tests/test_example.py::test_first -v

# 2. 修正後、関連テストを実行
pytest tests/test_example.py -v

# 3. 全テストで確認
pytest
```

## チェックリスト

修正前：
- [ ] エラーメッセージを完全に読んだか
- [ ] 失敗したテストの意図を理解したか
- [ ] テスト対象の実装を確認したか
- [ ] テストを修正すべきか、実装を修正すべきか判断したか

修正後：
- [ ] 修正したテストが通るか確認
- [ ] 他のテストに影響がないか確認
- [ ] 全テストスイートを実行して確認

## ユーザーへの確認事項

以下の判断が必要な場合は AskUserQuestion で確認：
- テストと実装のどちらを修正すべきか不明な場合
- 仕様変更が関係している可能性がある場合
- 複数の修正方法がある場合

## Sentryスタックトレースからの修正（任意）

Sentry MCPが有効な場合、以下の手順でSentryのエラーからテスト修正に活用できる：

1. Sentry MCPの `get_issue` でスタックトレースを取得
2. スタックトレースから該当ファイル・行番号を特定
3. 上記の修正パターン（アサーション/型エラー/非同期等）を適用
4. 修正後、Sentry MCPの `update_issue` でissueをresolvedに更新

### Sentry未導入時
- この手順はスキップし、従来の修正フローのみを使用する
