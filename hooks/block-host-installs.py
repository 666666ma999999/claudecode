#!/usr/bin/env python3
"""PreToolUse hook: Block host-level package installs. Force Docker usage."""
import json
import re
import shlex
import sys


DENY_PATTERNS = [
    r"\bpip3?\s+install\b",
    r"\bpython3?\s+-m\s+pip\s+install\b",
    r"\bpython3?\s+-m\s+venv\b",
    r"\bvirtualenv\b",
    r"\bnpm\s+(install|i|ci)\b",
    r"\byarn\s+(install|add)\b",
    r"\bpnpm\s+(install|add)\b",
    r"\bbun\s+(install|add)\b",
    r"\buv\s+(pip|venv)\b",
    r"\bpoetry\s+(install|add)\b",
    r"\bconda\s+(install|create)\b",
    r"\bsource\s+.*/?activate\b",
    r"\.\s+.*/?activate\b",
]

DOCKER_PREFIXES = (
    "docker compose exec",
    "docker compose run",
    "docker exec",
    "docker-compose exec",
    "docker-compose run",
    "docker run",
)

# Patterns that are explicitly allowed even if they match DENY_PATTERNS.
# Claude Code tool extensions (e.g. _build_tool) need host pip install -e.
ALLOW_PATTERNS = [
    r"\bpip3?\s+install\s+-e\s+.*[~/]\.claude/extensions/_build_tool\b",
    r"\bpython3?\s+-m\s+pip\s+install\s+-e\s+.*[~/]\.claude/extensions/_build_tool\b",
]


def deny(reason: str):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def extract_inner_command(cmd: str) -> str:
    """bash -lc '...' 等のラッパーから内部コマンドを抽出"""
    try:
        parts = shlex.split(cmd)
    except ValueError:
        return cmd
    if len(parts) >= 3 and parts[0] in ("bash", "zsh", "sh") and parts[1] in ("-c", "-lc"):
        return parts[2]
    return cmd


def main():
    data = json.load(sys.stdin)
    tool_name = data.get("tool_name", "")

    if tool_name != "Bash":
        return

    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd:
        return

    # Docker経由なら許可
    normalized = " ".join(cmd.strip().split())
    for prefix in DOCKER_PREFIXES:
        if normalized.startswith(prefix):
            return

    # 内部コマンドも検査（bash -c "pip install ..." 対策）
    inner = extract_inner_command(cmd)
    candidates = {cmd.strip(), inner.strip()}

    # && や ; で繋がれた複数コマンドも検査
    for candidate in list(candidates):
        for part in re.split(r"[;&|]+", candidate):
            candidates.add(part.strip())

    for candidate in candidates:
        # Check allow-list first: if ANY candidate matches an allow pattern, skip deny
        allowed = False
        for allow_pat in ALLOW_PATTERNS:
            if re.search(allow_pat, candidate):
                allowed = True
                break
        if allowed:
            continue

        for pattern in DENY_PATTERNS:
            if re.search(pattern, candidate):
                deny(
                    "ホスト環境でのパッケージインストール/venv作成は禁止されています。\n"
                    "Docker経由で実行してください:\n"
                    "  docker compose exec dev pip install ...\n"
                    "  docker compose exec dev npm install ...\n"
                    "  docker compose run --rm dev python -m venv .venv"
                )


if __name__ == "__main__":
    main()
