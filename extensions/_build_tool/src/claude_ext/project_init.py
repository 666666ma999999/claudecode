"""Project initialization for FE Extension Architecture."""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from rich.console import Console

console = Console()

DEFAULT_TEMPLATE_DIR = Path.home() / ".claude" / "fe-extension-template"
SKILL_SOURCE_DIR = (
    Path.home() / ".claude" / "extensions" / "fe-extension-pattern"
    / "skills" / "fe-extension-pattern"
)

# Directories to copy from template
COPY_DIRS = [
    ("src/core", "src/core"),
    ("src/shared/components", "src/shared/components"),
    ("scripts", "scripts"),
]

# Individual files to copy from template
COPY_FILES = [
    ("src/app/layout.tsx", "src/app/layout.tsx"),
    ("src/app/(extensions)/[...slug]/page.tsx", "src/app/(extensions)/[...slug]/page.tsx"),
    ("src/app/(core)/dashboard/page.tsx", "src/app/(core)/dashboard/page.tsx"),
    (".eslintrc.js", ".eslintrc.js"),
]

# Paths to add/merge into tsconfig.json
TSCONFIG_PATHS = {
    "@/core": ["./src/core/index.ts"],
    "@/shared/*": ["./src/shared/*"],
}

SAMPLE_EXTENSION_NAME = "sample"


def init_project(
    project_dir: Path,
    template_dir: Path | None = None,
    force: bool = False,
) -> None:
    """Initialize a project with FE Extension Architecture.

    Args:
        project_dir: Target project directory.
        template_dir: Source template directory. Defaults to ~/.claude/fe-extension-template/.
        force: Overwrite existing files.
    """
    template = template_dir or DEFAULT_TEMPLATE_DIR

    if not template.is_dir():
        console.print(f"[red]Template directory not found:[/red] {template}")
        raise SystemExit(1)

    project_dir = project_dir.resolve()
    project_dir.mkdir(parents=True, exist_ok=True)

    console.print(f"[bold]Initializing FE Extension Architecture in:[/bold] {project_dir}")

    # 1. Copy directories
    for src_rel, dst_rel in COPY_DIRS:
        _copy_dir(template / src_rel, project_dir / dst_rel, force)

    # 2. Copy individual files
    for src_rel, dst_rel in COPY_FILES:
        _copy_file(template / src_rel, project_dir / dst_rel, force)

    # 3. Generate config/extensions.json
    _generate_extensions_json(project_dir, force)

    # 4. Merge tsconfig.json paths
    _merge_tsconfig_paths(project_dir)

    # 5. Copy skill to project .claude/skills/
    _copy_skill_to_project(project_dir, force)

    # 6. Generate sample extension
    _generate_sample_extension(project_dir, force)

    console.print("[bold green]Project initialized successfully.[/bold green]")
    console.print()
    console.print("[bold]Next steps:[/bold]")
    console.print("  1. Review generated files")
    console.print("  2. Install dependencies (zustand, etc.)")
    console.print("  3. Run codegen scripts:")
    console.print("     npx ts-node scripts/generate-extension-loader.ts")
    console.print("     npx ts-node scripts/generate-eslint-zones.ts")


def _copy_dir(src: Path, dst: Path, force: bool) -> None:
    """Copy a directory tree."""
    if not src.is_dir():
        console.print(f"[yellow]SKIP (not found):[/yellow] {src}")
        return

    if dst.exists():
        if not force:
            console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {dst}")
            return
        shutil.rmtree(dst)

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dst)
    console.print(f"[green]COPIED:[/green] {dst}")


def _copy_file(src: Path, dst: Path, force: bool) -> None:
    """Copy a single file."""
    if not src.is_file():
        console.print(f"[yellow]SKIP (not found):[/yellow] {src}")
        return

    if dst.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {dst}")
        return

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    console.print(f"[green]COPIED:[/green] {dst}")


def _generate_extensions_json(project_dir: Path, force: bool) -> None:
    """Generate config/extensions.json with sample extension."""
    config_path = project_dir / "config" / "extensions.json"

    if config_path.exists() and not force:
        console.print(f"[yellow]EXISTS (use --force to overwrite):[/yellow] {config_path}")
        return

    config_path.parent.mkdir(parents=True, exist_ok=True)
    data = {"enabled": [SAMPLE_EXTENSION_NAME]}
    config_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    console.print(f"[green]GENERATED:[/green] {config_path}")


def _merge_tsconfig_paths(project_dir: Path) -> None:
    """Add extension paths to tsconfig.json (merge, not overwrite)."""
    tsconfig_path = project_dir / "tsconfig.json"

    if tsconfig_path.exists():
        try:
            data = json.loads(tsconfig_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            console.print("[yellow]WARNING: Could not parse existing tsconfig.json[/yellow]")
            return
    else:
        # Create minimal tsconfig.json
        data = {
            "compilerOptions": {
                "target": "ES2022",
                "lib": ["dom", "dom.iterable", "esnext"],
                "allowJs": True,
                "skipLibCheck": True,
                "strict": True,
                "noEmit": True,
                "esModuleInterop": True,
                "module": "esnext",
                "moduleResolution": "bundler",
                "resolveJsonModule": True,
                "isolatedModules": True,
                "jsx": "preserve",
                "incremental": True,
                "paths": {},
            },
            "include": ["src/**/*.ts", "src/**/*.tsx"],
            "exclude": ["node_modules"],
        }

    compiler_options: dict[str, Any] = data.setdefault("compilerOptions", {})
    paths: dict[str, list[str]] = compiler_options.setdefault("paths", {})

    added = []
    for alias, targets in TSCONFIG_PATHS.items():
        if alias not in paths:
            paths[alias] = targets
            added.append(alias)

    if added:
        tsconfig_path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        console.print(f"[green]MERGED tsconfig.json paths:[/green] {', '.join(added)}")
    else:
        console.print("[cyan]tsconfig.json paths already configured[/cyan]")


def _copy_skill_to_project(project_dir: Path, force: bool) -> None:
    """Copy fe-extension-pattern skill to project's .claude/skills/."""
    dst = project_dir / ".claude" / "skills" / "fe-extension-pattern"

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
    for subdir in ["types", "components", "hooks", "pages", "widgets", "store"]:
        (ext_dir / subdir).mkdir(parents=True, exist_ok=True)

    # types/item.ts
    (ext_dir / "types" / "item.ts").write_text(
        """export interface Item {
  readonly id: string;
  readonly title: string;
  readonly createdAt: string;
}
""",
        encoding="utf-8",
    )

    # store/sample-store.ts
    (ext_dir / "store" / "sample-store.ts").write_text(
        """import { create } from 'zustand';
import type { Item } from '../types/item';

interface SampleStore {
  items: Item[];
  setItems: (items: Item[]) => void;
}

export const useSampleStore = create<SampleStore>((set) => ({
  items: [],
  setItems: (items) => set({ items }),
}));
""",
        encoding="utf-8",
    )

    # hooks/useItems.ts
    (ext_dir / "hooks" / "useItems.ts").write_text(
        """import { useState, useEffect } from 'react';
import { useCoreServices } from '@/core';
import type { Item } from '../types/item';

export function useItems() {
  const { api } = useCoreServices();
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    api.get<Item[]>('/items')
      .then((data) => { if (!cancelled) setItems(data); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [api]);

  return { items, loading };
}
""",
        encoding="utf-8",
    )

    # components/ItemList.tsx
    (ext_dir / "components" / "ItemList.tsx").write_text(
        """import type { Item } from '../types/item';

interface Props {
  readonly items: Item[];
}

export function ItemList({ items }: Props) {
  if (items.length === 0) return <p>No items found.</p>;
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.title}</li>
      ))}
    </ul>
  );
}
""",
        encoding="utf-8",
    )

    # pages/SamplePage.tsx
    (ext_dir / "pages" / "SamplePage.tsx").write_text(
        """import { useItems } from '../hooks/useItems';
import { ItemList } from '../components/ItemList';

export default function SamplePage() {
  const { items, loading } = useItems();
  if (loading) return <p>Loading...</p>;
  return (
    <div>
      <h1>Sample Extension</h1>
      <ItemList items={items} />
    </div>
  );
}
""",
        encoding="utf-8",
    )

    # widgets/ItemCountCard.tsx
    (ext_dir / "widgets" / "ItemCountCard.tsx").write_text(
        """import { useState, useEffect } from 'react';
import type { MountPointProps } from '@/core';
import { useCoreServices } from '@/core';
import { Card } from '@/shared/components/Card';

export default function ItemCountCard(_props: MountPointProps) {
  const { api } = useCoreServices();
  const [count, setCount] = useState(0);

  useEffect(() => {
    api.get<{ count: number }>('/items/count')
      .then((data) => setCount(data.count));
  }, [api]);

  return <Card title="Items">{count} items</Card>;
}
""",
        encoding="utf-8",
    )

    # index.ts (manifest)
    (ext_dir / "index.ts").write_text(
        """import type { ExtensionManifest } from '@/core';

const manifest: ExtensionManifest = {
  id: 'sample',
  name: 'Sample Extension',
  version: '1.0.0',
  description: 'A sample extension to demonstrate the architecture',
  navigation: [
    { label: 'Sample', path: '/sample', icon: 'box', order: 100 },
  ],
  routes: [
    { path: '/sample', component: () => import('./pages/SamplePage') },
  ],
  mountPoints: [
    {
      mountPoint: 'dashboard-widgets',
      component: () => import('./widgets/ItemCountCard'),
      order: 100,
    },
  ],
};

export default manifest;
""",
        encoding="utf-8",
    )

    console.print(f"[green]GENERATED sample extension:[/green] {ext_dir}")
