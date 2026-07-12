#!/usr/bin/env python3
"""block-host-installs.py の allow/deny 回帰テスト。

2026-07-10 誤検知修正（heredoc本文・検索コマンドのクォート内を照合除外）の検証。
実行: python3 ~/.claude/hooks/tests/test_block_host_installs.py
"""
import json
import subprocess
import sys
from pathlib import Path

HOOK = Path.home() / ".claude/hooks/block-host-installs.py"

# コマンド文字列はリテラル連結で組み立て（本テスト自身が hook に deny されないため）
INSTALL = "in" + "stall"
PIP_INSTALL = "pip " + INSTALL
NPM_INSTALL = "npm " + INSTALL


def run_hook(command: str) -> bool:
    """True = deny された / False = 素通り(allow)"""
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    r = subprocess.run(
        [sys.executable, str(HOOK)], input=payload, capture_output=True, text=True
    )
    if r.returncode != 0:
        raise RuntimeError(f"hook exited {r.returncode}: {r.stderr}")
    if not r.stdout.strip():
        return False
    out = json.loads(r.stdout)
    return out.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"


CASES = [
    # (説明, コマンド, 期待deny)
    # --- 誤検知修正の対象（allow になるべき） ---
    ("grep 引数内リテラル", f'grep -R "{NPM_INSTALL}" .', False),
    ("rg 引数内リテラル", f"rg '{PIP_INSTALL}' src/", False),
    ("git log --grep リテラル", f'git log --grep="{PIP_INSTALL}"', False),
    (
        "python heredoc 本文にリテラル",
        f"python3 - <<'PYEOF'\ntext = '{PIP_INSTALL} を含む文書'\nprint(text)\nPYEOF",
        False,
    ),
    (
        "python heredoc 本文に | 区切りの表",
        f"python3 - <<'EOF'\n# | {NPM_INSTALL} | 説明 |\nEOF",
        False,
    ),
    # --- 従来どおり deny を維持すべき（真陽性） ---
    ("素の pip install", f"{PIP_INSTALL} requests", True),
    ("素の npm install", f"{NPM_INSTALL} express", True),
    ("bash -c 内", f'bash -c "{PIP_INSTALL} x"', True),
    (
        "bash heredoc は本文が実行される",
        f"bash <<'EOF'\n{PIP_INSTALL} x\nEOF",
        True,
    ),
    ("echo リテラル→sh パイプ", f'echo "{PIP_INSTALL} x" | sh', True),
    ("pipe injection", f"ls && {NPM_INSTALL} evil", True),
    ("venv 作成", "python3 -m venv .venv", True),
    ("npx 一般パッケージ", "npx some-random-pkg", True),
    # --- 既存 allow の回帰確認 ---
    ("npx skills は許可", "npx skills find dashboards", False),
    ("docker 経由は許可", f"docker compose exec dev {PIP_INSTALL} requests", False),
    ("claude-code upgrade 形は許可(hook上)", f"{NPM_INSTALL} -g @anthropic-ai/claude-code@latest", False),
]


def main() -> int:
    failed = []
    for name, cmd, expect_deny in CASES:
        got = run_hook(cmd)
        mark = "OK " if got == expect_deny else "FAIL"
        if got != expect_deny:
            failed.append(name)
        print(f"[{mark}] {name}: expect_deny={expect_deny} got_deny={got}")
    print(f"\n{len(CASES) - len(failed)}/{len(CASES)} passed")
    if failed:
        print("FAILED:", ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
