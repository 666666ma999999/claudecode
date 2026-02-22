"""Schema validator: checks individual extension manifest correctness."""

from __future__ import annotations

import re
from pathlib import Path

from ..models import ExtensionManifest, HookEvent

_KEBAB_CASE_RE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")


class SchemaValidator:
    """Validates a single extension's manifest and referenced files."""

    def validate(self, manifest: ExtensionManifest, ext_dir: Path) -> list[str]:
        """Return a list of error strings. An empty list means valid.

        Checks performed:
        1. ``name`` is kebab-case.
        2. Hook scripts referenced in the manifest exist on disk.
        3. ``rule_number_range`` is well-formed ([start, end], start <= end).
        4. Routing skill references exist in the extension's skills/ directory.
        """
        errors: list[str] = []
        ext_name = manifest.name

        # 1. name must be kebab-case
        if not _KEBAB_CASE_RE.match(ext_name):
            errors.append(
                f"[{ext_name}] Extension name '{ext_name}' is not valid kebab-case "
                f"(expected pattern: lowercase-words-joined-by-hyphens)"
            )

        # 2. Hook scripts must exist
        for event, hook_defs in manifest.hooks.items():
            for hook in hook_defs:
                script_path = ext_dir / hook.script
                if not script_path.exists():
                    errors.append(
                        f"[{ext_name}] Hook script not found: {hook.script} "
                        f"(event: {event.value}, expected at: {script_path})"
                    )

        # 3. rule_number_range validation (Pydantic already validates basic shape,
        #    but we double-check here for completeness)
        if manifest.rule_number_range is not None:
            rng = manifest.rule_number_range
            if len(rng) != 2:
                errors.append(
                    f"[{ext_name}] rule_number_range must have exactly 2 elements, "
                    f"got {len(rng)}"
                )
            elif rng[0] > rng[1]:
                errors.append(
                    f"[{ext_name}] rule_number_range start ({rng[0]}) > end ({rng[1]})"
                )

        # 4. Routing skill references must exist
        skills_dir = ext_dir / "skills"
        for entry in manifest.routing:
            skill_dir = skills_dir / entry.skill
            if not skill_dir.exists():
                errors.append(
                    f"[{ext_name}] Routing references skill '{entry.skill}' "
                    f"but directory not found: {skill_dir}"
                )

        # 5. Rules directory files should match rule_number_range prefix
        rules_dir = ext_dir / "rules"
        if rules_dir.is_dir() and manifest.rule_number_range is not None:
            start, end = manifest.rule_number_range
            for rule_file in sorted(rules_dir.glob("*.md")):
                # Extract leading digits from filename
                match = re.match(r"^(\d+)", rule_file.name)
                if match:
                    num = int(match.group(1))
                    if num < start or num > end:
                        errors.append(
                            f"[{ext_name}] Rule file '{rule_file.name}' has number "
                            f"{num} outside declared range [{start}, {end}]"
                        )

        return errors
