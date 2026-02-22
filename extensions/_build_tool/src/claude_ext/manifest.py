"""Extension manifest discovery and parsing."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import yaml

from .models import ExtensionManifest, ExtensionRegistry


def parse_manifest(path: Path) -> ExtensionManifest:
    """Read an extension.yaml file and return a validated ExtensionManifest.

    Args:
        path: Path to the extension.yaml file.

    Raises:
        FileNotFoundError: If the file does not exist.
        yaml.YAMLError: If the YAML is malformed.
        pydantic.ValidationError: If the data does not match the schema.
    """
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if data is None:
        raise ValueError(f"Empty manifest file: {path}")

    return ExtensionManifest(**data)


def load_registry(registry_path: Path) -> ExtensionRegistry:
    """Load extension-registry.yaml.

    Args:
        registry_path: Path to extension-registry.yaml.

    Returns:
        ExtensionRegistry with enabled/disabled state per extension.
        Returns an empty registry if the file does not exist.
    """
    if not registry_path.exists():
        return ExtensionRegistry()

    with open(registry_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if data is None:
        return ExtensionRegistry()

    return ExtensionRegistry(**data)


def discover_extensions(
    extensions_dir: Path,
    registry: Optional[ExtensionRegistry] = None,
) -> list[tuple[Path, ExtensionManifest]]:
    """Discover and parse all extensions under the extensions directory.

    Directories starting with ``_`` (e.g. ``_build_tool``) are excluded.
    If a *registry* is provided, only extensions marked as enabled are returned.

    Args:
        extensions_dir: The ``~/.claude/extensions/`` directory.
        registry: Optional registry to filter by enabled state.

    Returns:
        A list of (extension_directory, manifest) tuples sorted by name.
    """
    if not extensions_dir.is_dir():
        return []

    results: list[tuple[Path, ExtensionManifest]] = []

    for child in sorted(extensions_dir.iterdir()):
        # Skip non-directories and underscore-prefixed directories
        if not child.is_dir():
            continue
        if child.name.startswith("_"):
            continue

        manifest_path = child / "extension.yaml"
        if not manifest_path.exists():
            continue

        manifest = parse_manifest(manifest_path)

        # Filter by registry if provided
        if registry is not None:
            enabled = registry.extensions.get(manifest.name, manifest.enabled)
            if not enabled:
                continue

        results.append((child, manifest))

    return results
