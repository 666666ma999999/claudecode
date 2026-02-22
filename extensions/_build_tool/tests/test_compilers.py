"""Tests for compiler modules."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from claude_ext.compiler.build_manifest import BuildManifestCompiler
from claude_ext.compiler.claude_md import ClaudeMdCompiler
from claude_ext.compiler.commands import CommandsCompiler
from claude_ext.compiler.hooks import HooksCompiler
from claude_ext.compiler.routing import RoutingCompiler
from claude_ext.compiler.rules import RulesCompiler
from claude_ext.compiler.settings import SettingsCompiler
from claude_ext.compiler.skills import SkillsCompiler
from claude_ext.manifest import discover_extensions


@pytest.fixture
def extensions(fixtures_dir: Path):
    return discover_extensions(fixtures_dir)


class TestRulesCompiler:
    def test_copies_rule_files(self, extensions, tmp_path: Path):
        compiler = RulesCompiler()
        output = tmp_path / "rules"
        file_map = compiler.compile(extensions, output)

        assert (output / "10-sample.md").exists()
        assert "rules/10-sample.md" in file_map
        assert file_map["rules/10-sample.md"] == "sample-ext"

    def test_dry_run(self, extensions, tmp_path: Path):
        compiler = RulesCompiler()
        output = tmp_path / "rules"
        file_map = compiler.compile(extensions, output, dry_run=True)

        assert not output.exists()
        assert len(file_map) > 0


class TestSkillsCompiler:
    def test_copies_skill_dirs(self, extensions, tmp_path: Path):
        compiler = SkillsCompiler()
        output = tmp_path / "skills"
        file_map = compiler.compile(extensions, output)

        assert (output / "my-skill" / "SKILL.md").exists()
        assert (output / "other-skill" / "SKILL.md").exists()

    def test_dry_run(self, extensions, tmp_path: Path):
        compiler = SkillsCompiler()
        output = tmp_path / "skills"
        file_map = compiler.compile(extensions, output, dry_run=True)

        assert not (output / "my-skill").exists()
        assert len(file_map) > 0


class TestCommandsCompiler:
    def test_copies_command_files(self, extensions, tmp_path: Path):
        compiler = CommandsCompiler()
        output = tmp_path / "commands"
        file_map = compiler.compile(extensions, output)

        assert (output / "do-thing.md").exists()
        assert file_map["commands/do-thing.md"] == "sample-ext"


class TestHooksCompiler:
    def test_copies_hook_files(self, extensions, tmp_path: Path):
        compiler = HooksCompiler()
        output = tmp_path / "hooks"
        file_map = compiler.compile(extensions, output)

        assert (output / "check.sh").exists()
        assert (output / "protect.sh").exists()

    def test_preserves_executable(self, extensions, tmp_path: Path, fixtures_dir: Path):
        # Make fixture hook executable
        hook = fixtures_dir / "sample-ext" / "hooks" / "check.sh"
        hook.chmod(hook.stat().st_mode | 0o111)

        compiler = HooksCompiler()
        output = tmp_path / "hooks"
        compiler.compile(extensions, output)

        dest = output / "check.sh"
        assert dest.stat().st_mode & 0o111


class TestRoutingCompiler:
    def test_generates_routing_md(self, extensions, tmp_path: Path):
        compiler = RoutingCompiler()
        output = tmp_path / "rules"
        file_map = compiler.compile(extensions, output)

        routing_file = output / "30-routing.md"
        assert routing_file.exists()
        content = routing_file.read_text()
        assert "test trigger" in content
        assert "my-skill" in content
        assert "other trigger" in content
        assert "other-skill" in content
        assert "rules/30-routing.md" in file_map

    def test_no_routing_entries(self, tmp_path: Path):
        from claude_ext.models import ExtensionManifest

        exts = [(tmp_path, ExtensionManifest(name="empty-ext"))]
        compiler = RoutingCompiler()
        output = tmp_path / "rules"
        file_map = compiler.compile(exts, output)
        assert file_map == {}


class TestClaudeMdCompiler:
    def test_generates_with_template(self, extensions, tmp_path: Path):
        template = tmp_path / "template.md.tmpl"
        template.write_text("# Header\n\n{extension_sections}\n\n# Footer\n")

        output = tmp_path / "CLAUDE.md"
        compiler = ClaudeMdCompiler()
        file_map = compiler.compile(extensions, output, template)

        assert output.exists()
        content = output.read_text()
        assert "# Header" in content
        assert "# Footer" in content
        assert "CLAUDE.md" in file_map

    def test_generates_without_template(self, extensions, tmp_path: Path):
        output = tmp_path / "CLAUDE.md"
        compiler = ClaudeMdCompiler()
        compiler.compile(extensions, output)

        assert output.exists()


class TestSettingsCompiler:
    def test_merges_settings(self, extensions, tmp_path: Path):
        base_dir = tmp_path / "base"
        base_dir.mkdir()

        local_settings = base_dir / "settings.local.json"
        with open(local_settings, "w") as f:
            json.dump(
                {
                    "env": {"X": "1"},
                    "permissions": {"allow": ["Bash"], "deny": []},
                },
                f,
            )

        output = base_dir / "settings.json"
        compiler = SettingsCompiler()
        compiler.compile(extensions, output, local_settings, base_dir)

        assert output.exists()
        with open(output) as f:
            settings = json.load(f)

        assert settings["env"]["X"] == "1"
        # sample-ext adds deny permission
        assert "Bash(rm -rf*)" in settings["permissions"]["deny"]
        # Hooks from extensions
        assert "PreToolUse" in settings["hooks"]

    def test_missing_local_settings(self, extensions, tmp_path: Path):
        output = tmp_path / "settings.json"
        compiler = SettingsCompiler()
        compiler.compile(extensions, output, tmp_path / "missing.json", tmp_path)

        assert output.exists()


class TestBuildManifestCompiler:
    def test_writes_manifest(self, tmp_path: Path):
        output = tmp_path / ".build-manifest.json"
        compiler = BuildManifestCompiler()
        compiler.compile(
            ["ext-a", "ext-b"],
            {"rules/10.md": "ext-a", "skills/x/SKILL.md": "ext-b"},
            output,
        )

        assert output.exists()
        with open(output) as f:
            data = json.load(f)

        assert "ext-a" in data["extensions"]
        assert data["files"]["rules/10.md"] == "ext-a"
        assert "built_at" in data

    def test_dry_run(self, tmp_path: Path):
        output = tmp_path / ".build-manifest.json"
        compiler = BuildManifestCompiler()
        compiler.compile(["ext-a"], {}, output, dry_run=True)
        assert not output.exists()
