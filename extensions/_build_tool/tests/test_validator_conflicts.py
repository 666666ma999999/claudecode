"""Tests for conflict validator."""

from __future__ import annotations

import pytest

from claude_ext.models import ExtensionManifest, HookDef, HookEvent, RoutingEntry
from claude_ext.validator.conflicts import ConflictValidator


@pytest.fixture
def validator() -> ConflictValidator:
    return ConflictValidator()


class TestConflictValidator:
    def test_no_conflicts(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(
                    name="ext-a",
                    rule_number_range=[10, 19],
                    routing=[RoutingEntry(triggers=["a"], skill="skill-a")],
                ),
            ),
            (
                "ext-b",
                ExtensionManifest(
                    name="ext-b",
                    rule_number_range=[20, 29],
                    routing=[RoutingEntry(triggers=["b"], skill="skill-b")],
                ),
            ),
        ]
        errors = validator.validate(exts)
        assert errors == []

    def test_rule_range_overlap(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(name="ext-a", rule_number_range=[10, 19]),
            ),
            (
                "ext-b",
                ExtensionManifest(name="ext-b", rule_number_range=[15, 25]),
            ),
        ]
        errors = validator.validate(exts)
        assert any("Rule number range conflict" in e for e in errors)
        assert any("ext-a" in e and "ext-b" in e for e in errors)

    def test_rule_range_no_overlap_adjacent(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(name="ext-a", rule_number_range=[10, 19]),
            ),
            (
                "ext-b",
                ExtensionManifest(name="ext-b", rule_number_range=[20, 29]),
            ),
        ]
        errors = validator.validate(exts)
        assert not any("Rule number range" in e for e in errors)

    def test_duplicate_skill_name(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(
                    name="ext-a",
                    routing=[RoutingEntry(triggers=["a"], skill="shared-skill")],
                ),
            ),
            (
                "ext-b",
                ExtensionManifest(
                    name="ext-b",
                    routing=[RoutingEntry(triggers=["b"], skill="shared-skill")],
                ),
            ),
        ]
        errors = validator.validate(exts)
        assert any("Duplicate skill" in e and "shared-skill" in e for e in errors)

    def test_duplicate_hook_script_same_event(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(
                    name="ext-a",
                    hooks={
                        HookEvent.PRE_TOOL_USE: [
                            HookDef(matcher="Bash", script="hooks/check.sh")
                        ]
                    },
                ),
            ),
            (
                "ext-b",
                ExtensionManifest(
                    name="ext-b",
                    hooks={
                        HookEvent.PRE_TOOL_USE: [
                            HookDef(matcher="Write", script="hooks/check.sh")
                        ]
                    },
                ),
            ),
        ]
        errors = validator.validate(exts)
        assert any("Duplicate hook script" in e and "check.sh" in e for e in errors)

    def test_same_hook_script_different_events_ok(self, validator: ConflictValidator):
        exts = [
            (
                "ext-a",
                ExtensionManifest(
                    name="ext-a",
                    hooks={
                        HookEvent.PRE_TOOL_USE: [
                            HookDef(matcher="Bash", script="hooks/check.sh")
                        ]
                    },
                ),
            ),
            (
                "ext-b",
                ExtensionManifest(
                    name="ext-b",
                    hooks={
                        HookEvent.POST_TOOL_USE: [
                            HookDef(matcher="Bash", script="hooks/check.sh")
                        ]
                    },
                ),
            ),
        ]
        errors = validator.validate(exts)
        assert not any("Duplicate hook script" in e for e in errors)

    def test_three_way_overlap(self, validator: ConflictValidator):
        exts = [
            ("a", ExtensionManifest(name="a", rule_number_range=[0, 10])),
            ("b", ExtensionManifest(name="b", rule_number_range=[5, 15])),
            ("c", ExtensionManifest(name="c", rule_number_range=[12, 20])),
        ]
        errors = validator.validate(exts)
        # a-b overlap, b-c overlap
        assert len([e for e in errors if "Rule number range" in e]) == 2
