---
name: fe-be-extension-coordination
description: |
  FE+BE分離型リポジトリプロジェクトでエクステンション間の調整を指導するスキル。
  共有エクステンション設定、APIコントラクト、一貫したExtension ID、デプロイ協調、
  イベントコントラクト共有のガイド。FE+BE連携・APIコントラクト設計時に使用。
  キーワード: FE+BE連携, APIコントラクト, 共有Extension ID, デプロイ協調, イベントコントラクト
  NOT for: FE単体実装, BE単体実装, インフラ構成
allowed-tools: "Read Glob Grep"
license: proprietary
metadata:
  category: guide-reference
  tags: [fullstack, architecture, coordination, api-contract]
---

# FE+BE Extension Coordination Guide

## 1. 共有エクステンション設定

### extension-contracts パッケージ

FEとBEで共有するエクステンション定義を一元管理するnpmパッケージ（またはgit submodule）。

```
extension-contracts/           # 独立リポジトリ or monorepo内パッケージ
├── package.json
├── src/
│   ├── extension-ids.ts       # EXTENSION_IDS 定数
│   ├── extensions.yaml        # 有効エクステンション一覧（SSOT）
│   ├── events/                # 共有イベント型
│   │   ├── index.ts
│   │   └── user-events.ts
│   └── api/                   # APIコントラクト型
│       ├── index.ts
│       └── user-api.ts
└── tsconfig.json
```

### EXTENSION_IDS 定数

```typescript
// extension-contracts/src/extension-ids.ts
export const EXTENSION_IDS = {
  USER_MANAGEMENT: 'user-management',
  NOTIFICATION: 'notification',
  BILLING: 'billing',
  ANALYTICS: 'analytics',
} as const;

export type ExtensionId = typeof EXTENSION_IDS[keyof typeof EXTENSION_IDS];
```

### extensions.yaml (Single Source of Truth)

```yaml
# extension-contracts/src/extensions.yaml
extensions:
  - id: user-management
    fe: true
    be: true
    description: "ユーザー管理"
  - id: notification
    fe: true
    be: true
    description: "通知システム"
  - id: billing
    fe: true
    be: true
    description: "課金・決済"
  - id: analytics
    fe: false       # FEなし（BEのみ）
    be: true
    description: "分析・レポート"
```

### ランタイム設定サービス（オプション）

```typescript
// BE: Extension Configuration API
// GET /api/extensions/config
// Returns: { enabled: ExtensionId[], featureFlags: Record<string, boolean> }
// FE: Fetches config at boot to sync enabled extensions
```

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

## 3. 一貫したExtension ID

### 命名規則

| 項目 | ルール | 例 |
|------|--------|-----|
| Extension ID | kebab-case | `user-management` |
| FE ディレクトリ | kebab-case | `extensions/user-management/` |
| BE ディレクトリ (Python) | snake_case | `extensions/user_management/` |
| BE ディレクトリ (Node.js) | kebab-case | `extensions/user-management/` |
| API prefix | kebab-case | `/api/user-management/` |
| Event prefix | kebab-case + colon | `user:created` |
| DB table prefix | snake_case | `ext_user_management_*` |
| EXTENSION_IDS key | UPPER_SNAKE_CASE | `USER_MANAGEMENT` |

### CI検証スクリプト

```typescript
// scripts/validate-extension-ids.ts
import { EXTENSION_IDS } from 'extension-contracts';
import fs from 'fs';
import yaml from 'js-yaml';

// 1. FE extensions check
const feExtensions = fs.readdirSync('fe-repo/src/extensions');
// 2. BE extensions check
const beExtensions = fs.readdirSync('be-repo/src/extensions');
// 3. extensions.yaml check
const config = yaml.load(
  fs.readFileSync('extension-contracts/src/extensions.yaml', 'utf8')
);

const ids = Object.values(EXTENSION_IDS);

for (const id of ids) {
  const ext = config.extensions.find((e: any) => e.id === id);
  if (!ext) {
    console.error(`Missing in extensions.yaml: ${id}`);
    process.exit(1);
  }
  if (ext.fe && !feExtensions.includes(id)) {
    console.error(`FE directory missing for: ${id}`);
    process.exit(1);
  }
  // Python BE uses snake_case
  const beDir = id.replace(/-/g, '_');
  if (ext.be && !beExtensions.includes(id) && !beExtensions.includes(beDir)) {
    console.error(`BE directory missing for: ${id}`);
    process.exit(1);
  }
}
console.log('All extension IDs are consistent!');
```

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

## 5. イベントコントラクト共有

### SharedEvents interface

```typescript
// extension-contracts/src/events/index.ts
export interface SharedEvents {
  // User events
  'user:created': { userId: string; email: string };
  'user:updated': { userId: string; changes: string[] };
  'user:deleted': { userId: string };

  // Notification events
  'notification:created': {
    message: string;
    level: 'info' | 'warn' | 'error';
    targetUserId?: string;
  };

  // Billing events
  'billing:payment-completed': {
    orderId: string;
    amount: number;
    currency: string;
  };
  'billing:subscription-changed': { userId: string; plan: string };
}
```

### FEでの使用

```typescript
// FE: src/core/types/events.ts
// extension-contracts から re-export
export type { SharedEvents as CoreEvents } from 'extension-contracts';
```

### BEでの使用

```python
# BE (Python): core/interfaces/events.py
# TypedDict で SharedEvents を再現
from typing import TypedDict

class UserCreatedEvent(TypedDict):
    userId: str
    email: str

class NotificationCreatedEvent(TypedDict):
    message: str
    level: str  # 'info' | 'warn' | 'error'
    targetUserId: str | None
```

```typescript
// BE (Node.js): core/interfaces/events.ts
// extension-contracts から直接 import
import type { SharedEvents } from 'extension-contracts';
export type CoreEvents = SharedEvents;
```

## 6. 10のルール

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | Extension IDは `extension-contracts` で一元管理 | FE/BEで別々にID定義 | EXTENSION_IDS 定数から参照 |
| 2 | extensions.yamlがSSoT | FEとBEで別のconfig | 1つのyamlから両方生成 |
| 3 | APIコントラクトはOpenAPI specで定義 | 口頭合意やドキュメントのみ | per-ext openapi.yaml |
| 4 | FE向け型はCI自動生成 | 手動で型を同期 | openapi-typescript で自動生成 |
| 5 | イベント型は `SharedEvents` で共有 | FE/BEで別々にイベント型定義 | extension-contracts に定義 |
| 6 | Breaking changeはBE-first | FE/BE同時デプロイ前提 | 後方互換 → FE切替 → 旧API廃止 |
| 7 | Python BE dirはsnake_case、他はkebab-case | 命名不統一 | 変換テーブル参照 |
| 8 | DB table prefixは `ext_{snake_id}_` | ext間でテーブル名衝突 | `ext_user_management_profiles` |
| 9 | 各ext PRにFE/BE影響チェック | BE変更がFE未考慮 | PR templateに影響チェック欄 |
| 10 | Compatibility matrixで互換性管理 | バージョン依存が不明 | compatibility.yaml 更新 |
