"""Routing compiler: generates 30-routing.md from all extension routing definitions."""

from __future__ import annotations

from pathlib import Path

from ..models import ExtensionManifest


class RoutingCompiler:
    """Generates the consolidated 30-routing.md rule file."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_dir: Path,
        dry_run: bool = False,
        content_map: dict[str, str] | None = None,
    ) -> dict[str, str]:
        """Generate 30-routing.md from all extensions' routing entries.

        Returns:
            Mapping of output_path (relative) -> "routing-compiler" (synthetic source).
        """
        file_map: dict[str, str] = {}

        # Collect all routing entries and notes
        rows: list[tuple[str, str]] = []
        notes: list[str] = []

        for _ext_dir, manifest in extensions:
            for entry in manifest.routing:
                triggers_text = "、".join(entry.triggers)
                if entry.skill:
                    rows.append((triggers_text, f"`{entry.skill}`"))
                elif entry.reference:
                    rows.append((triggers_text, entry.reference))

            if manifest.routing_note:
                notes.append(manifest.routing_note)

        if not rows:
            return file_map

        # Build markdown content
        lines: list[str] = [
            "# スキルルーティング & 追加ルール",
            "",
            "## スキルルーティング",
            "",
            "回答・作業前に、以下のマッピングを確認し該当スキルを参照すること:",
            "",
        ]

        # Insert routing notes as blockquotes before table
        for note in notes:
            lines.append(f"> {note}")
            lines.append("")

        lines.extend([
            "| トリガー | 参照スキル |",
            "|---------|-----------|",
        ])

        for triggers_text, skill_ref in rows:
            lines.append(f"| {triggers_text} | {skill_ref} |")

        lines.append("")  # trailing newline

        content = "\n".join(lines)
        dest = output_dir / "30-routing.md"
        rel_dest = str(Path("rules") / "30-routing.md")

        if not dry_run:
            output_dir.mkdir(parents=True, exist_ok=True)
            dest.write_text(content, encoding="utf-8")

        if content_map is not None:
            content_map[rel_dest] = content

        file_map[rel_dest] = "routing-compiler"
        return file_map
