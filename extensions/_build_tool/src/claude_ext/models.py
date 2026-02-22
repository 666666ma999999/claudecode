"""Pydantic models for Claude Code Extension System."""

from __future__ import annotations

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class HookEvent(str, Enum):
    """Supported hook lifecycle events."""

    SESSION_START = "SessionStart"
    PRE_TOOL_USE = "PreToolUse"
    POST_TOOL_USE = "PostToolUse"
    NOTIFICATION = "Notification"


class HookDef(BaseModel):
    """A single hook definition within an extension."""

    matcher: str = ""
    script: str  # e.g. hooks/block-dangerous-git.py


class RoutingEntry(BaseModel):
    """Maps trigger keywords to a skill name."""

    triggers: list[str]
    skill: str


class ExtensionManifest(BaseModel):
    """The parsed content of an extension.yaml file."""

    name: str
    version: str = "1.0.0"
    description: str = ""
    author: str = ""
    enabled: bool = True
    rule_number_range: Optional[list[int]] = None
    routing: list[RoutingEntry] = []
    hooks: dict[HookEvent, list[HookDef]] = {}
    permissions: Optional[dict[str, list[str]]] = None
    tags: list[str] = []
    claude_md_section: Optional[str] = None

    @field_validator("rule_number_range")
    @classmethod
    def validate_rule_number_range(cls, v: Optional[list[int]]) -> Optional[list[int]]:
        if v is not None:
            if len(v) != 2:
                raise ValueError("rule_number_range must be a list of exactly 2 integers [start, end]")
            if v[0] > v[1]:
                raise ValueError(
                    f"rule_number_range start ({v[0]}) must be <= end ({v[1]})"
                )
        return v


class BuildManifest(BaseModel):
    """Build traceability manifest (.build-manifest.json)."""

    built_at: str
    extensions: list[str]
    files: dict[str, str]  # output_path -> source_extension


class ExtensionRegistry(BaseModel):
    """Contents of extension-registry.yaml."""

    extensions: dict[str, bool] = {}  # name -> enabled
