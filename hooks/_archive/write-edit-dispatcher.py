#!/usr/bin/env python3
"""
PreToolUse Write|Edit dispatcher.

Consolidates 8 separate hook entries into a single dispatcher to:
- Eliminate _profile-wrapper.sh perl-startup overhead (30-60ms x 6 = ~200ms)
- Reduce per-edit hook proliferation in settings.json
- Unify exit-code-2 (hard deny) and stdout-JSON-deny contracts

Order is preserved from the original settings.json:
  1. block-claude-mem-inject.sh
  2. prime-ad-drift-gate.sh
  3. plan-forbidden-block.sh
  4. verify-step-guard.sh
  5. enforce-extension-pattern.py
  6. file-protection.sh
  7. restrict-cwd-edits.sh
  8. memory-guard.sh

Behavior:
- stdin JSON is forwarded verbatim to each hook
- exit code 2 → immediately deny (forward stderr, exit 2)
- stdout containing a JSON with permissionDecision=deny → immediately deny
- otherwise forward stdout/stderr and continue to next hook
"""
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
HOOKS = [
    f"{HOME}/.claude/hooks/block-claude-mem-inject.sh",
    f"{HOME}/.claude/hooks/prime-ad-drift-gate.sh",
    f"{HOME}/.claude/hooks/plan-forbidden-block.sh",
    f"{HOME}/.claude/hooks/verify-step-guard.sh",
    f"{HOME}/.claude/hooks/enforce-extension-pattern.py",
    f"{HOME}/.claude/hooks/file-protection.sh",
    f"{HOME}/.claude/hooks/restrict-cwd-edits.sh",
    f"{HOME}/.claude/hooks/memory-guard.sh",
]

PER_HOOK_TIMEOUT = 10  # seconds


def is_deny_json(text: str) -> bool:
    """Check if stdout contains a hook deny JSON."""
    if not text or "permissionDecision" not in text:
        return False
    try:
        data = json.loads(text)
        return (
            data.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"
        )
    except (json.JSONDecodeError, AttributeError):
        return False


def main():
    stdin_data = sys.stdin.read()

    for hook in HOOKS:
        if not os.path.isfile(hook):
            continue

        try:
            result = subprocess.run(
                [hook],
                input=stdin_data,
                capture_output=True,
                text=True,
                timeout=PER_HOOK_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            sys.stderr.write(f"[dispatcher] timeout: {hook}\n")
            continue
        except Exception as e:
            sys.stderr.write(f"[dispatcher] error in {hook}: {e}\n")
            continue

        # Hard deny via exit code 2
        if result.returncode == 2:
            if result.stderr:
                sys.stderr.write(result.stderr)
            if result.stdout:
                sys.stdout.write(result.stdout)
            sys.exit(2)

        # Deny via stdout JSON (e.g., restrict-cwd-edits.sh)
        if is_deny_json(result.stdout):
            sys.stdout.write(result.stdout)
            if result.stderr:
                sys.stderr.write(result.stderr)
            sys.exit(0)

        # Pass-through stdout/stderr (warnings, info messages)
        if result.stdout:
            sys.stdout.write(result.stdout)
        if result.stderr:
            sys.stderr.write(result.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
