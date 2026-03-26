# Node.js (Express/NestJS) パターン

> 親ファイル: `SKILL.md` — 7原則・チートシート・チェックリストはそちらを参照

## ディレクトリ構造

```
src/
├── core/
│   ├── interfaces/
│   │   ├── extension.ts       # ExtensionManifest
│   │   ├── events.ts          # CoreEvents
│   │   ├── hooks.ts           # HookPoints
│   │   └── services.ts        # CoreServices
│   ├── services/
│   │   ├── database.ts
│   │   ├── auth.ts
│   │   └── cache.ts
│   ├── registry.ts            # ExtensionRegistry
│   ├── event-bus.ts           # EventBus
│   └── hook-executor.ts       # HookExecutor
├── shared/
│   ├── middleware/
│   ├── validators/
│   └── utils/
├── extensions/
│   ├── user-management/
│   │   ├── index.ts            # manifest
│   │   ├── router.ts
│   │   ├── service.ts
│   │   ├── models/
│   │   ├── events.ts
│   │   ├── hooks.ts
│   │   └── __tests__/
│   └── notification/
│       └── ...
├── config/
│   └── extensions.yaml
├── app.ts                      # Application Factory
└── main.ts
```

## TypeScript型定義

**ExtensionManifest:**

```typescript
// core/interfaces/extension.ts
import { Router } from 'express';
import type { HookHandler } from './hooks';
import type { CoreServices } from './services';

export interface ExtensionManifest {
  readonly id: string;        // kebab-case (e.g., "user-management")
  readonly name: string;      // 表示名
  readonly version: string;   // セマンティックバージョン
  readonly router?: Router;
  readonly models?: unknown[];
  readonly hookHandlers?: Record<string, HookHandler>;
  readonly eventSubscriptions?: Record<string, EventHandler>;
  readonly onInit?: (services: CoreServices) => Promise<void>;
  readonly onDestroy?: () => Promise<void>;
}

export type EventHandler<T = unknown> = (data: T) => Promise<void>;
```

**CoreEvents:**

```typescript
// core/interfaces/events.ts
export interface CoreEvents {
  'user:created': { userId: string };
  'user:updated': { userId: string; changes: Record<string, unknown> };
  'user:deleted': { userId: string };
  'notification:created': {
    message: string;
    level: 'info' | 'warn' | 'error';
  };
}
```

**HookPoints:**

```typescript
// core/interfaces/hooks.ts
import type { Request, Response } from 'express';

export interface HookPoints {
  'before:request': { req: Request; res: Response };
  'after:response': { req: Request; res: Response; duration: number };
  'user:created': { userId: string };
  'data:export': { format: string };
  'health:check': Record<string, never>;
}

export type HookHandler<T = unknown> = (context: T) => Promise<unknown>;
```

**CoreServices:**

```typescript
// core/interfaces/services.ts
import type { EventBus } from '../event-bus';
import type { HookExecutor } from '../hook-executor';

export interface CoreServices {
  readonly db: DatabaseService;
  readonly auth: AuthService;
  readonly cache: CacheService;
  readonly events: EventBus;
  readonly hooks: HookExecutor;
}

export interface DatabaseService {
  query<T>(sql: string, params?: unknown[]): Promise<T[]>;
  transaction<T>(fn: () => Promise<T>): Promise<T>;
}

export interface AuthService {
  verify(token: string): Promise<{ userId: string }>;
}

export interface CacheService {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttl?: number): Promise<void>;
  del(key: string): Promise<void>;
}
```

## ExtensionRegistry (TypeScript)

```typescript
// core/registry.ts
import type { ExtensionManifest } from './interfaces/extension';

export class ExtensionRegistry {
  private extensions = new Map<string, ExtensionManifest>();

  register(manifest: ExtensionManifest): void {
    if (this.extensions.has(manifest.id)) {
      throw new Error(`Extension '${manifest.id}' already registered`);
    }
    this.extensions.set(manifest.id, manifest);
  }

  get(id: string): ExtensionManifest | undefined {
    return this.extensions.get(id);
  }

  all(): ExtensionManifest[] {
    return Array.from(this.extensions.values());
  }

  isRegistered(id: string): boolean {
    return this.extensions.has(id);
  }
}
```

## EventBus (TypeScript)

```typescript
// core/event-bus.ts
import type { CoreEvents } from './interfaces/events';

type EventHandler<T = unknown> = (data: T) => Promise<void>;

export class EventBus {
  private handlers = new Map<string, EventHandler[]>();

  on<K extends keyof CoreEvents>(
    event: K,
    handler: EventHandler<CoreEvents[K]>,
  ): () => void {
    const list = this.handlers.get(event) ?? [];
    list.push(handler as EventHandler);
    this.handlers.set(event, list);

    return () => {
      const idx = list.indexOf(handler as EventHandler);
      if (idx >= 0) list.splice(idx, 1);
    };
  }

  async emit<K extends keyof CoreEvents>(
    event: K,
    data: CoreEvents[K],
  ): Promise<void> {
    const list = this.handlers.get(event) ?? [];
    await Promise.all(list.map((h) => h(data)));
  }
}
```

## HookExecutor (TypeScript)

```typescript
// core/hook-executor.ts
import type { HookHandler, HookPoints } from './interfaces/hooks';

export class HookExecutor {
  private hooks = new Map<string, Array<{ order: number; handler: HookHandler }>>();

  register<K extends keyof HookPoints>(
    hookPoint: K,
    handler: HookHandler<HookPoints[K]>,
    order = 0,
  ): void {
    const list = this.hooks.get(hookPoint) ?? [];
    list.push({ order, handler: handler as HookHandler });
    list.sort((a, b) => a.order - b.order);
    this.hooks.set(hookPoint, list);
  }

  async execute<K extends keyof HookPoints>(
    hookPoint: K,
    context: HookPoints[K],
  ): Promise<unknown[]> {
    const list = this.hooks.get(hookPoint) ?? [];
    const results: unknown[] = [];
    for (const { handler } of list) {
      const result = await handler(context);
      results.push(result);
    }
    return results;
  }
}
```

## Express Application Factory

```typescript
// app.ts (Express)
import express from 'express';
import yaml from 'js-yaml';
import fs from 'fs';
import { ExtensionRegistry } from './core/registry';
import { EventBus } from './core/event-bus';
import { HookExecutor } from './core/hook-executor';
import type { ExtensionManifest } from './core/interfaces/extension';

interface ExtensionConfig {
  enabled: string[];
}

export function createApp(
  enabledExtensions?: string[],
): express.Application {
  const app = express();
  const registry = new ExtensionRegistry();
  const eventBus = new EventBus();
  const hookExecutor = new HookExecutor();

  app.use(express.json());

  // 有効 ext の読み込み
  const extensions =
    enabledExtensions ??
    (
      yaml.load(
        fs.readFileSync('config/extensions.yaml', 'utf8'),
      ) as ExtensionConfig
    ).enabled;

  for (const extId of extensions) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const mod = require(`./extensions/${extId}`);
    const manifest: ExtensionManifest = mod.default ?? mod.manifest;

    if (manifest.router) {
      app.use(`/api/${extId}`, manifest.router);
    }

    if (manifest.eventSubscriptions) {
      for (const [event, handler] of Object.entries(
        manifest.eventSubscriptions,
      )) {
        eventBus.on(event as any, handler as any);
      }
    }

    if (manifest.hookHandlers) {
      for (const [hook, handler] of Object.entries(manifest.hookHandlers)) {
        hookExecutor.register(hook as any, handler as any);
      }
    }

    registry.register(manifest);
  }

  app.locals.registry = registry;
  app.locals.eventBus = eventBus;
  app.locals.hookExecutor = hookExecutor;

  return app;
}
```

## NestJS Dynamic Module

```typescript
// core/extension.module.ts (NestJS)
import { DynamicModule, Module } from '@nestjs/common';
import yaml from 'js-yaml';
import fs from 'fs';

interface ExtensionConfig {
  enabled: string[];
}

@Module({})
export class ExtensionModule {
  static async forRoot(): Promise<DynamicModule> {
    const config = yaml.load(
      fs.readFileSync('config/extensions.yaml', 'utf8'),
    ) as ExtensionConfig;

    const modules = await Promise.all(
      config.enabled.map(async (extId) => {
        const mod = await import(`../extensions/${extId}`);
        return mod.ExtensionModule ?? mod.default;
      }),
    );

    return {
      module: ExtensionModule,
      imports: modules,
    };
  }
}
```

## ESLint zones 設定

```javascript
// .eslintrc.js (zones)
module.exports = {
  rules: {
    'import/no-restricted-paths': [
      'error',
      {
        zones: [
          // ext → ext の直接import禁止
          {
            target: './src/extensions/user-management',
            from: './src/extensions/notification',
          },
          {
            target: './src/extensions/notification',
            from: './src/extensions/user-management',
          },
          // shared → ext のimport禁止
          {
            target: './src/shared',
            from: './src/extensions',
          },
        ],
      },
    ],
  },
};
```
