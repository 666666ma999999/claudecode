"""Build orchestrator: coordinates discovery, validation, and compilation."""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from .compiler import (
    BuildManifestCompiler,
    ClaudeMdCompiler,
    CommandsCompiler,
    HooksCompiler,
    RoutingCompiler,
    RulesCompiler,
    SettingsCompiler,
    SkillsCompiler,
)
from .manifest import discover_extensions, load_registry
from .models import BuildManifest, ExtensionManifest
from .validator import ExtensionValidator


@dataclass
class BuildResult:
    """Outcome of a build operation."""

    success: bool
    extensions: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    file_map: dict[str, str] = field(default_factory=dict)
    content_map: dict[str, str] = field(default_factory=dict)


def _normalize(text: str) -> str:
    """Normalize text for comparison (strip trailing whitespace per line, ensure single trailing newline)."""
    lines = text.rstrip().splitlines()
    return "\n".join(line.rstrip() for line in lines) + "\n"


class ExtensionBuilder:
    """Top-level build orchestrator."""

    def __init__(self, base_dir: Path) -> None:
        self.base_dir = base_dir
        self.extensions_dir = base_dir / "extensions"
        self.output_dirs = {
            "rules": base_dir / "rules",
            "skills": base_dir / "skills",
            "commands": base_dir / "commands",
            "hooks": base_dir / "hooks",
        }
        self.build_manifest_path = base_dir / ".build-manifest.json"
        self.registry_path = self.extensions_dir / "extension-registry.yaml"
        self.local_settings_path = base_dir / "settings.local.json"
        self.settings_output_path = base_dir / "settings.json"
        self.claude_md_output_path = base_dir / "CLAUDE.md"
        self.template_dir = self.extensions_dir / "_build_tool" / "templates"

    def build(
        self, force: bool = False, dry_run: bool = False
    ) -> BuildResult:
        """Execute the full build pipeline.

        Steps:
        1. Discover all extensions.
        2. Filter by registry (enabled only).
        3. Validate all extensions.
        4. Compile each output type.
        5. Write build manifest.

        Args:
            force: Skip validation errors and build anyway.
            dry_run: Do not write any files. When True, content_map is populated.

        Returns:
            BuildResult with success status, errors, file map, and content map.
        """
        result = BuildResult(success=True)

        # content_map collects {rel_path: file_content} during dry_run
        content_map: dict[str, str] = {} if dry_run else {}

        # 1. Discover
        registry = load_registry(self.registry_path)
        extensions = discover_extensions(self.extensions_dir, registry)

        if not extensions:
            result.warnings.append("No enabled extensions found.")
            return result

        result.extensions = [m.name for _, m in extensions]

        # 2. Validate
        validator = ExtensionValidator()
        errors = validator.validate_all(extensions)

        if errors:
            result.errors = errors
            if not force:
                result.success = False
                return result
            # With --force, continue but include errors as warnings
            result.warnings.extend(errors)
            result.errors = []

        # 3. Clean previous build outputs (only manifest-tracked files)
        if not dry_run:
            self._clean_build_outputs()

        # 4. Compile
        all_file_map: dict[str, str] = {}

        # Rules (without routing — routing is compiled separately)
        rules_compiler = RulesCompiler()
        all_file_map.update(
            rules_compiler.compile(
                extensions, self.output_dirs["rules"], dry_run,
                content_map=content_map,
            )
        )

        # Routing (generates 30-routing.md)
        routing_compiler = RoutingCompiler()
        all_file_map.update(
            routing_compiler.compile(
                extensions, self.output_dirs["rules"], dry_run,
                content_map=content_map,
            )
        )

        # Skills
        skills_compiler = SkillsCompiler()
        all_file_map.update(
            skills_compiler.compile(
                extensions, self.output_dirs["skills"], dry_run,
                content_map=content_map,
            )
        )

        # Commands
        commands_compiler = CommandsCompiler()
        all_file_map.update(
            commands_compiler.compile(
                extensions, self.output_dirs["commands"], dry_run,
                content_map=content_map,
            )
        )

        # Hooks
        hooks_compiler = HooksCompiler()
        all_file_map.update(
            hooks_compiler.compile(
                extensions, self.output_dirs["hooks"], dry_run,
                content_map=content_map,
            )
        )

        # CLAUDE.md
        claude_md_compiler = ClaudeMdCompiler()
        template_path = self.template_dir / "CLAUDE.md.tmpl"
        all_file_map.update(
            claude_md_compiler.compile(
                extensions,
                self.claude_md_output_path,
                template_path if template_path.exists() else None,
                dry_run,
                content_map=content_map,
            )
        )

        # Settings
        settings_compiler = SettingsCompiler()
        all_file_map.update(
            settings_compiler.compile(
                extensions,
                self.settings_output_path,
                self.local_settings_path,
                self.base_dir,
                dry_run,
                content_map=content_map,
            )
        )

        # 5. Build manifest
        manifest_compiler = BuildManifestCompiler()
        manifest_compiler.compile(
            result.extensions, all_file_map, self.build_manifest_path, dry_run
        )

        result.file_map = all_file_map
        result.content_map = content_map
        return result

    def clean(self) -> list[str]:
        """Remove files tracked by the build manifest.

        Returns:
            List of removed file paths (relative).
        """
        removed = self._clean_build_outputs()
        # Also remove the manifest itself
        if self.build_manifest_path.exists():
            self.build_manifest_path.unlink()
            removed.append(str(self.build_manifest_path.relative_to(self.base_dir)))
        return removed

    # Files in subdirectories that are NOT build outputs (e.g. claude-mem context).
    _SCAN_EXCLUDE_NAMES = {"CLAUDE.md"}

    def _scan_current_files(self) -> dict[str, str]:
        """Scan actual files in ~/.claude/ that are build output targets.

        Scans:
        - rules/*.md
        - skills/**/*
        - commands/* (excluding CLAUDE.md context files)
        - hooks/* (excluding CLAUDE.md context files)
        - settings.json
        - CLAUDE.md (top-level only)

        Returns:
            Mapping of rel_path -> file content.
        """
        current: dict[str, str] = {}

        # Rules
        rules_dir = self.base_dir / "rules"
        if rules_dir.is_dir():
            for f in sorted(rules_dir.glob("*.md")):
                rel = str(f.relative_to(self.base_dir))
                try:
                    current[rel] = f.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    current[rel] = repr(f.read_bytes())

        # Skills
        skills_dir = self.base_dir / "skills"
        if skills_dir.is_dir():
            for skill in sorted(skills_dir.iterdir()):
                if not skill.is_dir():
                    continue
                for f in skill.rglob("*"):
                    if f.is_file():
                        rel = str(f.relative_to(self.base_dir))
                        try:
                            current[rel] = f.read_text(encoding="utf-8")
                        except UnicodeDecodeError:
                            current[rel] = repr(f.read_bytes())

        # Commands
        commands_dir = self.base_dir / "commands"
        if commands_dir.is_dir():
            for f in sorted(commands_dir.iterdir()):
                if f.is_file():
                    rel = str(f.relative_to(self.base_dir))
                    try:
                        current[rel] = f.read_text(encoding="utf-8")
                    except UnicodeDecodeError:
                        current[rel] = repr(f.read_bytes())

        # Hooks
        hooks_dir = self.base_dir / "hooks"
        if hooks_dir.is_dir():
            for f in sorted(hooks_dir.rglob("*")):
                if f.is_file():
                    rel = str(f.relative_to(self.base_dir))
                    try:
                        current[rel] = f.read_text(encoding="utf-8")
                    except UnicodeDecodeError:
                        current[rel] = repr(f.read_bytes())

        # settings.json
        settings_file = self.base_dir / "settings.json"
        if settings_file.exists():
            current["settings.json"] = settings_file.read_text(encoding="utf-8")

        # CLAUDE.md
        claude_md_file = self.base_dir / "CLAUDE.md"
        if claude_md_file.exists():
            current["CLAUDE.md"] = claude_md_file.read_text(encoding="utf-8")

        return current

    def diff(self) -> str:
        """Show differences between current filesystem state and what a build would produce.

        Compares actual file contents (not just file lists) to detect modifications.

        Returns:
            Human-readable diff summary.
        """
        # Do a dry-run build to get expected content
        dry_result = self.build(dry_run=True, force=True)

        # Scan current filesystem
        current_files = self._scan_current_files()

        build_paths = set(dry_result.content_map.keys())
        current_paths = set(current_files.keys())

        identical: list[str] = []
        modified: list[str] = []
        added = sorted(build_paths - current_paths)       # build-only
        missing = sorted(current_paths - build_paths)      # current-only

        for rel_path in sorted(build_paths & current_paths):
            build_content = _normalize(dry_result.content_map[rel_path])
            current_content = _normalize(current_files[rel_path])
            if build_content == current_content:
                identical.append(rel_path)
            else:
                modified.append(rel_path)

        lines: list[str] = ["=== Build Diff ==="]

        lines.append(f"Identical: {len(identical)} files")

        if added:
            lines.append(f"Added (build only): {len(added)} files")
            for f in added:
                lines.append(f"  - {f}")

        if missing:
            lines.append(f"Missing (current only): {len(missing)} files")
            for f in missing:
                lines.append(f"  - {f}")

        if modified:
            lines.append(f"Modified: {len(modified)} files")
            for f in modified:
                lines.append(f"  - {f}")

        if not added and not missing and not modified:
            lines.append("No differences. Build output matches current state.")

        if dry_result.errors:
            lines.append("")
            lines.append("Validation errors:")
            for e in dry_result.errors:
                lines.append(f"  ! {e}")

        return "\n".join(lines)

    def _clean_build_outputs(self) -> list[str]:
        """Remove files listed in the build manifest.

        Returns:
            List of removed relative paths.
        """
        removed: list[str] = []

        if not self.build_manifest_path.exists():
            return removed

        with open(self.build_manifest_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        manifest = BuildManifest(**data)

        for rel_path in manifest.files:
            full_path = self.base_dir / rel_path
            if full_path.exists():
                if full_path.is_dir():
                    shutil.rmtree(full_path)
                else:
                    full_path.unlink()
                removed.append(rel_path)

        return removed
