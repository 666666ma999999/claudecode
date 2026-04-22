#!/usr/bin/env python3
"""
PreToolUse hook: 素Playwright (mcp__playwright__*) からの社内ドメインアクセスを物理遮断。

目的: permissions.allow の承認UIで誤って許可を押しても、hookのdeny は承認UIが出ないため
      物理的にバイパスできない（多層防御の補助層）。

対象ツール: mcp__playwright__browser_navigate
           （playwright-mkb / plugin_playwright_playwright は検査対象外 = プロキシ付き前提）

検査内容: tool_input.url が社内ドメインパターンに一致したら deny

注意:
- 本hookは browser_navigate 単点防御。browser_evaluate や browser_tabs 経由の迂回は防げない
  → 本質的な保護は各プロジェクトの .mcp.json で playwright-mkb を使うこと
- 社内ドメインリストの更新漏れで無防備になるため、新規ドメイン追加時は本ファイルを更新すること

fail-closed 設計: 入力パース失敗・予期せぬ例外時は deny ではなく通す（fail-open）。
    理由: hook 障害で業務停止を避けたいため。本hookは第2防衛線であり、主防御は設定側で担保。
"""
import json
import re
import sys
from urllib.parse import urlparse

# 社内ドメインパターン（追加時はここに列挙）
CORPORATE_DOMAIN_PATTERNS = [
    r"\.mkb\.ne\.jp$",
    r"\.ura9\.com$",
]

# 検査対象ツール（素Playwrightのみ、プロキシ版は対象外）
GUARDED_TOOLS = {"mcp__playwright__browser_navigate"}


def is_corporate_url(url: str) -> bool:
    if not url:
        return False
    try:
        host = urlparse(url).hostname or ""
    except Exception:
        return False
    host = host.lower()
    for pattern in CORPORATE_DOMAIN_PATTERNS:
        if re.search(pattern, host):
            return True
    return False


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # パース不能は通す（fail-open）

    tool_name = data.get("tool_name", "")
    if tool_name not in GUARDED_TOOLS:
        return 0

    url = data.get("tool_input", {}).get("url", "")
    if not is_corporate_url(url):
        return 0

    decision = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"社内ドメイン '{url}' への素Playwright経由アクセスは禁止。"
                f"プロジェクトで playwright-mkb (MKBプロキシ版) を使ってください。"
                f"ドメインリスト: ~/.claude/hooks/playwright-proxy-guard.py"
            ),
        }
    }
    print(json.dumps(decision))
    return 0


if __name__ == "__main__":
    sys.exit(main())
