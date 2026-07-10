---
name: obsidian-cli
description: >-
  Obsidian CLI で vault のノートを read/create/search/管理し、プラグイン/テーマ開発(reload, JS実行, screenshot, DOM検査)も行う。
  トリガー: obsidian-skills を使って, obsidian CLI, Obsidian プラグイン開発, DOM を調べて（ユーザーが obsidian-cli を明示指名した場合のみ・rules/40-obsidian.md「obsidian-cli ガード」準拠）。
  NOT for: /save /canvas /autoresearch /wiki-ingest 等 workflow skill からの自動委譲（禁止）, 一般の vault 書き込み（正系は wiki-ingest / save / canvas）
allowed-tools: [Bash, Read]
---

# Obsidian CLI

## 発火・詳細（description から移設 2026-07-03）

Interact with Obsidian vaults via the Obsidian CLI to read, create, search, and manage notes, plus plugin/theme development (reload plugins, run JS, screenshots, inspect DOM). Use for vault CLI operations or Obsidian plugin debugging. Triggers (kepano bundle): 「obsidian-skills を使って」「obsidian CLI」「Obsidian プラグイン開発」「DOM を調べて」（ユーザー明示指名時のみ・rules/40-obsidian.md「obsidian-cli ガード」準拠。workflow skill からの自動委譲は禁止）.

Use the `obsidian` CLI to interact with a running Obsidian instance. Requires Obsidian to be open **and** the CLI installed: run `command -v obsidian` first — if not found, install the command line tool per https://help.obsidian.md/cli (Obsidian 1.12+) before proceeding (2026-07-04 時点で本マシンは未インストール).

## Command reference

Run `obsidian help` to see all available commands. This is always up to date. Full docs: https://help.obsidian.md/cli

## Syntax

**Parameters** take a value with `=`. Quote values with spaces:

```bash
obsidian create name="My Note" content="Hello world"
```

**Flags** are boolean switches with no value:

```bash
obsidian create name="My Note" silent overwrite
```

For multiline content use `\n` for newline and `\t` for tab.

## File targeting

Many commands accept `file` or `path` to target a file. Without either, the active file is used.

- `file=<name>` — resolves like a wikilink (name only, no path or extension needed)
- `path=<path>` — exact path from vault root, e.g. `folder/note.md`

## Vault targeting

Commands target the most recently focused vault by default. Use `vault=<name>` as the first parameter to target a specific vault:

```bash
obsidian vault="My Vault" search query="test"
```

## Common patterns

```bash
obsidian read file="My Note"
obsidian create name="New Note" content="# Hello" template="Template" silent
obsidian append file="My Note" content="New line"
obsidian search query="search term" limit=10
obsidian daily:read
obsidian daily:append content="- [ ] New task"
obsidian property:set name="status" value="done" file="My Note"
obsidian tasks daily todo
obsidian tags sort=count counts
obsidian backlinks file="My Note"
```

Use `--copy` on any command to copy output to clipboard. Use `silent` to prevent files from opening. Use `total` on list commands to get a count.

## Plugin development

### Develop/test cycle

After making code changes to a plugin or theme, follow this workflow:

1. **Reload** the plugin to pick up changes:
   ```bash
   obsidian plugin:reload id=my-plugin
   ```
2. **Check for errors** — if errors appear, fix and repeat from step 1:
   ```bash
   obsidian dev:errors
   ```
3. **Verify visually** with a screenshot or DOM inspection:
   ```bash
   obsidian dev:screenshot path=screenshot.png
   obsidian dev:dom selector=".workspace-leaf" text
   ```
4. **Check console output** for warnings or unexpected logs:
   ```bash
   obsidian dev:console level=error
   ```

### Additional developer commands

Run JavaScript in the app context:

```bash
obsidian eval code="app.vault.getFiles().length"
```

Inspect CSS values:

```bash
obsidian dev:css selector=".workspace-leaf" prop=background-color
```

Toggle mobile emulation:

```bash
obsidian dev:mobile on
```

Run `obsidian help` to see additional developer commands including CDP and debugger controls.
