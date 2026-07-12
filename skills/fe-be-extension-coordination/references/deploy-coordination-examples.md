fe-be-extension-coordination の詳細（本文から 2026-07-11 P8 分離・内容不変）

## 4. デプロイ協調

### BE-first for breaking changes

```
1. BE: 新エンドポイント追加（後方互換）→ デプロイ
2. FE: 新エンドポイントに切り替え → デプロイ
3. BE: 旧エンドポイント廃止 → デプロイ
```

### Compatibility Matrix

```yaml
# extension-contracts/compatibility.yaml
compatibility:
  user-management:
    be: ">=1.2.0"
    fe: ">=1.1.0"
    notes: "BE 1.2.0 adds new /profile endpoint used by FE 1.1.0+"
  notification:
    be: ">=1.0.0"
    fe: ">=1.0.0"
```

### CI Pipeline 連携

```yaml
# .github/workflows/deploy-check.yml
name: Cross-repo Compatibility Check
on:
  pull_request:
    paths:
      - 'extensions/*/openapi.yaml'

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Compare with FE expectations
        run: |
          # Fetch FE repo's expected API types
          # Compare with BE's OpenAPI spec
          # Fail if breaking changes detected
          npx openapi-diff prev.yaml current.yaml
```
