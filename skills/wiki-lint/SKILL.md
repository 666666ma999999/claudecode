---
name: wiki-lint
description: >
  Obsidian wiki vault health check (orphans, dead links, stale claims, frontmatter gaps,
  Dataview dashboard, canvas map). Triggers: lint, health check, clean up wiki,
  check the wiki, wiki maintenance, find orphans, wiki audit.
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# wiki-lint: Wiki Health Check

## 発火・詳細（description から移設 2026-07-03）

Health check the Obsidian wiki vault. Finds orphan pages, dead wikilinks, stale claims, missing cross-references, frontmatter gaps, and empty sections. Creates or updates Dataview dashboards. Generates canvas maps. Triggers on: "lint", "health check", "clean up wiki", "check the wiki", "wiki maintenance", "find orphans", "wiki audit".

Run lint after every 10-15 ingests, or weekly. Ask before auto-fixing anything. Output a lint report to `wiki/meta/lint-report-YYYY-MM-DD.md`.

---

## Lint Checks

Work through these in order:

1. **Orphan pages**. Wiki pages with no inbound wikilinks. They exist but nothing points to them.
2. **Dead links**. Wikilinks that reference a page that does not exist.
3. **Stale claims**. Assertions on older pages that newer sources have contradicted or updated.
4. **Missing pages**. Concepts or entities mentioned in multiple pages but lacking their own page.
5. **Missing cross-references**. Entities mentioned in a page but not linked.
6. **Frontmatter gaps**. Pages missing required fields (type, status, created, updated, tags).
7. **Empty sections**. Headings with no content underneath.
8. **Stale index entries**. Items in `wiki/index.md` pointing to renamed or deleted pages.
9. **Address validity** (DragonScale Mechanism 2). For every page that has an `address:` frontmatter field, validate the format. See the **Address Validation** section below.
10. **Semantic tiling** (DragonScale Mechanism 3, opt-in). Flag candidate duplicate pages (across all scanned types, not just concepts) via embedding cosine similarity. See the **Semantic Tiling** section below.

---

## Lint Report Format

Create at `wiki/meta/lint-report-YYYY-MM-DD.md`:

```markdown
---
type: meta
title: "Lint Report YYYY-MM-DD"
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [meta, lint]
status: developing
---

# Lint Report: YYYY-MM-DD

## Summary
- Pages scanned: N
- Issues found: N
- Auto-fixed: N
- Needs review: N

## Orphan Pages
- [[Page Name]]: no inbound links. Suggest: link from [[Related Page]] or delete.

## Dead Links
- [[Missing Page]]: referenced in [[Source Page]] but does not exist. Suggest: create stub or remove link.

## Missing Pages
- "concept name": mentioned in [[Page A]], [[Page B]], [[Page C]]. Suggest: create a concept page.

## Frontmatter Gaps
- [[Page Name]]: missing fields: status, tags

## Stale Claims
- [[Page Name]]: claim "X" may conflict with newer source [[Newer Source]].

## Cross-Reference Gaps
- [[Entity Name]] mentioned in [[Page A]] without a wikilink.
```

---

## Naming Conventions

Enforce these during lint:

| Element | Convention | Example |
|---------|-----------|---------|
| Filenames | Title Case with spaces | `Machine Learning.md` |
| Folders | lowercase with dashes | `wiki/data-models/` |
| Tags | lowercase, hierarchical | `#domain/architecture` |
| Wikilinks | match filename exactly | `[[Machine Learning]]` |

Filenames must be unique across the vault. Wikilinks work without paths only if filenames are unique.

---

## Writing Style Check

During lint, flag pages that violate the style guide:

- Not declarative present tense ("X basically does Y" instead of "X does Y")
- Missing source citations where claims are made
- Uncertainty not flagged with `> [!gap]`
- Contradictions not flagged with `> [!contradiction]`

---

## Dataview Dashboard

Create or update `wiki/meta/dashboard.md` with these queries:

````markdown
---
type: meta
title: "Dashboard"
updated: YYYY-MM-DD
---
# Wiki Dashboard

## Recent Activity
```dataview
TABLE type, status, updated FROM "wiki" SORT updated DESC LIMIT 15
```

## Seed Pages (Need Development)
```dataview
LIST FROM "wiki" WHERE status = "seed" SORT updated ASC
```

## Entities Missing Sources
```dataview
LIST FROM "wiki/entities" WHERE !sources OR length(sources) = 0
```

## Open Questions
```dataview
LIST FROM "wiki/questions" WHERE answer_quality = "draft" SORT created DESC
```
````

---

## Canvas Map

Create or update `wiki/meta/overview.canvas` for a visual domain map:

```json
{
  "nodes": [
    {
      "id": "1",
      "type": "file",
      "file": "wiki/overview.md",
      "x": 0, "y": 0,
      "width": 300, "height": 140,
      "color": "1"
    }
  ],
  "edges": []
}
```

Add one node per domain page. Connect domains that have significant cross-references. Colors map to the CSS scheme: 1=blue, 2=purple, 3=yellow, 4=orange, 5=green, 6=red.

---

## Address Validation (DragonScale Mechanism 2, opt-in)

DragonScale 採用時のみ有効。詳細は `references/address-validation.md` を参照。

## Semantic Tiling (DragonScale Mechanism 3, opt-in)

ベクトル類似による近接ページ検出。詳細は `references/semantic-tiling.md` を参照。

---

## Before Auto-Fixing

Always show the lint report first. Ask: "Should I fix these automatically, or do you want to review each one?"

Safe to auto-fix:
- Adding missing frontmatter fields with placeholder values
- Creating stub pages for missing entities
- Adding wikilinks for unlinked mentions

Needs review before fixing:
- Deleting orphan pages (they might be intentionally isolated)
- Resolving contradictions (requires human judgment)
- Merging duplicate pages
