#!/usr/bin/env python3
"""
PreToolUse hook for Claude Code that detects extension pattern violations.

This hook enforces the extension-based architecture pattern by warning or blocking
Write/Edit operations that violate the directory structure conventions.

Environment variables:
  CLAUDE_EXT_STRICT=1  Escalate warnings to DENY (block the operation)
"""
import json
import sys
import os


def deny(reason: str):
    """Block the tool execution with the given reason."""
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def warn(message: str):
    """Print warning to stderr and allow the operation."""
    print(message, file=sys.stderr)


def is_extension_project(cwd: str) -> tuple[bool, str]:
    """
    Check if the current working directory is an extension project.

    Returns:
        (is_extension_project, project_type) where project_type is "BE", "FE", or ""
    """
    be_marker = os.path.join(cwd, "config", "extensions.yaml")
    fe_marker = os.path.join(cwd, "config", "extensions.json")

    if os.path.exists(be_marker):
        return (True, "BE")
    elif os.path.exists(fe_marker):
        return (True, "FE")
    else:
        return (False, "")


def get_relative_path(file_path: str, cwd: str) -> str:
    """
    Convert file_path to a path relative to cwd.

    Handles both absolute and relative paths correctly.
    """
    # Normalize paths
    file_path = os.path.normpath(file_path)
    cwd = os.path.normpath(cwd)

    # If already relative, return as-is
    if not os.path.isabs(file_path):
        return file_path

    # Convert absolute to relative
    try:
        rel_path = os.path.relpath(file_path, cwd)
        # Don't return paths that go up (../)
        if rel_path.startswith(".."):
            return file_path
        return rel_path
    except ValueError:
        # Different drives on Windows, return absolute
        return file_path


def check_violation(rel_path: str) -> tuple[bool, str]:
    """
    Check if the file path violates extension pattern conventions.

    Returns:
        (is_violation, warning_message)
    """
    # Normalize path separators
    rel_path = rel_path.replace("\\", "/")

    # Rule a: Warning for core/ modifications
    if rel_path.startswith("src/core/"):
        return (True, f"""⚠ core/ への変更を検出: {rel_path}
  → core/ の変更は慎重に。本当にcoreの変更が必要ですか？
  → 新機能の場合: src/extensions/<name>/ にエクステンションとして作成してください
  → 参照: be-extension-pattern スキル""")

    # Rule b: Files in src/ should be in extensions/, core/, shared/, or be app.py/main.py
    if rel_path.startswith("src/"):
        # Allowed patterns
        allowed_patterns = [
            "src/extensions/",
            "src/core/",
            "src/shared/",
            "src/app.py",
            "src/main.py",
        ]

        if not any(rel_path.startswith(pattern) for pattern in allowed_patterns):
            return (True, f"""⚠ extensions/ 外への配置を検出: {rel_path}
  → src/extensions/<name>/ 配下に配置してください
  → エクステンション構造: __init__.py (manifest), router.py, service.py, tests/
  → 参照: be-extension-pattern スキル""")

    # No violation
    return (False, "")


def main():
    try:
        # Read hook input
        data = json.load(sys.stdin)

        tool_name = data.get("tool_name", "")

        # Only process Write or Edit tools
        if tool_name not in ["Write", "Edit"]:
            sys.exit(0)

        # Get CWD
        cwd = data.get("cwd", os.getcwd())

        # Check if this is an extension project
        is_ext_project, project_type = is_extension_project(cwd)
        if not is_ext_project:
            # Not an extension project, skip validation
            sys.exit(0)

        # Get file_path from tool_input
        tool_input = data.get("tool_input", {})
        file_path = tool_input.get("file_path")

        if not file_path:
            # No file_path in tool_input, nothing to check
            sys.exit(0)

        # Make path relative to CWD
        rel_path = get_relative_path(file_path, cwd)

        # Check for violations
        is_violation, warning_message = check_violation(rel_path)

        if not is_violation:
            # No violation, allow
            sys.exit(0)

        # Check strict mode
        strict_mode = os.environ.get("CLAUDE_EXT_STRICT", "0") == "1"

        if strict_mode:
            # Strict mode: DENY the operation
            deny(f"""{warning_message}

プロジェクト: {project_type}

Strict mode is enabled (CLAUDE_EXT_STRICT=1). This operation is blocked.""")
        else:
            # Default mode: WARN only
            warn(f"\n{warning_message}\n\nプロジェクト: {project_type}\n")
            sys.exit(0)

    except Exception as e:
        # Log error to stderr but don't block operation
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
