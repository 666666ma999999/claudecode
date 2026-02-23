---
name: fe-extension-pattern
description: |
  FEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。
  新エクステンション作成、ページ追加、ウィジェット追加、MountPoint実装、Zustandストア設計、
  EventBusによるext間通信のガイド。FE新機能追加・ページ追加・ウィジェット追加時に使用。
  キーワード: エクステンション作成, ページ追加, ウィジェット追加, FEアーキテクチャ, MountPoint, EventBus, Zustand
  NOT for: バックエンド実装, インフラ構成, DB設計, 既存バグ修正（アーキテクチャ変更を伴わない場合）
allowed-tools: "Read Glob Grep"
---

# FE エクステンションパターン ガイド

## 1. アーキテクチャ概要

エクステンションパターンは、FEアプリケーションをプラグイン形式で拡張するアーキテクチャ。

```
src/
├── core/           # フレームワーク（変更しない）
│   ├── types/      # 共通型定義
│   ├── registry/   # エクステンション登録
│   ├── services/   # コアサービス
│   ├── providers/  # Reactプロバイダー
│   ├── components/ # コアコンポーネント
│   └── index.ts    # パブリックAPI
├── shared/         # 共有UIコンポーネント
│   └── components/ # Button, Card etc.
├── extensions/     # 各エクステンション（ここに機能を追加）
│   ├── ext-a/
│   └── ext-b/
├── app/            # Next.js App Router
│   ├── layout.tsx
│   ├── (core)/     # コアページ
│   └── (extensions)/ # エクステンションルーティング
└── config/
    └── extensions.json  # 有効なエクステンション一覧
```

### 設計原則

- **Core は変更しない**: `src/core/` はフレームワーク。機能追加は `src/extensions/` のみ
- **隔離**: エクステンション同士は直接importしない
- **プラグイン**: enable/disable で機能の ON/OFF が可能
- **依存方向**: `extensions → core` / `extensions → shared` のみ許可

## 2. 新エクステンション作成手順

### Step 1: ディレクトリ作成

```bash
mkdir -p src/extensions/{ext-name}/{types,components,hooks,pages,widgets,store}
```

### Step 2: 型定義 (`types/`)

```typescript
// src/extensions/{ext-name}/types/{entity}.ts
export interface MyEntity {
  readonly id: string;
  readonly name: string;
  readonly createdAt: string;
}
```

### Step 3: ストア (`store/`)

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

### Step 4: フック (`hooks/`)

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

### Step 5: コンポーネント (`components/`)

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

### Step 6: ページ (`pages/`)

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

### Step 7: ウィジェット (`widgets/`)

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

### Step 8: マニフェスト (`index.ts`)

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

### Step 9: 登録

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

## 3. 10のルール（チートシート）

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `src/core/` は変更しない | core に新しい型を追加 | ext 内に型を定義 |
| 2 | ext 間の直接 import 禁止 | `import { X } from '../other-ext/...'` | EventBus で通信 |
| 3 | 依存方向: ext → core, ext → shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `index.ts` (manifest) 必須 | manifest なしの ext | ExtensionManifest を export |
| 5 | ページは `pages/` に配置、lazy import | 直接 import でバンドル肥大化 | `() => import('./pages/...')` |
| 6 | ウィジェットは `widgets/` に配置 | コンポーネントに MountPoint ロジック混在 | MountPointProps を受け取る widget |
| 7 | ストアは ext 内に閉じる | グローバルストアに ext のステートを追加 | ext 内 Zustand ストア |
| 8 | ext 間通信は EventBus のみ | 共有グローバル変数 | `services.events.emit()` / `.on()` |
| 9 | `config/extensions.json` で ON/OFF | ハードコードされた import | enabled 配列から削除で無効化 |
| 10 | ESLint zones で隔離を強制 | zone 設定なしでレビュー頼み | `generate-eslint-zones.ts` 実行 |

## 4. ExtensionManifest の書き方

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
      mountPoint: 'dashboard-widgets',   // ターゲット MountPoint 名
      component: () => import('./widgets/SummaryCard'),
      order: 20,                         // 表示順
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
      // ext 初期化処理（EventBus 購読など）
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

## 5. MountPoint ウィジェットの実装パターン

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

## 6. ページの実装パターン

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

## 7. Zustand ストアのパターン

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

## 8. EventBus による ext 間通信

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

## 9. 検証チェックリスト

### 隔離性チェック

- [ ] `src/extensions/{ext}/` 内からの import が `@/core`, `@/shared/*`, 自ext内のみ
- [ ] 他の ext ディレクトリからの import がない
- [ ] `src/core/` を変更していない
- [ ] ESLint zones で違反なし（`npx ts-node scripts/validate-extension-isolation.ts`）

### Enable/Disable チェック

- [ ] `config/extensions.json` から ext を除外してもビルドエラーにならない
- [ ] 他の ext が正常に動作する（依存していない）
- [ ] ナビゲーション、ルーティング、MountPoint が消える

### マニフェストチェック

- [ ] `id` がユニーク
- [ ] `navigation` の `path` が他と衝突しない
- [ ] `routes` の `path` が他と衝突しない
- [ ] `mountPoints` の `mountPoint` が存在する MountPoint 名
- [ ] すべてのコンポーネントが lazy import (`() => import(...)`)

### コード品質チェック

- [ ] `default export` が pages/ と widgets/ の全ファイルにある
- [ ] カスタムフックがデータ取得を担当
- [ ] Loading / Error 状態のハンドリングがある
- [ ] TypeScript strict モードでエラーなし
