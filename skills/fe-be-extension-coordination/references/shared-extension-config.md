fe-be-extension-coordination の詳細（本文から 2026-07-11 P8 分離・内容不変）

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
