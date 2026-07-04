---
name: gog-cli
description: |
  Google Workspace を CLI `gog` で操作。WebFetch 不可→即 gog。トリガー: Google Sheets,スプレッドシート,Google Docs,ドキュメント,Google Slides,スライド,Google Drive,docs.google.com/{spreadsheets,document,presentation}/,drive.google.com/{file,drive/folders}/,Gmail検索・送信・ラベル,Google Calendar予定確認・作成,Tasks,Contacts,Classroom,Chat
allowed-tools: [Read, Glob, Grep, Bash]
---

# gogcli (gog) CLI

## 発火・詳細（description から移設 2026-07-03）

Google Workspace（Gmail / Calendar / Drive / Docs / Sheets / Slides）を CLI (`gog`) で操作するスキル。
以下に該当する場合は WebFetch を使わず、必ずこのスキルを先に起動すること:
- Google Sheets / スプレッドシート / `docs.google.com/spreadsheets/` を含むURLの読み書き
- Google Docs / ドキュメント / `docs.google.com/document/` のエクスポート・読取
- Google Slides / スライド / `docs.google.com/presentation/` のエクスポート
- Google Drive / `drive.google.com/file/` `drive.google.com/drive/folders/` のダウンロード・一覧
- Gmail 検索・送信・ラベル操作、Google Calendar 予定確認・作成
- Tasks / Contacts / Classroom / Chat 等の Google Workspace 操作
WebFetch では認証が通らず中身が読めないため、URL検出時は即 `gog` コマンドへ切替える。

A fast, script-friendly CLI for Google Workspace services with JSON-first output and multi-account support.

**Repository**: https://github.com/steipete/gogcli

## Prerequisites

This skill assumes `gog` is installed and authorised. If commands fail with authentication errors, inform the user they need to:
1. **Install gog**: `brew install steipete/tap/gogcli`
2. **Store OAuth credentials**: `gog auth credentials <path-to-credentials.json>`
3. **Add account**: `gog auth add user@gmail.com --services all`

Do not attempt to resolve authentication issues automatically. Provide the user with the relevant command and let them handle it.

## Supported Services

Gmail, Calendar, Drive, Docs, Sheets, Slides, Chat (Workspace), Classroom, Contacts, Tasks, People, Groups (Workspace), Keep (Workspace, service account only).

## Quick Reference

### Global Flags

```bash
--account <email>    # Select account
--client <name>      # Select OAuth client
--json               # JSON output
--plain              # TSV output (for scripting)
--force              # Skip confirmations
--no-input           # Fail instead of prompting
```

### Common Patterns

```bash
gog --account work@example.com gmail search "is:unread"  # Use specific account
gog gmail search "is:unread" --json | jq '.threads[].id' # JSON for parsing
gog gmail search "is:unread" --plain | cut -f1           # Plain for shell
gog gmail search "is:unread" --max 10 --page <token>     # Pagination
```

## 個別サービス (Gmail / Calendar / Drive / Docs / Sheets / Slides / Tasks / Contacts / Classroom)

各サービスのコマンド詳細・引数・例は `references/gmail.md` / `calendar.md` / `drive-docs.md` / `other-services.md` (Tasks/Contacts/Classroom 含む) を参照。

## Configuration

### Config Locations

- **macOS**: `~/Library/Application Support/gogcli/config.json`
- **Linux**: `~/.config/gogcli/config.json`
- **Windows**: `%AppData%\gogcli\config.json`

### Settings

```bash
gog config set default_timezone America/New_York
gog config set default_account user@gmail.com
gog config list
```

### Environment Variables

```bash
GOG_ACCOUNT=user@gmail.com      # Default account
GOG_CLIENT=work                 # OAuth client
GOG_JSON=1                      # Default JSON output
GOG_PLAIN=1                     # Default plain output
GOG_TIMEZONE=America/New_York   # Display timezone
GOG_ENABLE_COMMANDS=calendar,tasks  # Command allowlist
```

For full configuration, see `references/configuration.md`.

## Multi-Account Usage

```bash
gog --account work@example.com gmail search "is:unread"
gog auth alias set work work@example.com
gog --account work gmail search "is:unread"
gog auth list --check
```

For authentication including service accounts, see `references/authentication.md`.

## Scripting

```bash
# JSON processing
gog gmail search "is:unread" --json | jq -r '.threads[].id'

# Batch operations
gog gmail search "older_than:30d" --json | \
  jq -r '.threads[].id' | \
  xargs -I {} gog gmail thread modify {} --add Archive --remove INBOX

# Non-interactive
gog gmail send --to user@example.com --subject "Test" --body "Hi" --force
```

## Troubleshooting

If commands fail, inform the user of the likely cause:

| Error | Cause | Solution |
|-------|-------|----------|
| `no credentials` | OAuth not configured | `gog auth credentials <file>` |
| `token expired` | Auth invalid | `gog auth add <email> --force-consent` |
| `insufficient scope` | Missing permissions | `gog auth add <email> --services <services>` |
| `command not found` | Not installed | `brew install steipete/tap/gogcli` |

Status checks:
```bash
gog auth list --check
gog auth status
```

## Reference Files

- `references/setup-guide.md` - **Setup: OAuth credentials, multi-PC sharing, troubleshooting**
- `references/command-reference.md` - Complete command specification
- `references/authentication.md` - Auth, credentials, multi-account
- `references/configuration.md` - Config and environment variables
- `references/gmail.md` - Gmail operations
- `references/calendar.md` - Calendar operations
- `references/drive-docs.md` - Drive, Docs, Sheets, Slides
- `references/other-services.md` - Classroom, Chat, Contacts, Tasks, People, Groups, Keep
