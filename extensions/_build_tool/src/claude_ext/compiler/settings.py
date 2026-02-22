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
                    # Resolve script path relative to base_dir
                    script_path = ext_dir / hook_def.script
                    # Convert to ~/.claude/ relative path for settings.json
                    try:
                        rel_path = script_path.relative_to(base_dir)
                        command = f"~/.claude/{rel_path}"
                    except ValueError:
                        command = str(script_path)

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

        if not dry_run:
            output_file.parent.mkdir(parents=True, exist_ok=True)
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(settings, f, indent=2, ensure_ascii=False)
                f.write("\n")

        file_map[rel_dest] = "settings-compiler"
        return file_map
