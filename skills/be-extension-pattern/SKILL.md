---
name: be-extension-pattern
description: |
  BEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。
  Python (FastAPI) / Node.js (Express/NestJS) / 言語非依存の原則とパターンを提供。
  BE新機能追加・APIエンドポイント追加・BEエクステンション作成時に使用。
  キーワード: BEエクステンション, HookPoint, AsyncEventBus, ExtensionRegistry, FastAPI, NestJS
  NOT for: FE実装, インフラ構成, DB設計（エクステンション構造に関わらない場合）
allowed-tools: "Read Glob Grep"
license: proprietary
metadata:
  category: guide-reference
  tags: [backend, architecture, python, nodejs, extension-pattern]
---

# be-extension-pattern

BEプロジェクトでエクステンションパターン（プラグインアーキテクチャ）に従った実装を指導するスキル。

---

## 1. FE-BE コンセプトマッピング表

FEのエクステンションパターンとBEの対応概念を整理する。
FEスキル (`fe-extension-pattern`) を既に理解している場合、この表で対応関係を把握できる。

| FE概念 | BE対応概念 | 説明 |
|--------|-----------|------|
| MountPoint | HookPoint | コアの拡張ポイント。FEではUI配置、BEではリクエスト処理パイプラインへの注入 |
| EventBus | AsyncEventBus | ext間の非同期通信。BEではasyncio/EventEmitterベース |
| ExtensionManifest | ExtensionManifest | エクステンションのメタデータ。BEではrouter, models, handlers等を宣言 |
| Zustand Store | Extension-scoped State | ext内の状態管理。BEではext-scoped DB table / cache |
| config/extensions.json | config/extensions.yaml | 有効エクステンション一覧 |
| ESLint zones | import-linter / eslint-plugin-import | 隔離ルールの強制 |
| lazy import `() => import()` | Dynamic module loading | 遅延ロード |
| shared/ components | shared/ utilities | 共有ライブラリ |
| core/services | core/services | コアサービス（DB, Auth, Cache等） |
| core/types | core/interfaces | 共通型・インターフェース定義 |

---

## 2. 言語非依存7原則

どの言語・フレームワークでも守るべき普遍的な原則。

### 原則 1: 自己完結モジュール

各extはrouter/models/services/testsを内包する。ext単体で理解可能であること。
ext内のコードだけを読めば、そのextの機能を完全に把握できる状態を目指す。

### 原則 2: 単方向依存

ext → core/shared のみ許可。以下は全て禁止:
- ext → ext（他のextへの直接依存）
- shared → ext（共有ライブラリからextへの逆依存）
- core → ext（コアからextへの逆依存）

### 原則 3: レジストリ駆動

ExtensionRegistryがext一覧を管理する。動的load/unload可能。
ハードコードされたimportではなく、設定ファイルに基づく動的ロードを行う。

### 原則 4: 型付きEventBus

ext間通信は型安全なEventBusのみ。直接import禁止。
イベント名とペイロード型を事前に定義し、型チェックで安全性を担保する。

### 原則 5: ext-scoped永続化

DBテーブル/マイグレーションはext内に閉じる。coreテーブル変更禁止。
各extは自分のテーブルのみを管理し、他extやcoreのテーブルには触れない。

### 原則 6: Feature Flag

config/extensions.yamlでON/OFF。無効extはロードされない。
extを無効化するだけでアプリ全体が正常に動作すること。

### 原則 7: アーキテクチャテスト

import依存方向をCIで自動検証する。
Python: import-linter、Node.js: ESLint zones（import/no-restricted-paths）。

---

## 3. Python (FastAPI) パターン

### 3.1 ディレクトリ構造

```
src/
├── core/                    # フレームワーク（変更しない）
│   ├── interfaces/          # 共通インターフェース（Protocol）
│   │   ├── extension.py     # ExtensionManifest Protocol
│   │   ├── events.py        # EventBus Protocol
│   │   └── hooks.py         # HookPoint Protocol
│   ├── services/            # コアサービス
│   │   ├── database.py      # DB接続
│   │   ├── auth.py          # 認証
│   │   └── cache.py         # キャッシュ
│   ├── registry.py          # ExtensionRegistry
│   ├── event_bus.py         # AsyncEventBus
│   └── hook_executor.py     # HookExecutor
├── shared/                  # 共有ユーティリティ
│   ├── pagination.py
│   ├── responses.py
│   └── validators.py
├── extensions/              # エクステンション（ここに機能を追加）
│   ├── user_management/
│   │   ├── __init__.py      # manifest
│   │   ├── router.py        # APIルーター
│   │   ├── models.py        # SQLAlchemy/Pydanticモデル
│   │   ├── service.py       # ビジネスロジック
│   │   ├── events.py        # イベントハンドラ
│   │   ├── hooks.py         # HookPoint ハンドラ
│   │   ├── migrations/      # Alembicマイグレーション
│   │   └── tests/
│   │       ├── conftest.py   # ext-scoped fixtures
│   │       ├── test_router.py
│   │       └── test_service.py
│   └── notification/
│       └── ...
├── config/
│   └── extensions.yaml      # 有効エクステンション一覧
├── app.py                   # Application Factory
└── main.py                  # エントリポイント
```

### 3.2 ExtensionManifest

```python
# core/interfaces/extension.py
from dataclasses import dataclass, field
from typing import Callable, Any
from fastapi import APIRouter


@dataclass
class ExtensionManifest:
    """エクステンションのメタデータ。

    各extの __init__.py で manifest インスタンスを定義し、
    ExtensionRegistry に登録する。
    """

    id: str                          # kebab-case (e.g., "user-management")
    name: str                        # 表示名
    version: str                     # セマンティックバージョン
    router: APIRouter | None = None  # APIルーター
    models: list[Any] = field(default_factory=list)      # SQLAlchemyモデル
    hook_handlers: dict[str, Callable] = field(
        default_factory=dict,
    )  # HookPoint → handler
    event_subscriptions: dict[str, Callable] = field(
        default_factory=dict,
    )  # event_name → handler
    on_init: Callable | None = None      # 初期化コールバック
    on_destroy: Callable | None = None   # クリーンアップコールバック
```

### 3.3 ExtensionRegistry

```python
# core/registry.py
from core.interfaces.extension import ExtensionManifest


class ExtensionRegistry:
    """登録済みエクステンションの一覧管理。

    Application Factory (app.py) が config/extensions.yaml に基づき
    各 ext の manifest を登録する。
    """

    def __init__(self) -> None:
        self._extensions: dict[str, ExtensionManifest] = {}

    def register(self, manifest: ExtensionManifest) -> None:
        if manifest.id in self._extensions:
            raise ValueError(f"Extension '{manifest.id}' already registered")
        self._extensions[manifest.id] = manifest

    def get(self, ext_id: str) -> ExtensionManifest | None:
        return self._extensions.get(ext_id)

    def all(self) -> list[ExtensionManifest]:
        return list(self._extensions.values())

    def is_registered(self, ext_id: str) -> bool:
        return ext_id in self._extensions
```

### 3.4 AsyncEventBus

```python
# core/event_bus.py
import asyncio
from collections import defaultdict
from typing import Any, Callable, Awaitable


EventHandler = Callable[..., Awaitable[None]]


class AsyncEventBus:
    """ext間の非同期イベント通信バス。

    ext が直接 import し合うのではなく、EventBus を介して
    イベントを発火・購読する。FE の EventBus に対応。
    """

    def __init__(self) -> None:
        self._handlers: dict[str, list[EventHandler]] = defaultdict(list)

    def on(self, event_name: str, handler: EventHandler) -> Callable[[], None]:
        """イベントハンドラを登録。unsubscribe関数を返す。"""
        self._handlers[event_name].append(handler)

        def unsubscribe() -> None:
            self._handlers[event_name].remove(handler)

        return unsubscribe

    async def emit(self, event_name: str, data: Any = None) -> None:
        """イベントを発火。全ハンドラを並行実行。"""
        handlers = self._handlers.get(event_name, [])
        await asyncio.gather(*(h(data) for h in handlers))
```

### 3.5 HookExecutor (BE版MountPoint)

```python
# core/hook_executor.py
from typing import Any, Callable, Awaitable


HookHandler = Callable[..., Awaitable[Any]]


class HookExecutor:
    """BEのHookPoint実行エンジン。FEのMountPointに相当。

    コアのリクエスト処理パイプラインに拡張ポイント（HookPoint）を定義し、
    各 ext が handler を登録する。order で実行順序を制御。
    """

    def __init__(self) -> None:
        self._hooks: dict[str, list[tuple[int, HookHandler]]] = {}

    def register(
        self, hook_point: str, handler: HookHandler, order: int = 0
    ) -> None:
        """HookPoint に handler を登録。order が小さいほど先に実行。"""
        if hook_point not in self._hooks:
            self._hooks[hook_point] = []
        self._hooks[hook_point].append((order, handler))
        self._hooks[hook_point].sort(key=lambda x: x[0])

    async def execute(self, hook_point: str, context: Any = None) -> list[Any]:
        """HookPoint に登録された全 handler を順次実行。"""
        handlers = self._hooks.get(hook_point, [])
        results = []
        for _, handler in handlers:
            result = await handler(context)
            results.append(result)
        return results
```

### 3.6 利用可能な HookPoint

| HookPoint名 | タイミング | 用途 |
|-------------|-----------|------|
| `before_request` | リクエスト処理前 | 認証チェック、レート制限 |
| `after_response` | レスポンス送信後 | ログ記録、メトリクス |
| `user_created` | ユーザー作成後 | ウェルカムメール、初期データ作成 |
| `user_deleted` | ユーザー削除後 | 関連データクリーンアップ |
| `data_export` | データエクスポート時 | ext固有データの追加 |
| `health_check` | ヘルスチェック時 | ext固有のヘルスステータス |

### 3.7 Application Factory

```python
# app.py
import yaml
import importlib
from fastapi import FastAPI
from core.registry import ExtensionRegistry
from core.event_bus import AsyncEventBus
from core.hook_executor import HookExecutor


def create_app(
    enabled_extensions: list[str] | None = None,
) -> FastAPI:
    """Application Factory パターン。

    config/extensions.yaml から有効な ext を読み込み、
    router, EventBus, HookPoint を自動登録する。
    enabled_extensions を指定するとテスト用に ext を限定できる。
    """
    app = FastAPI()
    registry = ExtensionRegistry()
    event_bus = AsyncEventBus()
    hook_executor = HookExecutor()

    # 有効extの読み込み
    if enabled_extensions is None:
        with open("config/extensions.yaml") as f:
            config = yaml.safe_load(f)
        enabled_extensions = config.get("enabled", [])

    for ext_id in enabled_extensions:
        module_name = ext_id.replace("-", "_")
        mod = importlib.import_module(f"extensions.{module_name}")
        manifest = mod.manifest

        # ルーター登録
        if manifest.router:
            app.include_router(manifest.router, prefix=f"/api/{ext_id}")

        # EventBus購読登録
        for event_name, handler in manifest.event_subscriptions.items():
            event_bus.on(event_name, handler)

        # HookPoint登録
        for hook_point, handler in manifest.hook_handlers.items():
            hook_executor.register(hook_point, handler)

        # 初期化コールバック
        if manifest.on_init:
            # on_init は起動時に呼ばれる
            pass  # lifespan で呼び出す

        registry.register(manifest)

    # コアサービスをapp.stateに保存
    app.state.registry = registry
    app.state.event_bus = event_bus
    app.state.hook_executor = hook_executor

    return app
```

### 3.8 サンプルエクステンション (user_management)

**manifest定義:**

```python
# extensions/user_management/__init__.py
from fastapi import APIRouter
from core.interfaces.extension import ExtensionManifest
from .router import router
from .events import on_notification_created

manifest = ExtensionManifest(
    id="user-management",
    name="User Management",
    version="1.0.0",
    router=router,
    event_subscriptions={
        "notification:created": on_notification_created,
    },
    hook_handlers={
        "data_export": lambda ctx: {"users": "...export data..."},
    },
)
```

**ルーター:**

```python
# extensions/user_management/router.py
from fastapi import APIRouter, Request
from .service import UserService
from .models import UserCreate, UserResponse

router = APIRouter(tags=["users"])


@router.post("/", response_model=UserResponse)
async def create_user(request: Request, data: UserCreate):
    """ユーザー作成エンドポイント。

    作成後に user:created イベントを発火し、
    他の ext（notification等）に通知する。
    """
    service = UserService(request.app.state)
    user = await service.create(data)

    # イベント発火 - 他extへの通知
    await request.app.state.event_bus.emit(
        "user:created", {"user_id": user.id}
    )
    return user


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(request: Request, user_id: str):
    service = UserService(request.app.state)
    return await service.get(user_id)
```

**サービス:**

```python
# extensions/user_management/service.py
from .models import UserCreate, User


class UserService:
    """user_management ext のビジネスロジック。

    core/services のDB, Cache等を利用するが、
    他の ext のサービスには依存しない。
    """

    def __init__(self, app_state) -> None:
        self._state = app_state

    async def create(self, data: UserCreate) -> User:
        # DB操作は core/services/database.py 経由
        # 他の ext を直接呼ばない
        ...

    async def get(self, user_id: str) -> User:
        ...
```

**イベントハンドラ:**

```python
# extensions/user_management/events.py
from typing import Any


async def on_notification_created(data: Any) -> None:
    """notification ext からのイベントを処理。

    直接 notification ext を import するのではなく、
    AsyncEventBus 経由でイベントを受け取る。
    """
    message = data.get("message", "")
    # user_management 固有の処理
    ...
```

### 3.9 validate_isolation.py（アーキテクチャテスト）

```python
# validate_isolation.py
"""Architecture test: Verify extension isolation rules.

CI で実行し、ext 間の不正な import を検出する。
import-linter と併用することを推奨。
"""
import ast
import sys
from pathlib import Path


FORBIDDEN_PATTERNS = [
    # ext → ext の直接import
    ("extensions/*/", "extensions/*/"),
    # shared → ext のimport
    ("shared/", "extensions/"),
]


def check_extension_imports(ext_dir: Path) -> list[str]:
    """指定 ext ディレクトリ内の .py ファイルを走査し、
    他 ext への import を検出する。
    """
    violations = []
    ext_name = ext_dir.name

    for py_file in ext_dir.rglob("*.py"):
        tree = ast.parse(py_file.read_text())
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                module = (
                    node.module if isinstance(node, ast.ImportFrom) else None
                )
                if module and "extensions." in module:
                    imported_ext = module.split("extensions.")[1].split(".")[0]
                    if imported_ext != ext_name:
                        violations.append(
                            f"{py_file}:{node.lineno} "
                            f"imports from extensions.{imported_ext}"
                        )
    return violations


def check_shared_imports(shared_dir: Path) -> list[str]:
    """shared/ 内のファイルが extensions/ を import していないか検証。"""
    violations = []

    for py_file in shared_dir.rglob("*.py"):
        tree = ast.parse(py_file.read_text())
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                module = (
                    node.module if isinstance(node, ast.ImportFrom) else None
                )
                if module and "extensions." in module:
                    violations.append(
                        f"{py_file}:{node.lineno} "
                        f"shared imports from extensions"
                    )
    return violations


if __name__ == "__main__":
    ext_root = Path("src/extensions")
    shared_root = Path("src/shared")
    all_violations = []

    for ext_dir in ext_root.iterdir():
        if ext_dir.is_dir() and not ext_dir.name.startswith("_"):
            all_violations.extend(check_extension_imports(ext_dir))

    if shared_root.exists():
        all_violations.extend(check_shared_imports(shared_root))

    if all_violations:
        print("ISOLATION VIOLATIONS FOUND:")
        for v in all_violations:
            print(f"  - {v}")
        sys.exit(1)
    else:
        print("All isolation checks passed.")
```

**import-linter 設定:**

```ini
# setup.cfg
[importlinter]
root_package = src

[importlinter:contract:1]
name = Extensions cannot import from other extensions
type = independence
modules =
    extensions.user_management
    extensions.notification
    extensions.billing

[importlinter:contract:2]
name = Shared cannot import from extensions
type = forbidden
source_modules =
    shared
forbidden_modules =
    extensions
```

### 3.10 テスト分離

```python
# extensions/user_management/tests/conftest.py
"""ext-scoped test fixtures.

他のextに依存しない。user_management のみ有効なアプリで
テストを実行する。
"""
import pytest
from fastapi.testclient import TestClient
from app import create_app


@pytest.fixture
def app():
    """user_management のみ有効なアプリ"""
    return create_app(enabled_extensions=["user-management"])


@pytest.fixture
def client(app):
    return TestClient(app)
```

```python
# extensions/user_management/tests/test_router.py
def test_create_user(client):
    response = client.post("/api/user-management/", json={
        "name": "Test User",
        "email": "test@example.com",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test User"


def test_get_user(client):
    # create first
    create_resp = client.post("/api/user-management/", json={
        "name": "Test User",
        "email": "test@example.com",
    })
    user_id = create_resp.json()["id"]

    response = client.get(f"/api/user-management/{user_id}")
    assert response.status_code == 200
```

### 3.11 config/extensions.yaml

```yaml
# config/extensions.yaml
enabled:
  - user-management
  - notification
  # - billing  # 無効化はコメントアウト
```

---

## 4. Node.js (Express/NestJS) パターン

### 4.1 ディレクトリ構造

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

### 4.2 TypeScript型定義

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

### 4.3 ExtensionRegistry (TypeScript)

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

### 4.4 EventBus (TypeScript)

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

### 4.5 HookExecutor (TypeScript)

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

### 4.6 Express Application Factory

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

### 4.7 NestJS Dynamic Module

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

### 4.8 ESLint zones 設定

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

---

## 5. 10のルール（チートシート）

### Python版

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `core/` は変更しない | core にヘルパー関数追加 | shared/ または ext 内に定義 |
| 2 | ext 間の直接 import 禁止 | `from extensions.billing import ...` | AsyncEventBus で通信 |
| 3 | 依存方向: ext → core/shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `__init__.py` (manifest) 必須 | manifest なしの ext | ExtensionManifest を定義 |
| 5 | ルーターは ext 内に閉じる | core の router に ext のエンドポイント追加 | ext 内 APIRouter |
| 6 | DBモデル/マイグレーションは ext 内 | core のマイグレーションに ext テーブル追加 | ext/migrations/ に配置 |
| 7 | テストは ext 内に閉じる | テストで他 ext の fixture を使用 | ext-scoped conftest.py |
| 8 | ext 間通信は AsyncEventBus のみ | 直接関数呼び出し | `event_bus.emit()` / `.on()` |
| 9 | `config/extensions.yaml` で ON/OFF | ハードコードされた import | enabled リストから削除で無効化 |
| 10 | import-linter で隔離を強制 | CI 設定なしでレビュー頼み | `lint-imports` CI ステップ |

### Node.js版

| # | ルール | 違反例 | 正解 |
|---|--------|--------|------|
| 1 | `core/` は変更しない | core に新しい interface 追加 | ext 内に型を定義 |
| 2 | ext 間の直接 import 禁止 | `import { X } from '../notification'` | EventBus で通信 |
| 3 | 依存方向: ext → core/shared のみ | shared から ext を import | shared は ext を知らない |
| 4 | 各 ext に `index.ts` (manifest) 必須 | manifest なしの ext | ExtensionManifest を export |
| 5 | ルーターは ext 内に閉じる | app.ts に ext のルーティング追加 | ext 内 Router |
| 6 | モデル/マイグレーションは ext 内 | 共通マイグレーションに ext テーブル追加 | ext/models/ + ext/migrations/ |
| 7 | テストは ext 内に閉じる | テストで他 ext の mock を共有 | ext-scoped test setup |
| 8 | ext 間通信は EventBus のみ | 直接 import して関数呼び出し | `eventBus.emit()` / `.on()` |
| 9 | `config/extensions.yaml` で ON/OFF | ハードコードされた require/import | enabled リストから削除で無効化 |
| 10 | ESLint zones で隔離を強制 | zone 設定なしでレビュー頼み | `eslint-plugin-import` zones |

---

## 6. 検証チェックリスト

### 隔離性チェック

- [ ] `extensions/{ext}/` 内からの import が `core/`, `shared/`, 自ext内のみ
- [ ] 他の ext ディレクトリからの import がない
- [ ] `core/` を変更していない
- [ ] Python: `lint-imports` でコントラクト違反なし
- [ ] Node.js: ESLint zones で違反なし

### Enable/Disable チェック

- [ ] `config/extensions.yaml` から ext を除外してもアプリ起動できる
- [ ] 他の ext が正常に動作する（依存していない）
- [ ] API エンドポイント、イベント購読、HookPoint が消える

### マニフェストチェック

- [ ] `id` がユニーク（kebab-case）
- [ ] `router` のプレフィックスが他と衝突しない
- [ ] `event_subscriptions` のイベント名が CoreEvents に定義済み
- [ ] `hook_handlers` の HookPoint 名が有効

### テストチェック

- [ ] ext 内のテストが独立して実行可能（`pytest extensions/{ext}/tests/`）
- [ ] 他の ext を有効にしなくてもテストがパスする
- [ ] ext-scoped conftest.py / test setup で fixture を定義
