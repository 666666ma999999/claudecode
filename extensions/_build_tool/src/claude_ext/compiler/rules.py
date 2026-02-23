"""Rules compiler: collects and copies rule files from extensions."""

from __future__ import annotations

import shutil
from pathlib import Path

from ..models import ExtensionManifest


class RulesCompiler:
    """Copies rule files from each extension into the output rules/ directory."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_dir: Path,
        dry_run: bool = False,
        content_map: dict[str, str] | None = None,
    ) -> dict[str, str]:
        """Collect rule files, preserving numbered filenames.

        Returns:
            Mapping of output_path (relative) -> source extension name.
        """
        file_map: dict[str, str] = {}

        for ext_dir, manifest in extensions:
            rules_dir = ext_dir / "rules"
            if not rules_dir.is_dir():
                continue

            for rule_file in sorted(rules_dir.glob("*.md")):
                dest = output_dir / rule_file.name
                rel_dest = str(Path("rules") / rule_file.name)

                if not dry_run:
                    output_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(rule_file, dest)

                if content_map is not None:
                    content_map[rel_dest] = rule_file.read_text(encoding="utf-8")

                file_map[rel_dest] = manifest.name

        return file_map
