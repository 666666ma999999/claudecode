"""Tests for the build orchestrator."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from claude_ext.builder import ExtensionBuilder


class TestExtensionBuilder:
    def test_full_build(self, tmp_base_dir: Path):
        builder = ExtensionBuilder(tmp_base_dir)
        result = builder.build()

        assert result.success is True
        assert "sample-ext" in result.extensions
        assert "another-ext" in result.extensions
        assert len(result.file_map) > 0

        # Check outputs exist
        assert (tmp_base_dir / "rules" / "10-sample.md").exists()
        assert (tmp_base_dir / "skills" / "my-skill" / "SKILL.md").exists()
        assert (tmp_base_dir / "hooks" / "check.sh").exists()
        assert (tmp_base_dir / "commands" / "do-thing.md").exists()
        assert (tmp_base_dir / "settings.json").exists()
        assert (tmp_base_dir / ".build-manifest.json").exists()

        # Verify settings.json has merged content
        with open(tmp_base_dir / "settings.json") as f:
            settings = json.load(f)
        assert settings["env"]["TEST_VAR"] == "1"

    def test_dry_run_no_files(self, tmp_base_dir: Path):
        builder = ExtensionBuilder(tmp_base_dir)
        result = builder.build(dry_run=True)

        assert result.success is True
        assert len(result.extensions) > 0
        # No build manifest written
        assert not (tmp_base_dir / ".build-manifest.json").exists()

    def test_build_with_validation_errors_no_force(self, tmp_base_dir: Path):
        # Create an extension with validation errors
        bad_ext = tmp_base_dir / "extensions" / "bad-ext"
        bad_ext.mkdir(parents=True)
        import yaml

        manifest = {
            "name": "Bad_Name",  # not kebab-case
            "version": "1.0.0",
        }
        with open(bad_ext / "extension.yaml", "w") as f:
            yaml.dump(manifest, f)

        # Update registry
        registry_path = tmp_base_dir / "extensions" / "extension-registry.yaml"
        with open(registry_path) as f:
            reg = yaml.safe_load(f)
        reg["extensions"]["Bad_Name"] = True
        with open(registry_path, "w") as f:
            yaml.dump(reg, f)

        builder = ExtensionBuilder(tmp_base_dir)
        result = builder.build()

        assert result.success is False
        assert len(result.errors) > 0

    def test_build_with_force(self, tmp_base_dir: Path):
        # Even with errors, force should succeed
        bad_ext = tmp_base_dir / "extensions" / "bad-ext"
        bad_ext.mkdir(parents=True)
        import yaml

        manifest = {
            "name": "Bad_Name",
            "version": "1.0.0",
        }
        with open(bad_ext / "extension.yaml", "w") as f:
            yaml.dump(manifest, f)

        registry_path = tmp_base_dir / "extensions" / "extension-registry.yaml"
        with open(registry_path) as f:
            reg = yaml.safe_load(f)
        reg["extensions"]["Bad_Name"] = True
        with open(registry_path, "w") as f:
            yaml.dump(reg, f)

        builder = ExtensionBuilder(tmp_base_dir)
        result = builder.build(force=True)

        assert result.success is True
        assert len(result.warnings) > 0

    def test_clean(self, tmp_base_dir: Path):
        builder = ExtensionBuilder(tmp_base_dir)
        # First build
        builder.build()
        assert (tmp_base_dir / ".build-manifest.json").exists()

        # Then clean
        removed = builder.clean()
        assert len(removed) > 0
        assert not (tmp_base_dir / ".build-manifest.json").exists()

    def test_clean_no_manifest(self, tmp_base_dir: Path):
        builder = ExtensionBuilder(tmp_base_dir)
        removed = builder.clean()
        assert removed == []

    def test_diff(self, tmp_base_dir: Path):
        builder = ExtensionBuilder(tmp_base_dir)
        diff_output = builder.diff()

        # Should show files to add (no previous build)
        assert "add" in diff_output.lower() or "No changes" in diff_output

    def test_no_extensions_warning(self, tmp_path: Path):
        base = tmp_path / "empty-base"
        base.mkdir()
        (base / "extensions").mkdir()

        builder = ExtensionBuilder(base)
        result = builder.build()

        assert result.success is True
        assert any("No enabled extensions" in w for w in result.warnings)
