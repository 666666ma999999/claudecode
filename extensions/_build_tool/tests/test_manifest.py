"""Tests for manifest parser and discovery."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest
import yaml

from claude_ext.manifest import discover_extensions, load_registry, parse_manifest
from claude_ext.models import ExtensionRegistry


class TestParseManifest:
    def test_valid_manifest(self, sample_ext_dir: Path):
        manifest = parse_manifest(sample_ext_dir / "extension.yaml")
        assert manifest.name == "sample-ext"
        assert manifest.version == "1.0.0"
        assert manifest.rule_number_range == [10, 19]
        assert len(manifest.routing) == 1

    def test_missing_file(self, tmp_path: Path):
        with pytest.raises(FileNotFoundError):
            parse_manifest(tmp_path / "nonexistent.yaml")

    def test_empty_file(self, tmp_path: Path):
        empty = tmp_path / "empty.yaml"
        empty.write_text("")
        with pytest.raises(ValueError, match="Empty"):
            parse_manifest(empty)


class TestLoadRegistry:
    def test_existing_registry(self, tmp_path: Path):
        registry_path = tmp_path / "registry.yaml"
        data = {"extensions": {"ext-a": True, "ext-b": False}}
        with open(registry_path, "w") as f:
            yaml.dump(data, f)

        reg = load_registry(registry_path)
        assert reg.extensions["ext-a"] is True
        assert reg.extensions["ext-b"] is False

    def test_missing_registry(self, tmp_path: Path):
        reg = load_registry(tmp_path / "missing.yaml")
        assert reg.extensions == {}

    def test_empty_registry(self, tmp_path: Path):
        registry_path = tmp_path / "empty.yaml"
        registry_path.write_text("")
        reg = load_registry(registry_path)
        assert reg.extensions == {}


class TestDiscoverExtensions:
    def test_discovers_fixture_extensions(self, fixtures_dir: Path):
        exts = discover_extensions(fixtures_dir)
        names = [m.name for _, m in exts]
        assert "sample-ext" in names
        assert "another-ext" in names

    def test_skips_underscore_dirs(self, tmp_path: Path):
        # Create _build_tool dir with manifest
        build_dir = tmp_path / "_build_tool"
        build_dir.mkdir()
        manifest = {"name": "build-tool", "version": "1.0.0"}
        with open(build_dir / "extension.yaml", "w") as f:
            yaml.dump(manifest, f)

        exts = discover_extensions(tmp_path)
        names = [m.name for _, m in exts]
        assert "build-tool" not in names

    def test_skips_non_directories(self, tmp_path: Path):
        (tmp_path / "some-file.txt").write_text("not a dir")
        exts = discover_extensions(tmp_path)
        assert exts == []

    def test_filters_by_registry(self, fixtures_dir: Path):
        registry = ExtensionRegistry(
            extensions={"sample-ext": True, "another-ext": False}
        )
        exts = discover_extensions(fixtures_dir, registry)
        names = [m.name for _, m in exts]
        assert "sample-ext" in names
        assert "another-ext" not in names

    def test_nonexistent_dir(self, tmp_path: Path):
        exts = discover_extensions(tmp_path / "nonexistent")
        assert exts == []
