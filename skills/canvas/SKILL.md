---
name: canvas
description: "Obsidian canvas操作(wiki視覚層・zone自動配置・/banana連携)。発火: /canvas, canvas new, canvas add image, canvas add text, canvas add pdf, canvas add note, canvas zone, canvas list, canvas from banana, add to canvas, put this on the canvas, open canvas, create canvas"
allowed-tools: Read Write Edit Glob Grep
---

# canvas: Visual Reference Layer

## 発火・詳細（description から移設 2026-07-03）

Visual layer of the wiki. Add images, text cards, PDFs, and wiki pages to Obsidian canvas files with auto-positioning inside zones. Integrates with /banana for image capture. Triggers on: /canvas, canvas new, canvas add image, canvas add text, canvas add pdf, canvas add note, canvas zone, canvas list, canvas from banana, add to canvas, put this on the canvas, open canvas, create canvas.

The three knowledge capture layers:
- `/save` → text synthesis (wiki/questions/, wiki/concepts/)
- `/autoresearch` → structured knowledge (wiki/sources/, wiki/concepts/)
- `/canvas` → visual references (wiki/canvases/)

> ⚠️ **Project-specific analysis** (prime_crm の hvs-*/keyword-*/first-menu-*/top200-*/uranai- 等) は
> `wiki/concepts/` ではなく `02_Ai/<group>/<sub>/research/{,_raw,_archive}/` 配下に置く (rules/42 §0-6)。
> `wiki/concepts/` は Claude × Obsidian 自身のメタ概念や横断的フレームワーク用のみ。

A canvas is a JSON file Obsidian renders as an infinite visual board. This skill reads and writes canvas JSON directly. Read `references/canvas-spec.md` for the full format reference before making any edits. This spec aligns with the [JSON Canvas open standard](https://jsoncanvas.org/). If the kepano/obsidian-skills plugin is installed, its json-canvas skill is the authoritative canvas spec reference. Otherwise, use the guidance below.

---

## Default Canvas

`wiki/canvases/main.canvas`

If it does not exist, create it:

```json
{
  "nodes": [
    {
      "id": "title",
      "type": "text",
      "text": "# Visual Reference\n\nDrop images, PDFs, and notes here.",
      "x": -400, "y": -300, "width": 400, "height": 120, "color": "6"
    },
    {
      "id": "zone-default",
      "type": "group",
      "label": "General",
      "x": -400, "y": -140, "width": 800, "height": 400, "color": "4"
    }
  ],
  "edges": []
}
```

---

## Operations

### open / status (`/canvas` with no args)

1. Check if `wiki/canvases/main.canvas` exists.
2. If yes: read it, count nodes by type, list all group node labels (zone names).
   Report: "Canvas has N nodes: X images, Y text cards, Z wiki pages. Zones: [list]"
3. If no: create it with the starter structure above.
   Report: "Created main.canvas with a General zone."
4. Tell user: "Open `wiki/canvases/main.canvas` in Obsidian to view."

---

### new (`/canvas new [name]`)

1. Slugify the name: lowercase, spaces → hyphens, strip special chars.
2. Create `wiki/canvases/[slug].canvas` with the starter structure, title updated to `# [Name]`.
3. Add entry to `wiki/overview.md` under a "## Canvases" subsection (append after the Current State section). Do not modify `wiki/index.md`. It uses a fixed section schema (Domains, Entities, Concepts, Sources, Questions, Comparisons).
4. Report: "Created wiki/canvases/[slug].canvas"

---

### add image (`/canvas add image [path or url]`)

**Resolve the image:**
- If URL (starts with `http`): download with `curl -sL [url] -o _attachments/images/canvas/[filename]`
  Derive filename from URL path, or use `img-[timestamp].jpg` if unclear.
- If local path outside vault: `cp [path] _attachments/images/canvas/`
- If already vault-relative: use as-is.

Create `_attachments/images/canvas/` if it doesn't exist.

**Detect aspect ratio:**
Use `sips -g pixelWidth -g pixelHeight [path]` (macOS built-in). Fallbacks if unavailable: `python3 -c "from PIL import Image; img=Image.open('[path]'); print(img.width, img.height)"` or `identify -format '%w %h' [path]`.
See `references/canvas-spec.md` for the full aspect ratio → canvas size table (6 ratios + PDF + Unknown fallback). Do not use an inline table here. The spec is the single source of truth for sizing.

**Position using auto-layout** (see Auto-Positioning section below).

**Append node to canvas JSON and write.**

Report: "Added [filename] to [zone] zone at position ([x], [y])."

---

### add text (`/canvas add text [content]`)

Create a text node:
```json
{
  "id": "text-[timestamp]",
  "type": "text",
  "text": "[content]",
  "x": [auto], "y": [auto],
  "width": 300, "height": 120,
  "color": "4"
}
```

Position using auto-layout. Write and report.

---

### add pdf (`/canvas add pdf [path]`)

Same as add image. Obsidian renders PDFs natively as file nodes.
- Copy to `_attachments/pdfs/canvas/` if outside vault.
- Fixed size: width=400, height=520.
- Report page count if you can determine it.

---

### add note (`/canvas add note [wiki-page]`)

1. Search `wiki/` for a file matching the page name (case-insensitive, partial match ok).
2. Use the vault-relative path as the `file` field.
   - Use `"type": "file"` (not `"type": "link"`): `.md` files use file nodes, not link nodes.
   - `"type": "link"` takes a `url: "https://..."`: it is for web URLs only.
3. Create a file node: width=300, height=100.
4. Position using auto-layout.

```json
{
  "id": "note-[timestamp]",
  "type": "file",
  "file": "wiki/concepts/LLM Wiki Pattern.md",
  "x": [auto], "y": [auto],
  "width": 300, "height": 100
}
```

---

### zone (`/canvas zone [name] [color]`)

1. Read canvas JSON.
2. Find max_y: `max(node.y + node.height for all nodes) + 60`. Use 280 if no nodes (leaves room above the starter title node).
3. Create a group node:

```json
{
  "id": "zone-[slug]",
  "type": "group",
  "label": "[name]",
  "x": -400,
  "y": [max_y],
  "width": 1000,
  "height": 400,
  "color": "[color or '3']"
}
```

Valid colors: `"1"`=red `"2"`=orange `"3"`=yellow `"4"`=green `"5"`=cyan `"6"`=purple

Write and report.

---

### list (`/canvas list`)

1. `glob wiki/canvases/*.canvas`
2. For each canvas: read JSON, count nodes by type.
3. Report:

```
wiki/canvases/main.canvas      . 14 nodes (8 images, 3 text, 2 file, 1 group)
wiki/canvases/design-ideas.canvas. 42 nodes (30 images, 4 text, 8 groups)
```

---

### from banana (`/canvas from banana`) (if the banana-claude plugin is installed)

1. Check `wiki/canvases/.recent-images.txt` first (session log of newly written images).
2. If not found or empty: use `find` with correct precedence (parentheses required. Without them `-newer` only binds to the last `-name` clause):
   ```bash
   python3 -c "import time,os; open('/tmp/ten-min-ago','w').close(); os.utime('/tmp/ten-min-ago',(time.time()-600,time.time()-600))"
   find _attachments/images -newer /tmp/ten-min-ago \( -name "*.png" -o -name "*.jpg" \)
   ```
   Note: `/banana` is an optional external skill not shipped in this plugin. If the user has it installed, the `.recent-images.txt` log will be populated. If not, the `find` command above is the fallback.
3. If still none: show the 5 most recently modified images.
4. Present list: "Found N recent images: [list]. Add to canvas? Which zone? (zone name / 'new [name]' / 'skip')"
5. On confirmation: add each using the add image logic.

---

## Auto-Positioning + ID Generation + Session Log

配置アルゴリズム・ID 生成・session log・banana 統合の詳細は `references/algorithms.md` を参照。

## Summary

1. Read canvas-spec.md before editing any canvas JSON.
2. Always read the canvas file before writing. Parse existing nodes to avoid ID collisions and calculate auto-positions.
3. Create `_attachments/images/canvas/` for downloaded/copied images.
4. Update `wiki/overview.md` ("## Canvases" subsection) when creating new canvases. Do not modify `wiki/index.md`.
5. Report position and zone after every add operation.

## See Also

For standalone visual production (12 templates, 6 layout algorithms, AI generation,
presentations), see [claude-canvas](https://github.com/AgriciDaniel/claude-canvas).
This skill handles wiki-scoped visual boards. claude-canvas handles full-featured
canvas orchestration for any project.
