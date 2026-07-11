test-fixing の詳細（本文から 2026-07-11 P8 分離・内容不変）

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
