## SCAFFOLD Operation

Trigger: user describes what the vault is for.

Steps:

1. Determine the wiki mode. Read `references/modes.md` to show the 6 options and pick the best fit.
2. Ask: "What is this vault for?" (one question, then proceed).
3. Create full folder structure under `wiki/` based on the mode.
4. Create domain pages + `_index.md` sub-indexes.
5. Create `wiki/index.md`, `wiki/log.md`, `wiki/hot.md`, `wiki/overview.md`.
6. Create `_templates/` files for each note type.
7. Apply visual customization. Read `references/css-snippets.md`. Create `.obsidian/snippets/vault-colors.css`.
8. Create the vault CLAUDE.md using the template below.
9. Initialize git. Read `references/git-setup.md`.
10. Present the structure and ask: "Want to adjust anything before we start?"

### Vault CLAUDE.md Template

Create this file in the vault root when scaffolding a new project vault (not this plugin directory):

```markdown
# [WIKI NAME]: LLM Wiki

Mode: [MODE A/B/C/D/E/F]
Purpose: [ONE SENTENCE]
Owner: [NAME]
Created: YYYY-MM-DD

## Structure

[PASTE THE FOLDER MAP FROM THE CHOSEN MODE]

## Conventions

- All notes use YAML frontmatter: type, status, created, updated, tags (minimum)
- Wikilinks use [[Note Name]] format: filenames are unique, no paths needed
- .raw/ contains source documents: never modify them
- wiki/index.md is the master catalog: update on every ingest
- wiki/log.md is append-only: never edit past entries
- New log entries go at the TOP of the file

## Operations

- Ingest: drop source in .raw/, say "ingest [filename]"
- Query: ask any question: Claude reads index first, then drills in
- Lint: say "lint the wiki" to run a health check
- Archive: move cold sources to .archive/ to keep .raw/ clean
```

---

