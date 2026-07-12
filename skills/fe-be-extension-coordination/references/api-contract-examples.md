fe-be-extension-coordination の詳細（本文から 2026-07-11 P8 分離・内容不変）

## 2. APIコントラクト調整

### OpenAPI spec per extension

各エクステンションが自身のOpenAPI specを持つ。

```
be-repo/
└── extensions/
    └── user-management/
        └── openapi.yaml       # per-extension OpenAPI spec
```

```yaml
# extensions/user-management/openapi.yaml
openapi: "3.0.3"
info:
  title: "User Management Extension API"
  version: "1.0.0"
paths:
  /api/user-management/users:
    get:
      operationId: listUsers
      responses:
        '200':
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
    post:
      operationId: createUser
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserCreate'
components:
  schemas:
    User:
      type: object
      properties:
        id: { type: string }
        name: { type: string }
        email: { type: string, format: email }
    UserCreate:
      type: object
      required: [name, email]
      properties:
        name: { type: string }
        email: { type: string, format: email }
```

### CI型生成ワークフロー

```yaml
# .github/workflows/generate-types.yml
name: Generate API Types
on:
  push:
    paths:
      - 'extensions/*/openapi.yaml'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate TypeScript types
        run: |
          for spec in extensions/*/openapi.yaml; do
            ext=$(basename $(dirname $spec))
            npx openapi-typescript "$spec" -o "generated/api/${ext}.d.ts"
          done
      - name: Publish to extension-contracts
        run: |
          cp generated/api/* ../extension-contracts/src/api/
          cd ../extension-contracts && npm version patch && npm publish
```
