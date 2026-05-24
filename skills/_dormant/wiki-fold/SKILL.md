---
name: wiki-fold
description: "Rollup of wiki log entries into meta-pages. Reads the last 2^k entries from wiki/log.md and writes an idempotent fold page to wiki/folds/. Extractive only, no invention. Dry-run by default. Triggers on: fold the log, wiki-fold, log rollup."
---

# wiki-fold: Extractive Log Rollup

Implements a bounded subset of Mechanism 1 from [[DragonScale Memory]]: flat fold over raw `wiki/log.md` entries. Fold-of-folds (hierarchical level-stacking) is **out of scope for this skill**; see "Scope boundary" below.

A fold is **additive**: child log entries and their referenced pages are never modified, moved, or deleted. A fold is **extractive**: every outcome and theme in the output must be traceable to a specific child log entry. No invented facts, no synthesis beyond what the child entries support.

---

## Scope boundary (explicit)

This skill does **not** implement:
- Fold-of-folds / hierarchical level stacking (DragonScale spec calls for it; deferred to a future skill).
- Automatic triggering (folds are always human-invoked in Phase 1).
- Semantic-tiling dedup (Mechanism 3; separate skill).

It **does** implement:
- Flat fold over raw log.md entries at a chosen batch exponent `k`.
- Structural idempotency via a deterministic fold ID.
- Extractive summarization with count-checking.

When referring to level in frontmatter, use `batch_exponent: k` (not `level: k`), because this skill does not produce hierarchical levels.

---

## Modes

| Mode | Writes? | Invocation |
|---|---|---|
| **dry-run (default)** | **No Write tool calls.** Emit fold content via Bash `cat`/`heredoc` to stdout only. | `fold the log, dry-run k=3` |
| **commit** | Uses Write/Edit tools. Each Write fires the repo PostToolUse hook which auto-commits wiki changes. Accept this. Compose full content first, then sequence writes. | `fold the log, commit k=3` (only after a clean dry-run) |

**Why stdout-only in dry-run**: the repo's `hooks/hooks.json` PostToolUse hook fires on any `Write|Edit` and runs `git add wiki/ .raw/`. Writing to `/tmp` does not stage /tmp, but it still triggers the hook, which will commit *any pending wiki changes* under a generic message. Dry-run must leave zero residue. Bash stdout does not fire the hook.

---

## Deterministic fold ID

Every fold has an ID derived from its inputs:

```
fold-k{K}-from-{EARLIEST-DATE}-to-{LATEST-DATE}-n{COUNT}
```

Example: `fold-k3-from-2026-04-10-to-2026-04-23-n8`.

The filename in commit mode is `wiki/folds/{FOLD-ID}.md`. No date-of-creation in the filename. No timestamp in the title.

**Duplicate detection (required)**: before emitting any output, check if `wiki/folds/{FOLD-ID}.md` already exists. If so, report "Fold already exists at wiki/folds/{FOLD-ID}.md. Use --force to overwrite, or pick a different range." and stop. This is the no-op idempotency guarantee; byte-identical content is NOT guaranteed (LLM prose varies) but the filename and scope are.

---

## Parameters

- `k` (default 4): batch exponent. Batch size = `2^k`. Typical values: k=3 (8), k=4 (16), k=5 (32).
- `range` (optional): explicit entry range `entries 1-16`. Overrides k.
- `--force`: overwrite an existing fold with the same ID. Default no.
- `--commit`: write to wiki/. Without it, dry-run stdout-only.

If fewer than `2^k` log entries exist, report the shortfall and stop. Do not silently fold a partial batch.

---

## Procedure (6 steps)

詳細手順 (Parse → Extract → Read → Summarize → Self-check → Emit) は `references/procedure.md` を参照。

## Output schema

See `references/fold-template.md` for the canonical frontmatter and body layout.

---

## Invariants

1. **Structural idempotency**: same range + same k → same fold ID → duplicate detection prevents double-writes. LLM prose may vary across runs; the *location and scope* are fixed.
2. **Additive**: children are never modified.
3. **Bounded reads**: 0-15 child-page reads per fold.
4. **Extractive**: zero invented facts. Count checks enforced.
5. **No chaining**: wiki-fold does not invoke wiki-lint, wiki-ingest, autoresearch, or save.

---

## What NOT to do

- Do not use Write/Edit during dry-run. Bash stdout only.
- Do not include the current date in the fold filename or title. Use the child entry range.
- Do not silently dedupe children by page title. One record per log entry.
- Do not write "emergent themes" that span entries without naming which entries contribute.
- Do not claim byte-identical idempotency. Structural idempotency is the actual guarantee.
- Do not suppress or bypass the PostToolUse auto-commit hook.
- Do not update `wiki/hot.md`. Ownership stays with save/ingest skills.

---

## Reversal

Committed fold reversal (three commits, land in this order):
1. Remove the log.md fold entry.
2. Remove the index.md entry.
3. Delete the fold page file.

Or: `git revert` the three auto-commits. Child pages are untouched in either path.

---

## Example dry-run sequence

User: "fold the log, dry-run k=3"

1. Parse `wiki/log.md` top 8 entries.
2. Build structured children list (8 records).
3. Read 0-10 referenced pages as needed.
4. Produce fold ID: `fold-k3-from-2026-04-10-to-2026-04-23-n8`.
5. Check `wiki/folds/fold-k3-from-2026-04-10-to-2026-04-23-n8.md` does not exist.
6. Write fold body following the template.
7. Run self-check (frontmatter/table consistency, count verification).
8. Emit via `cat <<'EOF' ... EOF` to stdout.
9. Report: "Dry-run complete. Fold ID: {FOLD-ID}. To commit: 'commit the fold'."
