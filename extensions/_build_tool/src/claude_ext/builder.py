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
            dry_run: Do not write any files.

        Returns:
            BuildResult with success status, errors, and file map.
        """
        result = BuildResult(success=True)

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
            rules_compiler.compile(extensions, self.output_dirs["rules"], dry_run)
        )

        # Routing (generates 30-routing.md)
        routing_compiler = RoutingCompiler()
        all_file_map.update(
            routing_compiler.compile(extensions, self.output_dirs["rules"], dry_run)
        )

        # Skills
        skills_compiler = SkillsCompiler()
        all_file_map.update(
            skills_compiler.compile(extensions, self.output_dirs["skills"], dry_run)
        )

        # Commands
        commands_compiler = CommandsCompiler()
        all_file_map.update(
            commands_compiler.compile(extensions, self.output_dirs["commands"], dry_run)
        )

        # Hooks
        hooks_compiler = HooksCompiler()
        all_file_map.update(
            hooks_compiler.compile(extensions, self.output_dirs["hooks"], dry_run)
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
            )
        )

        # 5. Build manifest
        manifest_compiler = BuildManifestCompiler()
        manifest_compiler.compile(
            result.extensions, all_file_map, self.build_manifest_path, dry_run
        )

        result.file_map = all_file_map
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

    def diff(self) -> str:
        """Show differences between current state and what a build would produce.

        Returns:
            Human-readable diff summary.
        """
        # Do a dry-run build
        dry_result = self.build(dry_run=True, force=True)

        # Load current build manifest
        current_files: set[str] = set()
        if self.build_manifest_path.exists():
            with open(self.build_manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            current_manifest = BuildManifest(**data)
            current_files = set(current_manifest.files.keys())

        new_files = set(dry_result.file_map.keys())

        added = sorted(new_files - current_files)
        removed = sorted(current_files - new_files)
        common = sorted(new_files & current_files)

        lines: list[str] = []
        if added:
            lines.append("Files to add:")
            for f in added:
                lines.append(f"  + {f}")
        if removed:
            lines.append("Files to remove:")
            for f in removed:
                lines.append(f"  - {f}")
        if common:
            lines.append(f"Files to update: {len(common)}")

        if not lines:
            lines.append("No changes detected.")

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
