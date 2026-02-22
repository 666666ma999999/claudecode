"""CLAUDE.md compiler: merges template with extension sections."""

from __future__ import annotations

from pathlib import Path

from ..models import ExtensionManifest

_DEFAULT_TEMPLATE = """\
# エージェント運用方針

あなたはマネージャーでagentオーケストレーターです。あなたは絶対に実践せず、全てsubagentやtaskagentに委託すること。タスクは超細分化し、PDCAサイクルを構築すること。

{extension_sections}
"""


class ClaudeMdCompiler:
    """Generates CLAUDE.md from a template and per-extension sections."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_file: Path,
        template_path: Path | None = None,
        dry_run: bool = False,
    ) -> dict[str, str]:
        """Generate CLAUDE.md.

        If *template_path* is provided, its contents are used as the base with
        ``{extension_sections}`` replaced by collected sections. Otherwise a
        minimal default template is used.

        Returns:
            Mapping of output_path (relative) -> "claude-md-compiler".
        """
        file_map: dict[str, str] = {}

        # Load template
        if template_path and template_path.exists():
            template = template_path.read_text(encoding="utf-8")
        else:
            template = _DEFAULT_TEMPLATE

        # Collect extension sections from CLAUDE.md-contributing extensions
        sections: list[str] = []
        for _ext_dir, manifest in extensions:
            if manifest.claude_md_section:
                sections.append(manifest.claude_md_section.rstrip())

        section_text = "\n\n".join(sections)

        content = template.replace("{extension_sections}", section_text)

        rel_dest = "CLAUDE.md"

        if not dry_run:
            output_file.parent.mkdir(parents=True, exist_ok=True)
            output_file.write_text(content, encoding="utf-8")

        file_map[rel_dest] = "claude-md-compiler"
        return file_map
