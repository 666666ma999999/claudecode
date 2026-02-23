"""Settings compiler: merges settings.local.json with extension hooks/permissions."""

from __future__ import annotations

import json
from pathlib import Path

from ..models import ExtensionManifest, HookEvent


class SettingsCompiler:
    """Generates settings.json by merging settings.local.json with extension definitions."""

    def compile(
        self,
        extensions: list[tuple[Path, ExtensionManifest]],
        output_file: Path,
        local_settings_path: Path,
        base_dir: Path,
        dry_run: bool = False,
        content_map: dict[str, str] | None = None,
    ) -> dict[str, str]:
        """Generate settings.json.

        Process:
        1. Load settings.local.json as base (contains env, enabledPlugins, etc.)
        2. Merge extension hooks into hooks section
        3. Merge extension permissions into permissions section

        Args:
            extensions: Discovered extensions with manifests.
            output_file: Path to write settings.json.
            local_settings_path: Path to settings.local.json (base).
            base_dir: The ~/.claude directory (for resolving hook paths).
            dry_run: If True, do not write files.
            content_map: If provided, populated with rel_path -> content.

        Returns:
            Mapping of output_path (relative) -> "settings-compiler".
        """
        file_map: dict[str, str] = {}

        # Load base settings
        if local_settings_path.exists():
            with open(local_settings_path, "r", encoding="utf-8") as f:
                settings = json.load(f)
        else:
            settings = {}

        # Ensure structure
        settings.setdefault("permissions", {})
        settings["permissions"].setdefault("allow", [])
        settings["permissions"].setdefault("deny", [])

        # Merge permissions from extensions
        for _ext_dir, manifest in extensions:
            if manifest.permissions:
                for perm in manifest.permissions.get("allow", []):
                    if perm not in settings["permissions"]["allow"]:
                        settings["permissions"]["allow"].append(perm)
                for perm in manifest.permissions.get("deny", []):
                    if perm not in settings["permissions"]["deny"]:
                        settings["permissions"]["deny"].append(perm)

        # Build hooks section from extensions
        hooks: dict[str, list[dict]] = {}

        for ext_dir, manifest in extensions:
            for event, hook_defs in manifest.hooks.items():
                event_key = event.value
                hooks.setdefault(event_key, [])

                for hook_def in hook_defs:
                    # Use deployed path: hook_def.script (e.g. "hooks/foo.sh")
                    # is deployed to ~/.claude/hooks/foo.sh by the hooks/skills compiler.
                    command = f"~/.claude/{hook_def.script}"

                    hook_entry = {
                        "matcher": hook_def.matcher,
                        "hooks": [
                            {
                                "type": "command",
                                "command": command,
                            }
                        ],
                    }
                    hooks[event_key].append(hook_entry)

        # Merge hooks with any hooks already in settings.local.json
        if hooks:
            existing_hooks = settings.get("hooks", {})
            for event_key, new_entries in hooks.items():
                existing = existing_hooks.get(event_key, [])
                existing.extend(new_entries)
                existing_hooks[event_key] = existing
            settings["hooks"] = existing_hooks

        rel_dest = "settings.json"

        content = json.dumps(settings, indent=2, ensure_ascii=False) + "\n"

        if not dry_run:
            output_file.parent.mkdir(parents=True, exist_ok=True)
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(content)

        if content_map is not None:
            content_map[rel_dest] = content

        file_map[rel_dest] = "settings-compiler"
        return file_map
