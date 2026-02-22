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
    ) -> dict[str, str]:
        """Generate 30-routing.md from all extensions' routing entries.

        The file also includes claude_md_section content from extensions that
        define routing-related supplementary text (e.g. secret-management's
        additional policy text that currently lives in 30-routing.md).

        Returns:
            Mapping of output_path (relative) -> "routing-compiler" (synthetic source).
        """
        file_map: dict[str, str] = {}

        # Collect all routing entries
        rows: list[tuple[str, str]] = []
        extra_sections: list[tuple[str, str]] = []  # (ext_name, section_text)

        for _ext_dir, manifest in extensions:
            for entry in manifest.routing:
                triggers_text = ", ".join(entry.triggers)
                rows.append((triggers_text, f"`{entry.skill}`"))

            if manifest.claude_md_section:
                extra_sections.append((manifest.name, manifest.claude_md_section))

        if not rows and not extra_sections:
            return file_map

        # Build markdown content
        lines: list[str] = [
            "# スキルルーティング & 追加ルール",
            "",
            "## スキルルーティング",
            "",
            "回答・作業前に、以下のマッピングを確認し該当スキルを参照すること:",
            "",
            "| トリガー | 参照スキル |",
            "|---------|-----------|",
        ]

        for triggers_text, skill_ref in rows:
            lines.append(f"| {triggers_text} | {skill_ref} |")

        # Append extra sections from extensions
        for _ext_name, section_text in extra_sections:
            lines.append("")
            lines.append(section_text.rstrip())

        lines.append("")  # trailing newline

        content = "\n".join(lines)
        dest = output_dir / "30-routing.md"
        rel_dest = str(Path("rules") / "30-routing.md")

        if not dry_run:
            output_dir.mkdir(parents=True, exist_ok=True)
            dest.write_text(content, encoding="utf-8")

        file_map[rel_dest] = "routing-compiler"
        return file_map
