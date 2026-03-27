# 実装パターン詳細

> 親ファイル: `SKILL.md` — アーキテクチャ概要・10のルール・チェックリストはそちらを参照

## ExtensionManifest の書き方

```typescript
import type { ExtensionManifest } from '@/core';

const manifest: ExtensionManifest = {
  // 必須フィールド
  id: 'my-extension',           // ユニークID（kebab-case）
  name: 'My Extension',         // 表示名
  version: '1.0.0',             // セマンティックバージョン
  description: 'What it does',  // 説明

  // ナビゲーション（サイドバーに項目追加）
  navigation: [
    { label: 'My Feature', path: '/my-feature', icon: 'star', order: 20 },
  ],

  // ルーティング（ページ登録）
  routes: [
    { path: '/my-feature', component: () => import('./pages/MainPage') },
    { path: '/my-feature/:id', component: () => import('./pages/DetailPage') },
  ],

  // MountPoint（他のページにウィジェットを注入）
  mountPoints: [
    {
      mountPoint: 'dashboard-widgets',
      component: () => import('./widgets/SummaryCard'),
      order: 20,
    },
    {
      mountPoint: 'settings-panels',
      component: () => import('./widgets/SettingsPanel'),
      order: 10,
    },
  ],

  // ライフサイクル（オプション）
  lifecycle: {
    onInit: async (services) => {
      services.events.on('user:updated', (data) => {
        console.log('User updated:', data.userId);
      });
    },
    onDestroy: () => {
      // クリーンアップ
    },
  },
};

export default manifest;
```

### 利用可能な MountPoint

| MountPoint名 | 配置場所 | 用途 |
|---------------|---------|------|
| `dashboard-widgets` | ダッシュボード | サマリーカード、グラフ |
| `sidebar-bottom` | サイドバー下部 | クイックアクション |
| `settings-panels` | 設定画面 | ext 固有の設定 |
| `header-actions` | ヘッダー右側 | アクションボタン |
| `user-profile-tabs` | ユーザープロフィール | 追加タブ |

## MountPoint ウィジェットの実装パターン

```typescript
// widgets/MyWidget.tsx
import { useState, useEffect } from 'react';
import type { MountPointProps } from '@/core';
import { Card } from '@/shared/components/Card';

// MountPointProps を受け取ることが必須
export default function MyWidget({ services }: MountPointProps) {
  const [data, setData] = useState<number>(0);

  useEffect(() => {
    services.api.get<{ value: number }>('/my-endpoint')
      .then((res) => setData(res.value));
  }, [services.api]);

  return <Card title="My Widget">{data}</Card>;
}
```

**ポイント**:
- `MountPointProps` を受け取る（`services` 経由でコアサービスにアクセス）
- `default export` 必須（lazy import のため）
- 自己完結型（親コンポーネントに依存しない）

## ページの実装パターン

```typescript
// pages/MyPage.tsx
import { useMyData } from '../hooks/useMyData';
import { MyList } from '../components/MyList';

// default export 必須
export default function MyPage() {
  const { data, loading, error } = useMyData();

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div>
      <h1>My Feature</h1>
      <MyList items={data} />
    </div>
  );
}
```

**ポイント**:
- `default export` 必須（dynamic import のため）
- データ取得はカスタムフックに委譲
- Loading / Error 状態を必ずハンドリング

## Zustand ストアのパターン

```typescript
// store/my-store.ts
import { create } from 'zustand';
import type { MyEntity } from '../types/my-entity';

interface MyStore {
  // State
  items: MyEntity[];
  selectedId: string | null;
  filter: string;

  // Actions
  setItems: (items: MyEntity[]) => void;
  selectItem: (id: string | null) => void;
  setFilter: (filter: string) => void;
  reset: () => void;
}

const initialState = {
  items: [] as MyEntity[],
  selectedId: null as string | null,
  filter: '',
};

export const useMyStore = create<MyStore>((set) => ({
  ...initialState,
  setItems: (items) => set({ items }),
  selectItem: (id) => set({ selectedId: id }),
  setFilter: (filter) => set({ filter }),
  reset: () => set(initialState),
}));
```

**ポイント**:
- ストアは ext 内に閉じる（グローバルストアに追加しない）
- State と Actions を interface で明示
- `reset()` を用意（ext disable 時のクリーンアップ用）

## EventBus による ext 間通信

### イベント定義（Core）

```typescript
// src/core/types/events.ts（Core で定義済み。変更しない）
export interface CoreEvents {
  'user:updated': { userId: string };
  'user:deleted': { userId: string };
  'notification:created': { message: string; level: 'info' | 'warn' | 'error' };
  'theme:changed': { theme: 'light' | 'dark' };
}
```

### イベント発火（送信側 ext）

```typescript
// ext-a 内
const { events } = useCoreServices();
events.emit('user:updated', { userId: '123' });
```

### イベント購読（受信側 ext）

```typescript
// ext-b 内のフック
import { useEffect } from 'react';
import { useCoreServices } from '@/core';

export function useUserUpdates(callback: (userId: string) => void) {
  const { events } = useCoreServices();

  useEffect(() => {
    const unsubscribe = events.on('user:updated', (data) => {
      callback(data.userId);
    });
    return unsubscribe; // クリーンアップ
  }, [events, callback]);
}
```

### ライフサイクルでの購読

```typescript
// ext-b/index.ts
lifecycle: {
  onInit: async (services) => {
    services.events.on('user:deleted', (data) => {
      // ユーザー削除時の処理
      useMyStore.getState().removeByUserId(data.userId);
    });
  },
},
```

**ポイント**:
- 新しいイベント型の追加は `CoreEvents` を変更する必要がある（Core 変更 = 慎重に検討）
- `useEffect` の cleanup で必ず `unsubscribe` する
- 型安全: `emit` / `on` は `CoreEvents` のキーで型チェックされる
