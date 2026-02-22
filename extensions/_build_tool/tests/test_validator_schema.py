"""Tests for schema validator."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from claude_ext.models import ExtensionManifest, HookDef, HookEvent, RoutingEntry
from claude_ext.validator.schema import SchemaValidator


@pytest.fixture
def validator() -> SchemaValidator:
    return SchemaValidator()


class TestSchemaValidator:
    def test_valid_extension(self, validator: SchemaValidator, sample_ext_dir: Path):
        from claude_ext.manifest import parse_manifest

        manifest = parse_manifest(sample_ext_dir / "extension.yaml")
        errors = validator.validate(manifest, sample_ext_dir)
        assert errors == []

    def test_invalid_name_not_kebab(self, validator: SchemaValidator, tmp_path: Path):
        manifest = ExtensionManifest(name="Not_Kebab_Case")
        errors = validator.validate(manifest, tmp_path)
        assert any("kebab-case" in e for e in errors)

    def test_invalid_name_uppercase(self, validator: SchemaValidator, tmp_path: Path):
        manifest = ExtensionManifest(name="MyExt")
        errors = validator.validate(manifest, tmp_path)
        assert any("kebab-case" in e for e in errors)

    def test_valid_kebab_names(self, validator: SchemaValidator, tmp_path: Path):
        for name in ["my-ext", "a", "ext-123", "some-long-name"]:
            manifest = ExtensionManifest(name=name)
            errors = validator.validate(manifest, tmp_path)
            assert not any("kebab-case" in e for e in errors), f"'{name}' should be valid"

    def test_missing_hook_script(self, validator: SchemaValidator, tmp_path: Path):
        manifest = ExtensionManifest(
            name="test-ext",
            hooks={
                HookEvent.PRE_TOOL_USE: [
                    HookDef(matcher="Bash", script="hooks/nonexistent.sh")
                ]
            },
        )
        errors = validator.validate(manifest, tmp_path)
        assert any("Hook script not found" in e for e in errors)

    def test_existing_hook_script(self, validator: SchemaValidator, tmp_path: Path):
        hooks_dir = tmp_path / "hooks"
        hooks_dir.mkdir()
        (hooks_dir / "check.sh").write_text("#!/bin/bash")

        manifest = ExtensionManifest(
            name="test-ext",
            hooks={
                HookEvent.PRE_TOOL_USE: [
                    HookDef(matcher="Bash", script="hooks/check.sh")
                ]
            },
        )
        errors = validator.validate(manifest, tmp_path)
        assert not any("Hook script" in e for e in errors)

    def test_missing_routing_skill(self, validator: SchemaValidator, tmp_path: Path):
        manifest = ExtensionManifest(
            name="test-ext",
            routing=[RoutingEntry(triggers=["test"], skill="nonexistent-skill")],
        )
        errors = validator.validate(manifest, tmp_path)
        assert any("Routing references skill" in e for e in errors)

    def test_existing_routing_skill(self, validator: SchemaValidator, tmp_path: Path):
        skill_dir = tmp_path / "skills" / "my-skill"
        skill_dir.mkdir(parents=True)

        manifest = ExtensionManifest(
            name="test-ext",
            routing=[RoutingEntry(triggers=["test"], skill="my-skill")],
        )
        errors = validator.validate(manifest, tmp_path)
        assert not any("Routing references skill" in e for e in errors)

    def test_rule_file_outside_range(self, validator: SchemaValidator, tmp_path: Path):
        rules_dir = tmp_path / "rules"
        rules_dir.mkdir()
        (rules_dir / "99-wrong.md").write_text("# Wrong range")

        manifest = ExtensionManifest(
            name="test-ext",
            rule_number_range=[10, 19],
        )
        errors = validator.validate(manifest, tmp_path)
        assert any("outside declared range" in e for e in errors)

    def test_rule_file_in_range(self, validator: SchemaValidator, tmp_path: Path):
        rules_dir = tmp_path / "rules"
        rules_dir.mkdir()
        (rules_dir / "15-good.md").write_text("# Good")

        manifest = ExtensionManifest(
            name="test-ext",
            rule_number_range=[10, 19],
        )
        errors = validator.validate(manifest, tmp_path)
        assert not any("outside declared range" in e for e in errors)
