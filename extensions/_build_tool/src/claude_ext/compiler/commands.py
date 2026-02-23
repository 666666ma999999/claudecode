"""Commands compiler: collects command files from extensions."""

from __future__ import annotations

import shutil
from pathlib import Path

from ..models import ExtensionManifest


class CommandsCompiler:
    """Copies command files from each extension into the output commands/ directory."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_dir: Path,
        dry_run: bool = False,
        content_map: dict[str, str] | None = None,
    ) -> dict[str, str]:
        """Copy all command files.

        Returns:
            Mapping of output_path (relative) -> source extension name.
        """
        file_map: dict[str, str] = {}

        for ext_dir, manifest in extensions:
            commands_dir = ext_dir / "commands"
            if not commands_dir.is_dir():
                continue

            for cmd_file in sorted(commands_dir.iterdir()):
                if not cmd_file.is_file():
                    continue

                dest = output_dir / cmd_file.name
                rel_dest = str(Path("commands") / cmd_file.name)

                if not dry_run:
                    output_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(cmd_file, dest)

                if content_map is not None:
                    content_map[rel_dest] = cmd_file.read_text(encoding="utf-8")

                file_map[rel_dest] = manifest.name

        return file_map
