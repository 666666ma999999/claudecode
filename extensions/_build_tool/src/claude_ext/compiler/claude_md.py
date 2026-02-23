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
        content_map: dict[str, str] | None = None,
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

        # Note: claude_md_section content from extensions is handled by
        # the RoutingCompiler (placed in 30-routing.md), not here.
        # The {extension_sections} placeholder is replaced with empty string.
        content = template.replace("{extension_sections}", "")

        rel_dest = "CLAUDE.md"

        if not dry_run:
            output_file.parent.mkdir(parents=True, exist_ok=True)
            output_file.write_text(content, encoding="utf-8")

        if content_map is not None:
            content_map[rel_dest] = content

        file_map[rel_dest] = "claude-md-compiler"
        return file_map
