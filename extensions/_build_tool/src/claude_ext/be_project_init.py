"""Backend project initialization for BE Extension Architecture."""

from __future__ import annotations

import shutil
import yaml
from pathlib import Path

from rich.console import Console

console = Console()

SKILL_SOURCE_DIR = (
    Path.home() / ".claude" / "extensions" / "be-extension-pattern"
    / "skills" / "be-extension-pattern"
)

SAMPLE_EXTENSION_NAME = "sample"


def init_be_project(
    project_dir: Path,
    force: bool = False,
    stack: str = "python",
) -> None:
    """Initialize a project with BE Extension Architecture.

    Args:
        project_dir: Target project directory.
        force: Overwrite existing files.
        stack: Backend stack ("python" or "node"). Only "python" is supported for now.
    """
    if stack != "python":
        console.print(f"[yellow]Stack '{stack}' is not yet supported.[/yellow]")
        console.print("[yellow]Only 'python' (FastAPI) stack is available currently.[/yellow]")
        raise SystemExit(1)

    project_dir = project_dir.resolve()
    project_dir.mkdir(parents=True, exist_ok=True)

    console.print(f"[bold]Initializing BE Extension Architecture in:[/bold] {project_dir}")
    console.print(f"[bold]Stack:[/bold] {stack}")

    # 1. Generate core/ structure
    _generate_core_interfaces(project_dir, force)
    _generate_core_modules(project_dir, force)

    # 2. Generate shared/ structure
    _generate_shared(project_dir, force)

    # 3. Generate app.py (Application Factory)
    _generate_app_factory(project_dir, force)

    # 4. Generate config/extensions.yaml
    _generate_extensions_yaml(project_dir, force)

    # 5. Generate setup.cfg (import-linter)
    _generate_setup_cfg(project_dir, force)

    # 6. Copy skill to project .claude/skills/
    _copy_skill_to_project(project_dir, force)

    # 7. Generate sample extension
    _generate_sample_extension(project_dir, force)

    console.print("[bold green]BE project initialized successfully.[/bold green]")
    console.print()
    console.print("[bold]Next steps:[/bold]")
    console.print("  1. Review generated files")
    console.print("  2. Install dependencies: pip install fastapi uvicorn pyyaml")
    console.print("  3. Run the app: uvicorn app:app --reload")
    console.print("  4. Check isolation rules: lint-imports")


def _generate_core_interfaces(project_dir: Path, force: bool) -> None:
    """Generate core/interfaces/ directory with Protocol definitions."""
    interfaces_dir = project_dir / "src" / "core" / "interfaces"
    interfaces_dir.mkdir(parents=True, exist_ok=True)

    # __init__.py (empty)
    init_file = interfaces_dir / "__init__.py"
    if not init_file.exists() or force:
        init_file.write_text("", encoding="utf-8")
        console.print(f"[green]GENERATED:[/green] {init_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {init_file}")

    # extension.py
    extension_file = interfaces_dir / "extension.py"
    if not extension_file.exists() or force:
        extension_file.write_text(
            '''"""Extension manifest interface."""

from dataclasses import dataclass, field
from typing import Callable, Any
from fastapi import APIRouter


@dataclass
class ExtensionManifest:
    """Extension metadata.

    Each extension's __init__.py defines a manifest instance
    and registers it with ExtensionRegistry.
    """

    id: str
    name: str
    version: str
    router: APIRouter | None = None
    models: list[Any] = field(default_factory=list)
    hook_handlers: dict[str, Callable] = field(default_factory=dict)
    event_subscriptions: dict[str, Callable] = field(default_factory=dict)
    on_init: Callable | None = None
    on_destroy: Callable | None = None
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {extension_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {extension_file}")

    # events.py
    events_file = interfaces_dir / "events.py"
    if not events_file.exists() or force:
        events_file.write_text(
            '''"""Event bus interfaces."""

from typing import Any, Callable, Awaitable

EventHandler = Callable[..., Awaitable[None]]
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {events_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {events_file}")

    # hooks.py
    hooks_file = interfaces_dir / "hooks.py"
    if not hooks_file.exists() or force:
        hooks_file.write_text(
            '''"""Hook point interfaces."""

from typing import Any, Callable, Awaitable

HookHandler = Callable[..., Awaitable[Any]]
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {hooks_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {hooks_file}")


def _generate_core_modules(project_dir: Path, force: bool) -> None:
    """Generate core/ modules: registry, event_bus, hook_executor."""
    core_dir = project_dir / "src" / "core"
    core_dir.mkdir(parents=True, exist_ok=True)

    # __init__.py (export key classes)
    init_file = core_dir / "__init__.py"
    if not init_file.exists() or force:
        init_file.write_text(
            '''"""Core module exports."""

from .registry import ExtensionRegistry
from .event_bus import AsyncEventBus
from .hook_executor import HookExecutor
from .interfaces.extension import ExtensionManifest

__all__ = [
    "ExtensionRegistry",
    "AsyncEventBus",
    "HookExecutor",
    "ExtensionManifest",
]
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {init_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {init_file}")

    # registry.py
    registry_file = core_dir / "registry.py"
    if not registry_file.exists() or force:
        registry_file.write_text(
            '''"""Extension registry."""

from core.interfaces.extension import ExtensionManifest


class ExtensionRegistry:
    """Manage registered extensions.

    Application Factory (app.py) loads extensions from config/extensions.yaml
    and registers each extension's manifest.
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
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {registry_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {registry_file}")

    # event_bus.py
    event_bus_file = core_dir / "event_bus.py"
    if not event_bus_file.exists() or force:
        event_bus_file.write_text(
            '''"""Async event bus for inter-extension communication."""

import asyncio
from collections import defaultdict
from typing import Any, Callable, Awaitable

EventHandler = Callable[..., Awaitable[None]]


class AsyncEventBus:
    """Event bus for asynchronous inter-extension communication.

    Extensions do not directly import each other; instead, they emit
    and subscribe to events via the EventBus. Corresponds to FE EventBus.
    """

    def __init__(self) -> None:
        self._handlers: dict[str, list[EventHandler]] = defaultdict(list)

    def on(self, event_name: str, handler: EventHandler) -> Callable[[], None]:
        """Register an event handler. Returns an unsubscribe function."""
        self._handlers[event_name].append(handler)

        def unsubscribe() -> None:
            self._handlers[event_name].remove(handler)

        return unsubscribe

    async def emit(self, event_name: str, data: Any = None) -> None:
        """Emit an event. All handlers are executed concurrently."""
        handlers = self._handlers.get(event_name, [])
        await asyncio.gather(*(h(data) for h in handlers))
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {event_bus_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {event_bus_file}")

    # hook_executor.py
    hook_executor_file = core_dir / "hook_executor.py"
    if not hook_executor_file.exists() or force:
        hook_executor_file.write_text(
            '''"""Hook executor for core extension points."""

from typing import Any, Callable, Awaitable

HookHandler = Callable[..., Awaitable[Any]]


class HookExecutor:
    """BE HookPoint execution engine. Corresponds to FE MountPoint.

    Core defines extension points (HookPoints) in the request processing
    pipeline, and each extension registers handlers. Execution order is
    controlled by the order parameter.
    """

    def __init__(self) -> None:
        self._hooks: dict[str, list[tuple[int, HookHandler]]] = {}

    def register(self, hook_point: str, handler: HookHandler, order: int = 0) -> None:
        """Register a handler for a hook point. Lower order executes first."""
        if hook_point not in self._hooks:
            self._hooks[hook_point] = []
        self._hooks[hook_point].append((order, handler))
        self._hooks[hook_point].sort(key=lambda x: x[0])

    async def execute(self, hook_point: str, context: Any = None) -> list[Any]:
        """Execute all handlers registered for a hook point."""
        handlers = self._hooks.get(hook_point, [])
        results = []
        for _, handler in handlers:
            result = await handler(context)
            results.append(result)
        return results
''',
            encoding="utf-8",
        )
        console.print(f"[green]GENERATED:[/green] {hook_executor_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {hook_executor_file}")


def _generate_shared(project_dir: Path, force: bool) -> None:
    """Generate shared/ directory structure."""
    shared_dir = project_dir / "src" / "shared"
    shared_dir.mkdir(parents=True, exist_ok=True)

    init_file = shared_dir / "__init__.py"
    if not init_file.exists() or force:
        init_file.write_text("", encoding="utf-8")
        console.print(f"[green]GENERATED:[/green] {init_file}")
    else:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {init_file}")


def _generate_app_factory(project_dir: Path, force: bool) -> None:
    """Generate app.py (Application Factory)."""
    app_file = project_dir / "src" / "app.py"

    if app_file.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {app_file}")
        return

    app_file.parent.mkdir(parents=True, exist_ok=True)
    app_file.write_text(
        '''"""Application Factory for BE Extension Architecture."""

import yaml
import importlib
from pathlib import Path
from fastapi import FastAPI
from core.registry import ExtensionRegistry
from core.event_bus import AsyncEventBus
from core.hook_executor import HookExecutor


def create_app(enabled_extensions: list[str] | None = None) -> FastAPI:
    """Application Factory pattern.

    Loads enabled extensions from config/extensions.yaml and automatically
    registers routers, EventBus subscriptions, and HookPoint handlers.
    enabled_extensions can be specified to limit extensions (useful for testing).
    """
    app = FastAPI()
    registry = ExtensionRegistry()
    event_bus = AsyncEventBus()
    hook_executor = HookExecutor()

    # Load enabled extensions
    if enabled_extensions is None:
        config_path = Path("config/extensions.yaml")
        with open(config_path) as f:
            config = yaml.safe_load(f)
        enabled_extensions = config.get("enabled", [])

    for ext_id in enabled_extensions:
        module_name = ext_id.replace("-", "_")
        mod = importlib.import_module(f"extensions.{module_name}")
        manifest = mod.manifest

        # Register router
        if manifest.router:
            app.include_router(manifest.router, prefix=f"/api/{ext_id}")

        # Register EventBus subscriptions
        for event_name, handler in manifest.event_subscriptions.items():
            event_bus.on(event_name, handler)

        # Register HookPoint handlers
        for hook_point, handler in manifest.hook_handlers.items():
            hook_executor.register(hook_point, handler)

        # Initialization callback (called on startup via lifespan)
        if manifest.on_init:
            pass  # TODO: call in lifespan event

        registry.register(manifest)

    # Store core services in app.state
    app.state.registry = registry
    app.state.event_bus = event_bus
    app.state.hook_executor = hook_executor

    return app


# Create default app instance
app = create_app()
''',
        encoding="utf-8",
    )
    console.print(f"[green]GENERATED:[/green] {app_file}")


def _generate_extensions_yaml(project_dir: Path, force: bool) -> None:
    """Generate config/extensions.yaml with sample extension."""
    config_path = project_dir / "config" / "extensions.yaml"

    if config_path.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {config_path}")
        return

    config_path.parent.mkdir(parents=True, exist_ok=True)
    data = {"enabled": [SAMPLE_EXTENSION_NAME]}
    config_path.write_text(yaml.dump(data, default_flow_style=False), encoding="utf-8")
    console.print(f"[green]GENERATED:[/green] {config_path}")


def _generate_setup_cfg(project_dir: Path, force: bool) -> None:
    """Generate setup.cfg with import-linter configuration."""
    setup_cfg_path = project_dir / "setup.cfg"

    if setup_cfg_path.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {setup_cfg_path}")
        return

    setup_cfg_path.write_text(
        """[importlinter]
root_package = src

[importlinter:contract:1]
name = Extensions cannot import from other extensions
type = independence
modules =
    extensions.sample

[importlinter:contract:2]
name = Shared cannot import from extensions
type = forbidden
source_modules =
    shared
forbidden_modules =
    extensions
""",
        encoding="utf-8",
    )
    console.print(f"[green]GENERATED:[/green] {setup_cfg_path}")


def _copy_skill_to_project(project_dir: Path, force: bool) -> None:
    """Copy be-extension-pattern skill to project's .claude/skills/."""
    dst = project_dir / ".claude" / "skills" / "be-extension-pattern"

    if not SKILL_SOURCE_DIR.is_dir():
        console.print(
            "[yellow]SKIP (skill source not found):[/yellow] "
            f"{SKILL_SOURCE_DIR}"
        )
        return

    if dst.exists():
        if not force:
            console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {dst}")
            return
        shutil.rmtree(dst)

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SKILL_SOURCE_DIR, dst)
    console.print(f"[green]COPIED skill to project:[/green] {dst}")


def _generate_sample_extension(project_dir: Path, force: bool) -> None:
    """Generate a minimal sample extension."""
    ext_dir = project_dir / "src" / "extensions" / SAMPLE_EXTENSION_NAME

    if ext_dir.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {ext_dir}")
        return

    if ext_dir.exists():
        shutil.rmtree(ext_dir)

    # Create directory structure
    ext_dir.mkdir(parents=True, exist_ok=True)
    (ext_dir / "tests").mkdir(parents=True, exist_ok=True)

    # __init__.py (manifest)
    (ext_dir / "__init__.py").write_text(
        '''"""Sample extension manifest."""

from fastapi import APIRouter
from core.interfaces.extension import ExtensionManifest
from .router import router

manifest = ExtensionManifest(
    id="sample",
    name="Sample Extension",
    version="1.0.0",
    router=router,
    event_subscriptions={},
    hook_handlers={},
)
''',
        encoding="utf-8",
    )

    # router.py
    (ext_dir / "router.py").write_text(
        '''"""Sample extension API router."""

from fastapi import APIRouter, Request
from .service import SampleService
from pydantic import BaseModel

router = APIRouter(tags=["sample"])


class ItemCreate(BaseModel):
    title: str


class ItemResponse(BaseModel):
    id: str
    title: str
    created_at: str


@router.post("/items", response_model=ItemResponse)
async def create_item(request: Request, data: ItemCreate):
    """Create a new item.

    After creation, emits an item:created event to notify other extensions.
    """
    service = SampleService(request.app.state)
    item = await service.create(data.title)

    # Emit event to notify other extensions
    await request.app.state.event_bus.emit(
        "item:created", {"item_id": item["id"]}
    )
    return item


@router.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(request: Request, item_id: str):
    service = SampleService(request.app.state)
    return await service.get(item_id)


@router.get("/items", response_model=list[ItemResponse])
async def list_items(request: Request):
    service = SampleService(request.app.state)
    return await service.list_all()
''',
        encoding="utf-8",
    )

    # service.py
    (ext_dir / "service.py").write_text(
        '''"""Sample extension business logic."""

from datetime import datetime, timezone
import uuid


class SampleService:
    """Sample extension service layer.

    Uses core/services for DB, Cache, etc., but does not depend
    on other extensions' services.
    """

    def __init__(self, app_state) -> None:
        self._state = app_state
        # In-memory storage for demo purposes
        self._items: dict[str, dict] = {}

    async def create(self, title: str) -> dict:
        item_id = str(uuid.uuid4())
        item = {
            "id": item_id,
            "title": title,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        self._items[item_id] = item
        return item

    async def get(self, item_id: str) -> dict:
        if item_id not in self._items:
            raise ValueError(f"Item {item_id} not found")
        return self._items[item_id]

    async def list_all(self) -> list[dict]:
        return list(self._items.values())
''',
        encoding="utf-8",
    )

    # tests/conftest.py
    (ext_dir / "tests" / "conftest.py").write_text(
        '''"""Extension-scoped test fixtures.

Does not depend on other extensions. Tests run with only this extension enabled.
"""

import pytest
from fastapi.testclient import TestClient
from app import create_app


@pytest.fixture
def app():
    """App with only sample extension enabled."""
    return create_app(enabled_extensions=["sample"])


@pytest.fixture
def client(app):
    return TestClient(app)
''',
        encoding="utf-8",
    )

    # tests/__init__.py
    (ext_dir / "tests" / "__init__.py").write_text("", encoding="utf-8")

    # tests/test_router.py
    (ext_dir / "tests" / "test_router.py").write_text(
        '''"""Sample extension router tests."""


def test_create_item(client):
    response = client.post("/api/sample/items", json={
        "title": "Test Item",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test Item"
    assert "id" in data
    assert "created_at" in data


def test_get_item(client):
    # Create first
    create_resp = client.post("/api/sample/items", json={
        "title": "Test Item",
    })
    item_id = create_resp.json()["id"]

    # Get
    response = client.get(f"/api/sample/items/{item_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == item_id
    assert data["title"] == "Test Item"


def test_list_items(client):
    # Create multiple items
    client.post("/api/sample/items", json={"title": "Item 1"})
    client.post("/api/sample/items", json={"title": "Item 2"})

    # List
    response = client.get("/api/sample/items")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 2
''',
        encoding="utf-8",
    )

    console.print(f"[green]GENERATED sample extension:[/green] {ext_dir}")
