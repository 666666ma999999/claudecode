"""Shared test fixtures for claude-ext tests."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest
import yaml

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixtures_dir() -> Path:
    """Path to the test fixtures directory."""
    return FIXTURES_DIR


@pytest.fixture
def sample_ext_dir(fixtures_dir: Path) -> Path:
    """Path to the sample-ext fixture."""
    return fixtures_dir / "sample-ext"


@pytest.fixture
def another_ext_dir(fixtures_dir: Path) -> Path:
    """Path to the another-ext fixture."""
    return fixtures_dir / "another-ext"


@pytest.fixture
def tmp_base_dir(tmp_path: Path, fixtures_dir: Path) -> Path:
    """Create a temporary ~/.claude-like directory structure with extensions.

    Copies fixture extensions into tmp_path/extensions/ and creates
    a minimal settings.local.json and extension-registry.yaml.
    """
    base = tmp_path / "dot-claude"
    extensions = base / "extensions"
    extensions.mkdir(parents=True)

    # Copy fixture extensions
    for ext in ["sample-ext", "another-ext"]:
        src = fixtures_dir / ext
        if src.exists():
            shutil.copytree(src, extensions / ext)

    # Create extension-registry.yaml
    registry = {"extensions": {"sample-ext": True, "another-ext": True}}
    with open(extensions / "extension-registry.yaml", "w") as f:
        yaml.dump(registry, f)

    # Create settings.local.json
    local_settings = {
        "$schema": "https://json.schemastore.org/claude-code-settings.json",
        "env": {"TEST_VAR": "1"},
        "permissions": {"allow": ["Bash", "Read"], "deny": []},
    }
    import json

    with open(base / "settings.local.json", "w") as f:
        json.dump(local_settings, f)

    # Create output directories
    for d in ["rules", "skills", "commands", "hooks"]:
        (base / d).mkdir()

    return base
