"""Conflict validator: detects inter-extension conflicts."""

from __future__ import annotations

from pathlib import Path

from ..models import ExtensionManifest


class ConflictValidator:
    """Detects conflicts between multiple extensions."""

    def validate(
        self, extensions: list[tuple[str, ExtensionManifest]]
    ) -> list[str]:
        """Check for conflicts across all extensions.

        Checks:
        1. Overlapping rule_number_range values.
        2. Duplicate skill names across extensions.
        3. Duplicate command names across extensions.
        4. Duplicate hook script names within the same event.

        Args:
            extensions: List of (extension_name, manifest) tuples.

        Returns:
            List of error strings. Empty means no conflicts.
        """
        errors: list[str] = []

        errors.extend(self._check_rule_range_overlaps(extensions))
        errors.extend(self._check_skill_name_duplicates(extensions))
        errors.extend(self._check_command_name_duplicates(extensions))
        errors.extend(self._check_hook_script_duplicates(extensions))

        return errors

    def _check_rule_range_overlaps(
        self, extensions: list[tuple[str, ExtensionManifest]]
    ) -> list[str]:
        """Detect overlapping rule_number_range between extensions."""
        errors: list[str] = []
        ranges: list[tuple[str, int, int]] = []

        for ext_name, manifest in extensions:
            if manifest.rule_number_range is not None:
                start, end = manifest.rule_number_range
                ranges.append((ext_name, start, end))

        # Check every pair for overlaps
        for i, (name_a, start_a, end_a) in enumerate(ranges):
            for name_b, start_b, end_b in ranges[i + 1 :]:
                if start_a <= end_b and start_b <= end_a:
                    errors.append(
                        f"Rule number range conflict: '{name_a}' [{start_a}-{end_a}] "
                        f"overlaps with '{name_b}' [{start_b}-{end_b}]"
                    )

        return errors

    def _check_skill_name_duplicates(
        self, extensions: list[tuple[str, ExtensionManifest]]
    ) -> list[str]:
        """Detect skill names that appear in multiple extensions."""
        errors: list[str] = []
        skill_owners: dict[str, list[str]] = {}

        for ext_name, manifest in extensions:
            # Collect skill names from routing entries
            for entry in manifest.routing:
                skill_owners.setdefault(entry.skill, []).append(ext_name)

        for skill_name, owners in skill_owners.items():
            if len(owners) > 1:
                errors.append(
                    f"Duplicate skill '{skill_name}' found in extensions: "
                    f"{', '.join(sorted(owners))}"
                )

        return errors

    def _check_command_name_duplicates(
        self, extensions: list[tuple[str, ExtensionManifest]]
    ) -> list[str]:
        """Detect command filenames that appear in multiple extensions.

        We cannot check file-level commands purely from the manifest, so this
        relies on scanning the actual directories. For manifest-only validation
        this is a no-op; the builder calls a file-aware variant separately.
        """
        # This will be enhanced in the builder to scan actual directories.
        # Manifest-level duplicate commands are not detectable from the manifest
        # alone since command names are filesystem-based.
        return []

    def _check_hook_script_duplicates(
        self, extensions: list[tuple[str, ExtensionManifest]]
    ) -> list[str]:
        """Detect hook scripts with the same name under the same event."""
        errors: list[str] = []
        # event -> script_basename -> list of extension names
        event_scripts: dict[str, dict[str, list[str]]] = {}

        for ext_name, manifest in extensions:
            for event, hook_defs in manifest.hooks.items():
                event_key = event.value
                if event_key not in event_scripts:
                    event_scripts[event_key] = {}
                for hook in hook_defs:
                    # Use the basename of the script path as the identifier
                    script_name = Path(hook.script).name
                    event_scripts[event_key].setdefault(script_name, []).append(
                        ext_name
                    )

        for event_key, scripts in event_scripts.items():
            for script_name, owners in scripts.items():
                if len(owners) > 1:
                    errors.append(
                        f"Duplicate hook script '{script_name}' for event "
                        f"'{event_key}' in extensions: {', '.join(sorted(owners))}"
                    )

        return errors
