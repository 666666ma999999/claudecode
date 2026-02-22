"""Hooks compiler: collects hook scripts from extensions."""

from __future__ import annotations

import shutil
from pathlib import Path

from ..models import ExtensionManifest


class HooksCompiler:
    """Copies hook scripts from each extension into the output hooks/ directory."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_dir: Path,
        dry_run: bool = False,
    ) -> dict[str, str]:
        """Copy all hook scripts, preserving original filenames.

        Returns:
            Mapping of output_path (relative) -> source extension name.
        """
        file_map: dict[str, str] = {}

        for ext_dir, manifest in extensions:
            hooks_dir = ext_dir / "hooks"
            if not hooks_dir.is_dir():
                continue

            for hook_file in sorted(hooks_dir.rglob("*")):
                if not hook_file.is_file():
                    continue

                rel_in_hooks = hook_file.relative_to(hooks_dir)
                dest = output_dir / rel_in_hooks
                rel_dest = str(Path("hooks") / rel_in_hooks)

                if not dry_run:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(hook_file, dest)
                    # Preserve execute permission
                    if hook_file.stat().st_mode & 0o111:
                        dest.chmod(dest.stat().st_mode | 0o111)

                file_map[rel_dest] = manifest.name

        return file_map
