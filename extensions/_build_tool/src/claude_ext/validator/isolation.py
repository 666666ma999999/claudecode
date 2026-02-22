"""Isolation validator: detects cross-extension references."""

from __future__ import annotations

import re
from pathlib import Path

from ..models import ExtensionManifest


class IsolationValidator:
    """Ensures extensions do not reference each other's internals."""

    def validate(
        self,
        ext_name: str,
        ext_dir: Path,
        all_extensions: dict[str, ExtensionManifest],
    ) -> list[str]:
        """Scan text files in *ext_dir* for references to other extensions.

        Checks:
        1. Skill files (SKILL.md, CLAUDE.md, *.md in skills/) referencing other ext skill names.
        2. Rule files referencing other ext skill names.
        3. Hook scripts referencing other ext directory paths.
        4. Command files referencing other ext skill/command names.

        Returns:
            List of error strings. Empty means no violations found.
        """
        errors: list[str] = []

        # Build reference sets from other extensions
        other_ext_names: set[str] = set()
        other_skill_names: set[str] = set()
        other_command_names: set[str] = set()

        for name, manifest in all_extensions.items():
            if name == ext_name:
                continue
            other_ext_names.add(name)
            # Collect skill directory names from routing entries
            for route in manifest.routing:
                other_skill_names.add(route.skill)

        # Also scan other ext dirs for actual skill directory names
        ext_parent = ext_dir.parent
        for name in other_ext_names:
            other_dir = ext_parent / name
            skills_dir = other_dir / "skills"
            if skills_dir.is_dir():
                for skill_dir in skills_dir.iterdir():
                    if skill_dir.is_dir():
                        other_skill_names.add(skill_dir.name)
            commands_dir = other_dir / "commands"
            if commands_dir.is_dir():
                for cmd_file in commands_dir.iterdir():
                    if cmd_file.is_file():
                        other_command_names.add(cmd_file.stem)

        if not other_ext_names and not other_skill_names:
            return errors

        # Build search patterns
        # For extension names, look for directory-style references like extensions/other-ext
        ext_path_patterns = [
            re.compile(rf"extensions/{re.escape(n)}(?:/|\b)") for n in other_ext_names
        ]

        # Scan relevant files
        scan_dirs = ["skills", "rules", "hooks", "commands"]
        scan_extensions = {".md", ".py", ".sh", ".yaml", ".yml", ".txt"}

        for scan_dir_name in scan_dirs:
            scan_dir = ext_dir / scan_dir_name
            if not scan_dir.is_dir():
                continue

            for file_path in scan_dir.rglob("*"):
                if not file_path.is_file():
                    continue
                if file_path.suffix not in scan_extensions:
                    continue

                try:
                    content = file_path.read_text(encoding="utf-8")
                except (UnicodeDecodeError, OSError):
                    continue

                rel_path = file_path.relative_to(ext_dir)

                # Check for other extension path references
                for pattern in ext_path_patterns:
                    matches = pattern.findall(content)
                    if matches:
                        ref_ext = matches[0].split("/")[1] if "/" in matches[0] else matches[0]
                        ref_ext = ref_ext.rstrip("/")
                        errors.append(
                            f"[{ext_name}] File '{rel_path}' references "
                            f"other extension path: 'extensions/{ref_ext}'"
                        )

                # Check for other skill name references (word boundary match)
                for skill_name in other_skill_names:
                    # Use word-boundary-like matching to reduce false positives
                    # Match skill name as a standalone token (not part of a larger word)
                    pattern = re.compile(
                        rf"(?<![a-zA-Z0-9_-]){re.escape(skill_name)}(?![a-zA-Z0-9_-])"
                    )
                    if pattern.search(content):
                        # Skip if this skill also exists in the current extension
                        own_skill_dir = ext_dir / "skills" / skill_name
                        if own_skill_dir.is_dir():
                            continue
                        errors.append(
                            f"[{ext_name}] File '{rel_path}' references "
                            f"skill '{skill_name}' from another extension"
                        )

                # Check for other command name references in command files
                if scan_dir_name == "commands":
                    for cmd_name in other_command_names:
                        pattern = re.compile(
                            rf"(?<![a-zA-Z0-9_-]){re.escape(cmd_name)}(?![a-zA-Z0-9_-])"
                        )
                        if pattern.search(content):
                            own_cmd = ext_dir / "commands" / f"{cmd_name}.md"
                            if own_cmd.exists():
                                continue
                            errors.append(
                                f"[{ext_name}] Command file '{rel_path}' references "
                                f"command '{cmd_name}' from another extension"
                            )

        return errors
