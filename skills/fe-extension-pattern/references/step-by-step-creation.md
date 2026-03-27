# 新エクステンション作成手順（詳細コード）

> 親ファイル: `SKILL.md` — アーキテクチャ概要・10のルール・チェックリストはそちらを参照

## Step 1: ディレクトリ作成

```bash
mkdir -p src/extensions/{ext-name}/{types,components,hooks,pages,widgets,store}
```

## Step 2: 型定義 (`types/`)

```typescript
// src/extensions/{ext-name}/types/{entity}.ts
export interface MyEntity {
  readonly id: string;
  readonly name: string;
  readonly createdAt: string;
}
```

## Step 3: ストア (`store/`)

```typescript
// src/extensions/{ext-name}/store/{ext-name}-store.ts
import { create } from 'zustand';
import type { MyEntity } from '../types/my-entity';

interface MyExtStore {
  items: MyEntity[];
  selectedId: string | null;
  setItems: (items: MyEntity[]) => void;
  selectItem: (id: string | null) => void;
}

export const useMyExtStore = create<MyExtStore>((set) => ({
  items: [],
  selectedId: null,
  setItems: (items) => set({ items }),
  selectItem: (id) => set({ selectedId: id }),
}));
```

## Step 4: フック (`hooks/`)

```typescript
// src/extensions/{ext-name}/hooks/use{Entity}.ts
import { useState, useEffect } from 'react';
import { useCoreServices } from '@/core';
import type { MyEntity } from '../types/my-entity';

export function useMyEntities() {
  const { api } = useCoreServices();
  const [items, setItems] = useState<MyEntity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api.get<MyEntity[]>('/my-entities')
      .then((data) => { if (!cancelled) setItems(data); })
      .catch((err) => { if (!cancelled) setError(err.message); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [api]);

  return { items, loading, error };
}
```

## Step 5: コンポーネント (`components/`)

```typescript
// src/extensions/{ext-name}/components/MyTable.tsx
import type { MyEntity } from '../types/my-entity';

interface Props {
  readonly items: MyEntity[];
}

export function MyTable({ items }: Props) {
  if (items.length === 0) return <p>No items found.</p>;
  return (
    <table>
      <thead><tr><th>Name</th></tr></thead>
      <tbody>
        {items.map((item) => (
          <tr key={item.id}><td>{item.name}</td></tr>
        ))}
      </tbody>
    </table>
  );
}
```

## Step 6: ページ (`pages/`)

```typescript
// src/extensions/{ext-name}/pages/MyPage.tsx
import { useMyEntities } from '../hooks/useMyEntities';
import { MyTable } from '../components/MyTable';

export default function MyPage() {
  const { items, loading, error } = useMyEntities();
  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error}</p>;
  return <MyTable items={items} />;
}
```

## Step 7: ウィジェット (`widgets/`)

```typescript
// src/extensions/{ext-name}/widgets/MyCountCard.tsx
import { useState, useEffect } from 'react';
import { useCoreServices } from '@/core';
import type { MountPointProps } from '@/core';
import { Card } from '@/shared/components/Card';

export default function MyCountCard(_props: MountPointProps) {
  const { api } = useCoreServices();
  const [count, setCount] = useState<number>(0);

  useEffect(() => {
    api.get<{ count: number }>('/my-entities/count')
      .then((data) => setCount(data.count));
  }, [api]);

  return <Card title="My Items">{count} items</Card>;
}
```

## Step 8: マニフェスト (`index.ts`)

```typescript
// src/extensions/{ext-name}/index.ts
import type { ExtensionManifest } from '@/core';

const manifest: ExtensionManifest = {
  id: '{ext-name}',
  name: '{Extension Display Name}',
  version: '1.0.0',
  description: '{description}',
  navigation: [
    { label: '{Label}', path: '/{ext-name}', icon: '{icon}', order: 10 },
  ],
  routes: [
    { path: '/{ext-name}', component: () => import('./pages/MyPage') },
  ],
  mountPoints: [
    {
      mountPoint: 'dashboard-widgets',
      component: () => import('./widgets/MyCountCard'),
      order: 10,
    },
  ],
};

export default manifest;
```

## Step 9: 登録

`config/extensions.json` に追加:
```json
{
  "enabled": ["existing-ext", "{ext-name}"]
}
```

その後 codegen スクリプトを実行:
```bash
npx ts-node scripts/generate-extension-loader.ts
npx ts-node scripts/generate-eslint-zones.ts
```
