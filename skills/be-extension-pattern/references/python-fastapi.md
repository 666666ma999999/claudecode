# Python (FastAPI) パターン

> 親ファイル: `SKILL.md` — 7原則・チートシート・チェックリストはそちらを参照

## ディレクトリ構造

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

## ExtensionManifest

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

## ExtensionRegistry

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

## AsyncEventBus

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

## HookExecutor (BE版MountPoint)

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

## 利用可能な HookPoint

| HookPoint名 | タイミング | 用途 |
|-------------|-----------|------|
| `before_request` | リクエスト処理前 | 認証チェック、レート制限 |
| `after_response` | レスポンス送信後 | ログ記録、メトリクス |
| `user_created` | ユーザー作成後 | ウェルカムメール、初期データ作成 |
| `user_deleted` | ユーザー削除後 | 関連データクリーンアップ |
| `data_export` | データエクスポート時 | ext固有データの追加 |
| `health_check` | ヘルスチェック時 | ext固有のヘルスステータス |

## Application Factory

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

## サンプルエクステンション (user_management)

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

## validate_isolation.py（アーキテクチャテスト）

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

## テスト分離

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

## config/extensions.yaml

```yaml
# config/extensions.yaml
enabled:
  - user-management
  - notification
  # - billing  # 無効化はコメントアウト
```
