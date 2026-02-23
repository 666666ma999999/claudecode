"""CLI interface for claude-ext build tool."""

from __future__ import annotations

from pathlib import Path

import click
import yaml
from rich.console import Console
from rich.table import Table

from .builder import ExtensionBuilder
from .manifest import discover_extensions, load_registry, parse_manifest
from .models import ExtensionRegistry
from .project_init import init_project
from .be_project_init import init_be_project
from .validator import ExtensionValidator

console = Console()

DEFAULT_BASE_DIR = Path.home() / ".claude"


def _get_builder(base_dir: Path | None = None) -> ExtensionBuilder:
    return ExtensionBuilder(base_dir or DEFAULT_BASE_DIR)


@click.group()
@click.option(
    "--base-dir",
    type=click.Path(exists=True, path_type=Path),
    default=None,
    help="Base directory (default: ~/.claude)",
)
@click.pass_context
def cli(ctx: click.Context, base_dir: Path | None) -> None:
    """Claude Code Extension Build Tool."""
    ctx.ensure_object(dict)
    ctx.obj["base_dir"] = base_dir or DEFAULT_BASE_DIR


@cli.command()
@click.option("--force", is_flag=True, help="Continue despite validation errors.")
@click.option("--dry-run", is_flag=True, help="Show what would be done without writing files.")
@click.pass_context
def build(ctx: click.Context, force: bool, dry_run: bool) -> None:
    """Build all enabled extensions into ~/.claude/."""
    builder = _get_builder(ctx.obj["base_dir"])
    result = builder.build(force=force, dry_run=dry_run)

    if dry_run:
        console.print("[bold cyan]Dry run:[/bold cyan] no files written.")

    if result.warnings:
        for w in result.warnings:
            console.print(f"[yellow]WARNING:[/yellow] {w}")

    if not result.success:
        console.print("[bold red]Build failed:[/bold red]")
        for e in result.errors:
            console.print(f"  [red]{e}[/red]")
        raise SystemExit(1)

    console.print(
        f"[bold green]Build successful.[/bold green] "
        f"{len(result.extensions)} extension(s), {len(result.file_map)} file(s)."
    )
    for ext in result.extensions:
        console.print(f"  [green]+[/green] {ext}")


@cli.command()
@click.option("--extension", "-e", default=None, help="Validate a single extension.")
@click.pass_context
def validate(ctx: click.Context, extension: str | None) -> None:
    """Validate extension manifests and structure."""
    base_dir = ctx.obj["base_dir"]
    extensions_dir = base_dir / "extensions"
    registry = load_registry(extensions_dir / "extension-registry.yaml")

    if extension:
        ext_dir = extensions_dir / extension
        manifest_path = ext_dir / "extension.yaml"
        if not manifest_path.exists():
            console.print(f"[red]Extension not found:[/red] {extension}")
            raise SystemExit(1)
        manifest = parse_manifest(manifest_path)
        extensions = [(ext_dir, manifest)]
    else:
        extensions = discover_extensions(extensions_dir, registry)

    validator = ExtensionValidator()
    errors = validator.validate_all(extensions)

    if errors:
        console.print(f"[bold red]{len(errors)} error(s) found:[/bold red]")
        for e in errors:
            console.print(f"  [red]{e}[/red]")
        raise SystemExit(1)
    else:
        console.print(
            f"[bold green]All {len(extensions)} extension(s) valid.[/bold green]"
        )


@cli.command(name="list")
@click.pass_context
def list_extensions(ctx: click.Context) -> None:
    """List all discovered extensions."""
    base_dir = ctx.obj["base_dir"]
    extensions_dir = base_dir / "extensions"
    registry = load_registry(extensions_dir / "extension-registry.yaml")

    # Discover all (without registry filter) to show disabled ones too
    all_exts = discover_extensions(extensions_dir)

    if not all_exts:
        console.print("[yellow]No extensions found.[/yellow]")
        return

    table = Table(title="Extensions")
    table.add_column("Name", style="cyan")
    table.add_column("Version")
    table.add_column("Enabled", justify="center")
    table.add_column("Rules")
    table.add_column("Skills")
    table.add_column("Hooks")
    table.add_column("Description")

    for ext_dir, manifest in all_exts:
        enabled = registry.extensions.get(manifest.name, manifest.enabled)
        enabled_str = "[green]yes[/green]" if enabled else "[red]no[/red]"

        rules_range = ""
        if manifest.rule_number_range:
            rules_range = f"[{manifest.rule_number_range[0]}-{manifest.rule_number_range[1]}]"

        skill_count = str(len(list((ext_dir / "skills").iterdir()))) if (ext_dir / "skills").is_dir() else "0"
        hook_count = str(sum(len(h) for h in manifest.hooks.values()))

        table.add_row(
            manifest.name,
            manifest.version,
            enabled_str,
            rules_range,
            skill_count,
            hook_count,
            manifest.description[:50] if manifest.description else "",
        )

    console.print(table)


@cli.command()
@click.argument("name")
@click.pass_context
def enable(ctx: click.Context, name: str) -> None:
    """Enable an extension."""
    _set_extension_enabled(ctx.obj["base_dir"], name, True)
    console.print(f"[green]Enabled:[/green] {name}")


@cli.command()
@click.argument("name")
@click.pass_context
def disable(ctx: click.Context, name: str) -> None:
    """Disable an extension."""
    _set_extension_enabled(ctx.obj["base_dir"], name, False)
    console.print(f"[yellow]Disabled:[/yellow] {name}")


@cli.command()
@click.argument("name")
@click.pass_context
def new(ctx: click.Context, name: str) -> None:
    """Scaffold a new extension."""
    base_dir = ctx.obj["base_dir"]
    ext_dir = base_dir / "extensions" / name

    if ext_dir.exists():
        console.print(f"[red]Extension already exists:[/red] {name}")
        raise SystemExit(1)

    ext_dir.mkdir(parents=True)

    manifest_content = {
        "name": name,
        "version": "1.0.0",
        "description": "",
        "author": "",
        "enabled": True,
        "tags": [],
    }

    manifest_path = ext_dir / "extension.yaml"
    with open(manifest_path, "w", encoding="utf-8") as f:
        yaml.dump(manifest_content, f, default_flow_style=False, allow_unicode=True)

    # Create standard subdirectories
    for subdir in ["rules", "skills", "hooks", "commands"]:
        (ext_dir / subdir).mkdir()

    console.print(f"[green]Created extension:[/green] {name}")
    console.print(f"  Directory: {ext_dir}")
    console.print(f"  Manifest:  {manifest_path}")


@cli.command()
@click.option("--dry-run", is_flag=True, help="Show what would be migrated.")
@click.pass_context
def migrate(ctx: click.Context, dry_run: bool) -> None:
    """Analyze current ~/.claude structure for migration to extensions."""
    base_dir = ctx.obj["base_dir"]

    console.print("[bold]Migration analysis:[/bold]")

    # Check existing files
    for dirname in ["rules", "skills", "hooks", "commands"]:
        d = base_dir / dirname
        if d.is_dir():
            count = sum(1 for _ in d.rglob("*") if _.is_file())
            console.print(f"  {dirname}/: {count} file(s)")

    if dry_run:
        console.print("[cyan]Dry run — no changes made.[/cyan]")
    else:
        console.print(
            "[yellow]Migration must be performed by creating extension directories "
            "and running 'claude-ext build'.[/yellow]"
        )


@cli.command()
@click.pass_context
def clean(ctx: click.Context) -> None:
    """Remove build artifacts (files tracked in .build-manifest.json)."""
    builder = _get_builder(ctx.obj["base_dir"])
    removed = builder.clean()

    if removed:
        console.print(f"[green]Removed {len(removed)} file(s):[/green]")
        for r in removed:
            console.print(f"  [red]-[/red] {r}")
    else:
        console.print("[yellow]Nothing to clean.[/yellow]")


@cli.command()
@click.pass_context
def diff(ctx: click.Context) -> None:
    """Show differences between current state and next build."""
    builder = _get_builder(ctx.obj["base_dir"])
    output = builder.diff()
    console.print(output)


@cli.command()
@click.pass_context
def doctor(ctx: click.Context) -> None:
    """Diagnose the extension system health."""
    base_dir = ctx.obj["base_dir"]
    extensions_dir = base_dir / "extensions"
    issues: list[str] = []
    ok: list[str] = []

    # Check extensions directory
    if not extensions_dir.is_dir():
        issues.append("extensions/ directory does not exist")
    else:
        ok.append("extensions/ directory exists")

    # Check registry
    registry_path = extensions_dir / "extension-registry.yaml"
    if registry_path.exists():
        ok.append("extension-registry.yaml found")
    else:
        issues.append("extension-registry.yaml not found (will use manifest defaults)")

    # Check settings.local.json
    local_settings = base_dir / "settings.local.json"
    if local_settings.exists():
        ok.append("settings.local.json found")
    else:
        issues.append("settings.local.json not found (needed as build base)")

    # Check build manifest
    build_manifest = base_dir / ".build-manifest.json"
    if build_manifest.exists():
        ok.append(".build-manifest.json found (previous build exists)")
    else:
        issues.append(".build-manifest.json not found (no previous build)")

    # Check template
    template = extensions_dir / "_build_tool" / "templates" / "CLAUDE.md.tmpl"
    if template.exists():
        ok.append("CLAUDE.md template found")
    else:
        issues.append("CLAUDE.md template not found (will use default)")

    # Validate extensions if they exist
    if extensions_dir.is_dir():
        registry = load_registry(registry_path)
        extensions = discover_extensions(extensions_dir, registry)
        if extensions:
            validator = ExtensionValidator()
            errors = validator.validate_all(extensions)
            if errors:
                for e in errors:
                    issues.append(f"Validation: {e}")
            else:
                ok.append(f"All {len(extensions)} extension(s) pass validation")
        else:
            issues.append("No enabled extensions found")

    console.print("[bold]Extension System Health Check[/bold]\n")

    if ok:
        for item in ok:
            console.print(f"  [green]OK[/green] {item}")
    if issues:
        for item in issues:
            console.print(f"  [red]!!![/red] {item}")

    console.print()
    if issues:
        console.print(f"[yellow]{len(issues)} issue(s) found.[/yellow]")
        raise SystemExit(1)
    else:
        console.print("[bold green]All checks passed.[/bold green]")


@cli.command(name="init-project")
@click.argument("project_dir", type=click.Path(path_type=Path))
@click.option("--force", is_flag=True, help="Overwrite existing files.")
@click.pass_context
def init_project_cmd(ctx: click.Context, project_dir: Path, force: bool) -> None:
    """Initialize a project with FE Extension Architecture."""
    init_project(project_dir, force=force)


@cli.command(name="init-be-project")
@click.argument("project_dir", type=click.Path(path_type=Path))
@click.option("--force", is_flag=True, help="Overwrite existing files.")
@click.option("--stack", type=click.Choice(["python", "node"]), default="python", help="Technology stack (default: python).")
@click.pass_context
def init_be_project_cmd(ctx: click.Context, project_dir: Path, force: bool, stack: str) -> None:
    """Initialize a project with BE Extension Architecture."""
    init_be_project(project_dir, force=force, stack=stack)


def _set_extension_enabled(base_dir: Path, name: str, enabled: bool) -> None:
    """Update the registry to enable/disable an extension."""
    registry_path = base_dir / "extensions" / "extension-registry.yaml"

    if registry_path.exists():
        with open(registry_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    else:
        data = {}

    data.setdefault("extensions", {})
    data["extensions"][name] = enabled

    registry_path.parent.mkdir(parents=True, exist_ok=True)
    with open(registry_path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
