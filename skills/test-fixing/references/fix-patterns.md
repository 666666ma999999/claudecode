test-fixing の詳細（本文から 2026-07-11 P8 分離・内容不変）

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
