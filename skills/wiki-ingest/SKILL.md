---
name: wiki-ingest
description: "Ingest sources (files, URLs, batch) into the Obsidian wiki vault: create/update wiki pages, cross-reference, log. Triggers: ingest, process this source, add this to the wiki, read and file this, batch ingest, ingest all of these, ingest this url."
---

# wiki-ingest: Source Ingestion

## 発火・詳細（description から移設 2026-07-03）

Ingest sources into the Obsidian wiki vault. Reads a source, extracts entities and concepts, creates or updates wiki pages, cross-references, and logs the operation. Supports files, URLs, and batch mode.

Read the source. Write the wiki. Cross-reference everything. A single source typically touches 8-15 wiki pages.

**Syntax standard**: Write all Obsidian Markdown using proper Obsidian Flavored Markdown. Wikilinks as `[[Note Name]]`, callouts as `> [!type] Title`, embeds as `![[file]]`, properties as YAML frontmatter. If the kepano/obsidian-skills plugin is installed, prefer its canonical obsidian-markdown skill for Obsidian syntax reference. Otherwise, follow the guidance in this skill.

---

## Delta Tracking

Before ingesting any file, check `.raw/.manifest.json` to avoid re-processing unchanged sources.

```bash
# Check if manifest exists
[ -f .raw/.manifest.json ] && echo "exists" || echo "no manifest yet"
```

**Manifest format** (create if missing):
```json
{
  "sources": {
    ".raw/articles/article-slug-2026-04-08.md": {
      "hash": "abc123",
      "ingested_at": "2026-04-08",
      "pages_created": ["wiki/sources/article-slug.md", "wiki/entities/Person.md"],
      "pages_updated": ["wiki/index.md"]
    }
  }
}
```

**Before ingesting a file:**
1. Compute a hash: `md5sum [file] | cut -d' ' -f1` (or `sha256sum` on Linux).
2. Check if the path exists in `.manifest.json` with the same hash.
3. If hash matches, skip. Report: "Already ingested (unchanged). Use `force` to re-ingest."
4. If missing or hash differs, proceed with ingest.

**After ingesting a file:**
1. Record `{hash, ingested_at, pages_created, pages_updated}` in `.manifest.json`.
2. Write the updated manifest back.

Skip delta checking if the user says "force ingest" or "re-ingest".

---

## URL Ingestion

Trigger: user passes a URL starting with `https://`.

Steps:

1. **Fetch** the page using WebFetch.
2. **Clean** (optional): if `defuddle` is available (`which defuddle 2>/dev/null`), run `defuddle [url]` to strip ads, nav, and clutter. Typically saves 40-60% tokens. Fall back to raw WebFetch output if not installed.
3. **Derive slug** from the URL path (last segment, lowercased, spaces→hyphens, strip query strings).
4. **Save** to `.raw/articles/[slug]-[YYYY-MM-DD].md` with a frontmatter header:
   ```markdown
   ---
   source_url: [url]
   fetched: [YYYY-MM-DD]
   ---
   ```
5. Proceed with **Single Source Ingest** starting at step 2 (file is now in `.raw/`).

---

## Image / Vision Ingestion

Trigger: user passes an image file path (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`, `.avif`).

Steps:

1. **Read** the image file using the Read tool. Claude can process images natively.
2. **Describe** the image contents: extract all text (OCR), identify key concepts, entities, diagrams, and data visible in the image.
3. **Save** the description to `.raw/images/[slug]-[YYYY-MM-DD].md`:
   ```markdown
   ---
   source_type: image
   original_file: [original path]
   fetched: YYYY-MM-DD
   ---
   # Image: [slug]

   [Full description of image contents, transcribed text, entities visible, etc.]
   ```
4. Copy the image to `_attachments/images/[slug].[ext]` if it's not already in the vault.
5. Proceed with **Single Source Ingest** on the saved description file.

Use cases: whiteboard photos, screenshots, diagrams, infographics, document scans.

---

## Single Source Ingest

Trigger: user drops a file into `.raw/` or pastes content.

Steps:

1. **Read** the source completely. Do not skim.
2. **Discuss** key takeaways with the user. Ask: "What should I emphasize? How granular?" Skip this if the user says "just ingest it."
3. **Create** source summary in `wiki/sources/`. Use the source frontmatter schema from `skills/wiki/references/frontmatter.md` (the `### source` section). Assign an address per the **Address Assignment** section below.
4. **Create or update** entity pages for every person, org, product, and repo mentioned. One page per entity. Assign addresses to new entity pages.
5. **Create or update** concept pages for significant ideas and frameworks. Assign addresses to new concept pages.
6. **Update** relevant domain page(s) and their `_index.md` sub-indexes.
7. **Update** `wiki/overview.md` if the big picture changed.
8. **Update** `wiki/index.md`. Add entries for all new pages.
9. **Update** `wiki/hot.md` with this ingest's context.
10. **Append** to `wiki/log.md` (new entries at the TOP):
    ```markdown
    ## [YYYY-MM-DD] ingest | Source Title
    - Source: `.raw/articles/filename.md`
    - Summary: [[Source Title]]
    - Pages created: [[Page 1]], [[Page 2]]
    - Pages updated: [[Page 3]], [[Page 4]]
    - Key insight: One sentence on what is new.
    ```
11. **Check for contradictions.** If new info conflicts with existing pages, add `> [!contradiction]` callouts on both pages.

---

## Chain Update（「育つ」＝取り込みで既存知識も更新する）

新規ページを作って終わりにしない。知識は既存とつながって初めて育つ:

- **相互リンク（関連が実在する場合のみ）**: 新規ページに関連する既存ページを最大 3〜5 枚選び、双方向にリンクする。**各リンクに「なぜ関連するか」の根拠を 1 行必ず添える**。
- **`## Updates` 追記**: 既存ページ側には `## Updates` セクションへ `### YYYY-MM-DD` 見出しで差分を追記する（rules/40 訂正プロトコル準拠・**本文は書き換えない・取消線禁止**）。
- **関連が無ければ更新 0 を許容**: 母数が少ない段階で無理にリンクを張らない。**無理リンク・薄い `## Updates` の量産は禁止**（質 > 量）。
- **記録**: 取り込み完了時に `wiki/log.md` へ 1 行 append（上記 Single Source Ingest step 10 の log エントリに、更新した既存ページを必ず含める）。
- **✅ キュー経由の後始末**: `wiki/meta/wiki-ingest-queue.md` の✅（`- [x]`）を処理したら、完了後にその項目をキューから削除する（SessionStart の「未処理✅ N件」通知の N を減らす）。

---

## Batch Ingest

Trigger: user drops multiple files or says "ingest all of these."

Steps:

1. List all files to process. Confirm with user before starting.
2. Process each source following the single ingest flow. Defer cross-referencing between sources until step 3.
3. After all sources: do a cross-reference pass. Look for connections between the newly ingested sources.
4. Update index, hot cache, and log once at the end (not per-source).
5. Report: "Processed N sources. Created X pages, updated Y pages. Here are the key connections I found."

Batch ingest is less interactive. For 30+ sources, expect significant processing time. Check in with the user after every 10 sources.

---

## Context Window Discipline

Token budget matters. Follow these rules during ingest:

- Read `wiki/hot.md` first. If it contains the relevant context, don't re-read full pages.
- Read `wiki/index.md` to find existing pages before creating new ones.
- Read only 3-5 existing pages per ingest. If you need 10+, you are reading too broadly.
- Use PATCH for surgical edits. Never re-read an entire file just to update one field.
- Keep wiki pages short. 100-300 lines max. If a page grows beyond 300 lines, split it.
- Use search (`/search/simple/`) to find specific content without reading full pages.

---

## Contradictions

> [!note] Custom callout dependency
> The `[!contradiction]` callout type used below is a **custom callout** defined in `.obsidian/snippets/vault-colors.css` (auto-installed by `/wiki` scaffold). It renders with reddish-brown styling and an alert-triangle icon when the snippet is enabled. If the snippet is missing, Obsidian falls back to default callout styling, so the page still works without the visual flourish. See [[skills/wiki/references/css-snippets.md]] for the four custom callouts (`contradiction`, `gap`, `key-insight`, `stale`).

When new info contradicts an existing wiki page:

On the existing page, add:
```markdown
> [!contradiction] Conflict with [[New Source]]
> [[Existing Page]] claims X. [[New Source]] says Y.
> Needs resolution. Check dates, context, and primary sources.
```

On the new source summary, reference it:
```markdown
> [!contradiction] Contradicts [[Existing Page]]
> This source says Y, but existing wiki says X. See [[Existing Page]] for details.
```

Do not silently overwrite old claims. Flag and let the user decide.

---

## What Not to Do

- **Source files under `.raw/` are immutable.** Do not modify the files that users drop there (articles, transcripts, images). The `.raw/.manifest.json` delta tracker and its `address_map` (DragonScale Mechanism 2) are the only files under `.raw/` that `wiki-ingest` itself maintains. Treat every other file under `.raw/` as read-only source content.
- Do not create duplicate pages. Always check the index and search before creating.
- Do not skip the log entry. Every ingest must be recorded.
- Do not skip the hot cache update. It is what keeps future sessions fast.

---

## Address Assignment (DragonScale Mechanism 2, opt-in)

DragonScale 採用時のみ。`scripts/allocate-address.sh` で各ページに hierarchical address を付与。詳細手順・モード・冪等性ルール・並行性ポリシーは `references/address-assignment.md` を参照。
