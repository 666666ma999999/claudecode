"""Tests for isolation validator."""

from __future__ import annotations

from pathlib import Path

import pytest

from claude_ext.models import ExtensionManifest, RoutingEntry
from claude_ext.validator.isolation import IsolationValidator


@pytest.fixture
def validator() -> IsolationValidator:
    return IsolationValidator()


class TestIsolationValidator:
    def test_no_cross_references(
        self, validator: IsolationValidator, fixtures_dir: Path
    ):
        """sample-ext and another-ext fixture should have no cross-refs."""
        all_ext = {
            "sample-ext": ExtensionManifest(
                name="sample-ext",
                routing=[RoutingEntry(triggers=["t"], skill="my-skill")],
            ),
            "another-ext": ExtensionManifest(
                name="another-ext",
                routing=[RoutingEntry(triggers=["t"], skill="other-skill")],
            ),
        }
        errors = validator.validate(
            "sample-ext", fixtures_dir / "sample-ext", all_ext
        )
        assert errors == []

    def test_detects_skill_cross_reference(
        self, validator: IsolationValidator, tmp_path: Path
    ):
        """An extension that references another extension's skill should fail."""
        # Create ext-a with a skill file referencing ext-b's skill
        ext_a = tmp_path / "ext-a"
        skills = ext_a / "skills" / "a-skill"
        skills.mkdir(parents=True)
        (skills / "SKILL.md").write_text("Use b-skill for this task.")

        ext_b = tmp_path / "ext-b"
        b_skills = ext_b / "skills" / "b-skill"
        b_skills.mkdir(parents=True)
        (b_skills / "SKILL.md").write_text("B skill content")

        all_ext = {
            "ext-a": ExtensionManifest(
                name="ext-a",
                routing=[RoutingEntry(triggers=["t"], skill="a-skill")],
            ),
            "ext-b": ExtensionManifest(
                name="ext-b",
                routing=[RoutingEntry(triggers=["t"], skill="b-skill")],
            ),
        }
        errors = validator.validate("ext-a", ext_a, all_ext)
        assert any("b-skill" in e and "another extension" in e for e in errors)

    def test_detects_path_cross_reference(
        self, validator: IsolationValidator, tmp_path: Path
    ):
        """An extension referencing another extension's path should fail."""
        ext_a = tmp_path / "ext-a"
        rules = ext_a / "rules"
        rules.mkdir(parents=True)
        (rules / "10-rule.md").write_text(
            "See extensions/ext-b/skills for details."
        )

        all_ext = {
            "ext-a": ExtensionManifest(name="ext-a"),
            "ext-b": ExtensionManifest(name="ext-b"),
        }
        errors = validator.validate("ext-a", ext_a, all_ext)
        assert any("extensions/ext-b" in e for e in errors)

    def test_no_errors_for_single_extension(
        self, validator: IsolationValidator, tmp_path: Path
    ):
        """No cross-refs possible with only one extension."""
        ext = tmp_path / "solo"
        skills = ext / "skills" / "my-skill"
        skills.mkdir(parents=True)
        (skills / "SKILL.md").write_text("Just my own content.")

        all_ext = {
            "solo": ExtensionManifest(
                name="solo",
                routing=[RoutingEntry(triggers=["t"], skill="my-skill")],
            )
        }
        errors = validator.validate("solo", ext, all_ext)
        assert errors == []

    def test_own_skill_reference_ok(
        self, validator: IsolationValidator, tmp_path: Path
    ):
        """Referencing own skill should not be flagged."""
        ext = tmp_path / "ext-a"
        skills_a = ext / "skills" / "shared-skill"
        skills_a.mkdir(parents=True)
        (skills_a / "SKILL.md").write_text("Reference shared-skill here.")

        all_ext = {
            "ext-a": ExtensionManifest(
                name="ext-a",
                routing=[RoutingEntry(triggers=["t"], skill="shared-skill")],
            ),
            "ext-b": ExtensionManifest(
                name="ext-b",
                routing=[RoutingEntry(triggers=["t"], skill="shared-skill")],
            ),
        }
        # ext-a has its own shared-skill directory, so referencing it is OK
        errors = validator.validate("ext-a", ext, all_ext)
        assert not any("shared-skill" in e and "another extension" in e for e in errors)
