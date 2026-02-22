#!/usr/bin/env python3
"""PreToolUse hook: Block dangerous git commands (force-push, reset --hard, etc.)."""
import json
import re
import shlex
import sys


# 危険なgitコマンドパターン
DENY_PATTERNS = [
    # Force push（全形式）
    (r"\bgit\s+push\s+.*--force\b", "git push --force は禁止です。--force-with-lease を使用してください。"),
    (r"\bgit\s+push\s+.*-f\b", "git push -f は禁止です。--force-with-lease を使用してください。"),
    (r"\bgit\s+push\s+.*\+[^\s]+:[^\s]+", "git push +refspec（force-push回避パターン）は禁止です。"),
    # 履歴破壊
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard は禁止です。git stash → git reset --soft を使用してください。"),
    # 全ファイル変更破棄
    (r"\bgit\s+checkout\s+\.\s*$", "git checkout . は禁止です。個別ファイルを指定してください。"),
    (r"\bgit\s+checkout\s+--\s+\.\s*$", "git checkout -- . は禁止です。個別ファイルを指定してください。"),
    (r"\bgit\s+restore\s+\.\s*$", "git restore . は禁止です。個別ファイルを指定してください。"),
    (r"\bgit\s+restore\s+--staged\s+\.\s*$", "git restore --staged . は禁止です。個別ファイルを指定してください。"),
    # 未追跡ファイル削除
    (r"\bgit\s+clean\s+-[dDfFxX]*f", "git clean -f は禁止です。git clean -n（ドライラン）で確認してください。"),
    # ブランチ強制削除
    (r"\bgit\s+branch\s+-D\b", "git branch -D は禁止です。git branch -d（マージ済みのみ）を使用してください。"),
    # 共有ブランチrebase
    (r"\bgit\s+rebase\s+.*\bmain\b", "main ブランチへの rebase は禁止です。git merge main を使用してください。"),
    (r"\bgit\s+rebase\s+.*\bmaster\b", "master ブランチへの rebase は禁止です。git merge master を使用してください。"),
    # 参照直接書き換え
    (r"\bgit\s+update-ref\b", "git update-ref は禁止です。通常のgitコマンドを使用してください。"),
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

    # gitコマンドでなければスキップ（高速パス）
    if "git " not in cmd and not cmd.strip().startswith("git"):
        return

    # 内部コマンドも検査（bash -c "git push --force" 対策）
    inner = extract_inner_command(cmd)
    candidates = {cmd.strip(), inner.strip()}

    # && や ; や | で繋がれた複数コマンドも検査
    for candidate in list(candidates):
        for part in re.split(r"[;&|]+", candidate):
            candidates.add(part.strip())

    for candidate in candidates:
        for pattern, message in DENY_PATTERNS:
            if re.search(pattern, candidate):
                deny(message)


if __name__ == "__main__":
    main()
