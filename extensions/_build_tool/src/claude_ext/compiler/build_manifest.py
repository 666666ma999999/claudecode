"""Build manifest compiler: generates .build-manifest.json for traceability."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from ..models import BuildManifest


class BuildManifestCompiler:
    """Generates the .build-manifest.json file."""

    def compile(
        self,
        extension_names: list[str],
        file_map: dict[str, str],
        output_file: Path,
        dry_run: bool = False,
    ) -> None:
        """Write the build manifest.

        Args:
            extension_names: Names of all extensions included in the build.
            file_map: Combined mapping of all output files -> source extension.
            output_file: Path to write .build-manifest.json.
            dry_run: If True, do not write.
        """
        manifest = BuildManifest(
            built_at=datetime.now(timezone.utc).isoformat(),
            extensions=sorted(extension_names),
            files=dict(sorted(file_map.items())),
        )

        if not dry_run:
            output_file.parent.mkdir(parents=True, exist_ok=True)
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(manifest.model_dump(), f, indent=2, ensure_ascii=False)
                f.write("\n")
