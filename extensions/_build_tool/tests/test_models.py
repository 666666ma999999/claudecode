"""Tests for Pydantic models."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from claude_ext.models import (
    BuildManifest,
    ExtensionManifest,
    ExtensionRegistry,
    HookDef,
    HookEvent,
    RoutingEntry,
)


class TestExtensionManifest:
    def test_minimal(self):
        m = ExtensionManifest(name="my-ext")
        assert m.name == "my-ext"
        assert m.version == "1.0.0"
        assert m.enabled is True
        assert m.hooks == {}
        assert m.routing == []

    def test_full(self):
        m = ExtensionManifest(
            name="full-ext",
            version="2.0.0",
            description="A test",
            author="tester",
            enabled=False,
            rule_number_range=[10, 19],
            routing=[RoutingEntry(triggers=["a", "b"], skill="my-skill")],
            hooks={
                HookEvent.PRE_TOOL_USE: [HookDef(matcher="Bash", script="hooks/x.sh")]
            },
            permissions={"deny": ["Bash(rm*)"]},
            tags=["test"],
            claude_md_section="## Extra",
        )
        assert m.version == "2.0.0"
        assert m.rule_number_range == [10, 19]
        assert len(m.routing) == 1
        assert m.routing[0].skill == "my-skill"

    def test_rule_number_range_validation_start_gt_end(self):
        with pytest.raises(ValidationError, match="start.*<=.*end"):
            ExtensionManifest(name="bad", rule_number_range=[20, 10])

    def test_rule_number_range_validation_wrong_length(self):
        with pytest.raises(ValidationError, match="exactly 2"):
            ExtensionManifest(name="bad", rule_number_range=[1, 2, 3])


class TestHookEvent:
    def test_values(self):
        assert HookEvent.SESSION_START.value == "SessionStart"
        assert HookEvent.PRE_TOOL_USE.value == "PreToolUse"
        assert HookEvent.POST_TOOL_USE.value == "PostToolUse"
        assert HookEvent.NOTIFICATION.value == "Notification"


class TestBuildManifest:
    def test_creation(self):
        m = BuildManifest(
            built_at="2026-01-01T00:00:00Z",
            extensions=["a", "b"],
            files={"rules/10.md": "a"},
        )
        assert len(m.extensions) == 2
        assert m.files["rules/10.md"] == "a"


class TestExtensionRegistry:
    def test_default_empty(self):
        r = ExtensionRegistry()
        assert r.extensions == {}

    def test_with_extensions(self):
        r = ExtensionRegistry(extensions={"a": True, "b": False})
        assert r.extensions["a"] is True
        assert r.extensions["b"] is False
