#!/usr/bin/env python3
"""PreToolUse hook: Google Workspace URL を WebFetch で取得させず、gog CLI へ誘導する。

対象URL:
- docs.google.com/spreadsheets/  → gog sheets read
- docs.google.com/document/      → gog docs export / read
- docs.google.com/presentation/  → gog slides export
- drive.google.com/file/         → gog drive download
- drive.google.com/drive/folders → gog drive ls --parent <id>

WebFetch は認証を通せないため、Sheets は「タブ区切りテキスト」を返して中身が読めない。
ここで deny して理由文に具体的なコマンドを示すことで、Claude が次手で Bash + gog に切替える。
"""
import json
import re
import sys


WORKSPACE_PATTERNS = [
    (
        r"https?://docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)",
        "Google Sheets",
        'gog sheets read <spreadsheetId> "Sheet1!A:Z" --json\n'
        '（まず gog drive search でタイトル確認 or URL内のIDを直接使用）',
    ),
    (
        r"https?://docs\.google\.com/document/d/([a-zA-Z0-9_-]+)",
        "Google Docs",
        'gog docs export <documentId> --format md --out /tmp/doc.md\n'
        '（pdf/txt/html 等も --format で指定可）',
    ),
    (
        r"https?://docs\.google\.com/presentation/d/([a-zA-Z0-9_-]+)",
        "Google Slides",
        'gog slides export <presentationId> --format pdf --out /tmp/slides.pdf',
    ),
    (
        r"https?://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)",
        "Google Drive file",
        'gog drive download <fileId> --out /tmp/',
    ),
    (
        r"https?://drive\.google\.com/drive/folders/([a-zA-Z0-9_-]+)",
        "Google Drive folder",
        'gog drive ls --parent <folderId>',
    ),
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


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if data.get("tool_name", "") != "WebFetch":
        sys.exit(0)

    url = data.get("tool_input", {}).get("url", "")
    if not url:
        sys.exit(0)

    for pattern, service, example in WORKSPACE_PATTERNS:
        m = re.search(pattern, url)
        if not m:
            continue
        resource_id = m.group(1)
        reason = (
            f"{service} の URL を WebFetch で取得しようとしました（認証を通せず中身が読めません）。\n"
            f"代わりに `gog` CLI を使ってください（skill: gog-cli）。\n\n"
            f"例:\n  {example}\n\n"
            f"抽出したID: {resource_id}\n"
            f"未インストールなら: brew install steipete/tap/gogcli\n"
            f"認証エラーなら: gog auth add <email> --services all"
        )
        deny(reason)

    sys.exit(0)


if __name__ == "__main__":
    main()
