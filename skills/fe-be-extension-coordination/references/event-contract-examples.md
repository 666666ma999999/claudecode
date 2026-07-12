fe-be-extension-coordination の詳細（本文から 2026-07-11 P8 分離・内容不変）

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
