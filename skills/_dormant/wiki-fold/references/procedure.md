## Procedure

### 1. Parse log entries

```
grep -n "^## \[" wiki/log.md | head -{2^k}
```

Record for each entry: line number, date, operation, title, and the following bullet lines until the next `## [` or end-of-section.

### 2. Extract child page identifiers

From each entry's bullet list, extract:
- `Location: wiki/path/to/page.md` (the primary page)
- `[[Wikilinks]]` inline
- `Pages created:` and `Pages updated:` lists

Build a structured children list:
```yaml
children:
  - date: "2026-04-23"
    op: "save"
    title: "DragonScale Memory v0.2 — post-adversarial-review"
    page: "[[DragonScale Memory]]"
  - ...
```

One record per log entry. Do not dedupe by page: if two entries both point to `[[DragonScale Memory]]`, both records appear, distinguishable by date and title.

### 3. Read referenced pages (bounded)

Read only the pages that are not already captured fully in the log entry's bullets. Budget: 0-10 page reads. Hard ceiling: 15. If an entry's referenced page is missing, record `page_missing: true` and proceed.

### 4. Extractive summarization with count checks

Write the fold body per `references/fold-template.md`. **Rules**:

- **Extractive only.** Every outcome bullet and theme bullet must cite a specific child entry (e.g., `(from 2026-04-14 session)`) or a quoted line from that entry. Do not introduce events, counts, or interpretations not present in a child entry.
- **Log entry is the primary source.** If the log entry's bullets and the referenced meta-page disagree on a fact (e.g., a count), prefer the log-entry bullets and flag the mismatch as "source mismatch: log says X, meta says Y."
- **Count checks.** If you write "N concept pages" or "M repos updated," grep the source entries for the number and verify. Numeric mismatches are dry-run blockers.
- **No merging across entries without naming them.** A theme that spans multiple entries must name each contributing entry inline.
- **Uncertainty is a feature.** If an entry is ambiguous, say "ambiguous in source: [[Entry]]" rather than picking one interpretation.

### 5. Self-check before emitting

Before printing output, verify:
- Every child in `children:` frontmatter appears exactly once in the Child Entries table.
- Every entry in the table appears in the `children:` frontmatter.
- Every numeric claim in Key Outcomes is grep-verifiable against a child entry.
- The fold ID is deterministic and the file does not already exist (or `--force` is set).

If any check fails, abort and report the specific failure.

### 6. Emit

**Dry-run**: use Bash `cat <<'EOF' ... EOF` to stdout. Do not use Write. Print the fold ID and a one-line summary of what the commit step would do.

**Commit** (only after user says "commit the fold"):
1. `Write` the fold page to `wiki/folds/{FOLD-ID}.md`. (PostToolUse hook will auto-commit this.)
2. `Edit` `wiki/index.md` to add the fold link under a `## Folds` section (create section if missing). (Hook auto-commits.)
3. `Edit` `wiki/log.md` to prepend one entry:
   ```
   ## [YYYY-MM-DD] fold | batch-exponent-k{K} rollup of N entries
   - Location: wiki/folds/{FOLD-ID}.md
   - Range: {EARLIEST-DATE} to {LATEST-DATE}
   - Children: N log entries
   ```
   (Hook auto-commits.)

Three auto-commits result. The user sees three separate `wiki: auto-commit` entries in git log. This is expected; do not attempt to suppress the hook.

---

