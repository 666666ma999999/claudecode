#!/usr/bin/env python3
"""PostToolUse hook: Check for cross-extension import violations."""
import ast
import json
import os
import sys
from typing import Optional, List


def warn(message: str):
    """Print warning to stderr."""
    print(message, file=sys.stderr)


def get_extension_name(file_path: str, cwd: str) -> Optional[str]:
    """Extract extension name from file path.

    e.g., /project/src/extensions/billing/service.py -> "billing"
    """
    rel = os.path.relpath(file_path, cwd)
    parts = rel.split(os.sep)
    # Look for src/extensions/<name>/...
    try:
        ext_idx = parts.index("extensions")
        if ext_idx > 0 and parts[ext_idx - 1] == "src" and ext_idx + 1 < len(parts):
            return parts[ext_idx + 1]
    except ValueError:
        pass
    return None


def check_imports(file_path: str, ext_name: str) -> List[str]:
    """Check a Python file for cross-extension imports."""
    violations = []
    try:
        source = open(file_path, "r", encoding="utf-8").read()
        tree = ast.parse(source)
    except (OSError, SyntaxError):
        return violations

    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module:
            if "extensions." in node.module:
                imported_ext = node.module.split("extensions.")[1].split(".")[0]
                if imported_ext != ext_name:
                    violations.append(
                        f"  Line {node.lineno}: from {node.module} import ... "
                        f"(ext '{ext_name}' imports from ext '{imported_ext}')"
                    )
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if "extensions." in alias.name:
                    imported_ext = alias.name.split("extensions.")[1].split(".")[0]
                    if imported_ext != ext_name:
                        violations.append(
                            f"  Line {node.lineno}: import {alias.name} "
                            f"(ext '{ext_name}' imports from ext '{imported_ext}')"
                        )
    return violations


def check_reverse_imports(file_path: str, cwd: str) -> List[str]:
    """Check if shared/ or core/ files import from extensions/."""
    violations = []
    rel = os.path.relpath(file_path, cwd)

    # Only check files in src/shared/ or src/core/
    if not (rel.startswith("src/shared/") or rel.startswith("src/core/")):
        return violations

    try:
        source = open(file_path, "r", encoding="utf-8").read()
        tree = ast.parse(source)
    except (OSError, SyntaxError):
        return violations

    location = "shared" if "shared" in rel else "core"

    for node in ast.walk(tree):
        module = None
        if isinstance(node, ast.ImportFrom) and node.module:
            module = node.module
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if "extensions." in alias.name:
                    module = alias.name
                    break

        if module and "extensions." in module:
            violations.append(
                f"  Line {node.lineno}: {location}/ が extensions/ を import しています: {module}"
            )

    return violations


def main():
    data = json.load(sys.stdin)
    tool_name = data.get("tool_name", "")

    if tool_name not in ("Write", "Edit"):
        return

    tool_input = data.get("tool_input") or {}
    file_path = tool_input.get("file_path", "")
    cwd = data.get("cwd", "")

    if not file_path or not cwd:
        return

    # Only check .py files
    if not file_path.endswith(".py"):
        return

    # Check if extension project
    be_marker = os.path.join(cwd, "config", "extensions.yaml")
    fe_marker = os.path.join(cwd, "config", "extensions.json")
    if not os.path.exists(be_marker) and not os.path.exists(fe_marker):
        return

    file_path = os.path.realpath(file_path)
    cwd = os.path.realpath(cwd)

    all_violations = []

    # Check cross-extension imports
    ext_name = get_extension_name(file_path, cwd)
    if ext_name:
        all_violations.extend(check_imports(file_path, ext_name))

    # Check reverse imports (shared/core -> extensions)
    all_violations.extend(check_reverse_imports(file_path, cwd))

    if all_violations:
        warn("⚠ エクステンション隔離違反を検出:")
        warn(f"  ファイル: {os.path.relpath(file_path, cwd)}")
        for v in all_violations:
            warn(v)
        warn("  → ext間の直接importは禁止です。EventBus を使用してください。")
        warn("  → 参照: be-extension-pattern スキル")


if __name__ == "__main__":
    main()
