"""Skills compiler: collects skill directories from extensions."""

from __future__ import annotations

import shutil
from pathlib import Path

from ..models import ExtensionManifest


class SkillsCompiler:
    """Copies skill directories from each extension into the output skills/ directory."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_dir: Path,
        dry_run: bool = False,
        content_map: dict[str, str] | None = None,
    ) -> dict[str, str]:
        """Copy all skill directories.

        Returns:
            Mapping of output_path (relative) -> source extension name.
        """
        file_map: dict[str, str] = {}

        for ext_dir, manifest in extensions:
            skills_dir = ext_dir / "skills"
            if not skills_dir.is_dir():
                continue

            for skill_dir in sorted(skills_dir.iterdir()):
                if not skill_dir.is_dir():
                    continue

                dest = output_dir / skill_dir.name
                if not dry_run:
                    output_dir.mkdir(parents=True, exist_ok=True)
                    if dest.exists():
                        shutil.rmtree(dest)
                    shutil.copytree(skill_dir, dest)

                # Map all files in the skill directory
                for file_path in skill_dir.rglob("*"):
                    if file_path.is_file():
                        rel = file_path.relative_to(skill_dir)
                        rel_dest = str(Path("skills") / skill_dir.name / rel)
                        file_map[rel_dest] = manifest.name

                        if content_map is not None:
                            try:
                                content_map[rel_dest] = file_path.read_text(encoding="utf-8")
                            except UnicodeDecodeError:
                                # Binary file: use repr of bytes for comparison
                                content_map[rel_dest] = repr(file_path.read_bytes())

        return file_map
