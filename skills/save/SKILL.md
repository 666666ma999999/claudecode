---
name: save
description: >
  Save the current conversation, answer, or insight into the Obsidian wiki vault as a
  structured note. Analyzes the chat, determines the right note type, creates frontmatter,
  files it in the correct wiki folder, and updates index, log, and hot cache.
  Triggers on: "save this", "save that answer", "/save", "/save decision", "/save mistake",
  "file this", "save to wiki", "save this session", "file this conversation", "keep this",
  "save this analysis", "add this to the wiki", "決定を記録", "方針確定", "教訓",
  "再発防止", "同じミス", "lesson learned".
allowed-tools: Read Write Edit Glob Grep
---

# save: File Conversations Into the Wiki

Good answers and insights shouldn't disappear into chat history. This skill takes what was just discussed and files it as a permanent wiki page.

The wiki compounds. Save often.

---

## Note Type Decision

Determine the best type from the conversation content:

| Type | Target | Mode | Use when |
|------|--------|------|---------|
| synthesis | wiki/questions/ | new file | Multi-step analysis, comparison, or answer to a specific question |
| concept | wiki/concepts/ | new file | Explaining or defining an idea, pattern, or framework |
| source | wiki/sources/ | new file | Summary of external material discussed in the session |
| session | wiki/meta/ | new file | Full session summary: captures everything discussed |
| **decision** | **wiki/meta/decisions.md** | **single-file append** | Architectural, project, or strategic decision that was made. **Always one file, append-only.** |
| **mistake** | **wiki/meta/mistakes.md** | **single-file de-dup** | Recurring failure pattern, lesson learned. **Always one file, merge if pattern already exists.** |

If the user specifies a type, use that. If not, pick the best fit. When in doubt, use `synthesis`.

**Trigger routing**:
- `/save decision`, "決定を記録", "方針確定", "採用", "却下" → type=**decision**
- `/save mistake`, "教訓", "再発防止", "同じミス", "lesson learned" → type=**mistake**
- Else → infer from content (synthesis/concept/source/session)

---

## Single-File Append Modes (decision / mistake)

These two types are **special**: they do NOT create new files per save. They append to / merge into one canonical file each, per `rules/40-obsidian.md`:

- **decision** → append to `wiki/meta/decisions.md` (append-only, newest on top of entry list)
- **mistake** → append OR merge in `wiki/meta/mistakes.md` (de-dup; 2nd occurrence updates existing entry)

For these types, skip the standard "new file with frontmatter" workflow. Use the append/merge workflow below.

### decision append workflow

1. Read `wiki/meta/decisions.md`.
2. Find the marker line `新しい判断は **このセクションの直下**に append（newest on top）。` (after the `## 書き方` section's code block + `---`).
3. Insert the new entry **immediately after** that marker (and before the next `---` divider), using this exact template:

   ```markdown
   ## YYYY-MM-DD — <短い決定タイトル>

   **Context**: 何があったか / なぜこの判断が要ったか
   **Decision**: 何を決めたか（1 文）
   **Reasoning**: 根拠（箇条書き 2-4 個）
   **Alternatives considered**: 検討した別案と却下理由
   **Scope**: どのプロジェクトに効くか（[[project]] wikilink）
   **Supersedes**: （過去判断を上書きする場合のみ）[[YYYY-MM-DD-slug]]
   **Related**: 関連 wiki ページ wikilink（任意）
   **KPI**: 成功判定の観測値（任意）

   ---
   ```

4. If superseding a prior decision, fill `**Supersedes**` with the wikilink to the old entry. **Do NOT edit or delete the old entry** — append-only.
5. Update `wiki/log.md` with `## [YYYY-MM-DD] decision | <title>` at the top.
6. Confirm: "Appended decision [YYYY-MM-DD — title] to wiki/meta/decisions.md."

### mistake append/merge workflow

1. Read `wiki/meta/mistakes.md`.
2. **Check for duplicate**: search existing entries by pattern name (`## <パターン名>` headings). If a similar pattern exists:
   - **Update** the existing entry's `**最終発生**` and `**頻度**` (e.g., "2 回目" → "3 回目")
   - Optionally add the new project to `**発生プロジェクト**` if not already listed
   - **Do NOT create a new entry** for the same pattern (de-dup principle)
3. If no duplicate: insert a new entry **immediately after** the `## 書き方` code block + marker text, using this template:

   ```markdown
   ## <パターン名（短く、固有名詞っぽく）>

   **症状**: 何が起きるか
   **根本原因**: なぜ起きるか
   **ルール**: 再発防止策（1 行）
   **発生プロジェクト**: [[project-a]]
   **最終発生**: YYYY-MM-DD
   **頻度**: 初回

   ---
   ```

4. Update `wiki/log.md` with `## [YYYY-MM-DD] mistake | <pattern>` (or `mistake-merge` if dedup).
5. Confirm: "Appended mistake [pattern] to wiki/meta/mistakes.md." or "Merged into existing mistake entry [pattern] (頻度: N 回目)."

**Note**: If 3 months pass with no recurrence, the entry should be moved to the `## Archive (3 ヶ月以上未発生)` section. This is a separate maintenance task (not done on every save).

---

## Standard Save Workflow (synthesis / concept / source / session)

For non-decision / non-mistake types only.

1. **Scan** the current conversation. Identify the most valuable content to preserve.
2. **Ask** (if not already named): "What should I call this note?" Keep the name short and descriptive.
3. **Determine** note type using the table above.
4. **Extract** all relevant content from the conversation. Rewrite it in declarative present tense (not "the user asked" but the actual content itself).
5. **Create** the note in the correct folder with full frontmatter.
6. **Collect links**: identify any wiki pages mentioned in the conversation. Add them to `related` in frontmatter.
7. **Update** `wiki/index.md`. Add the new entry at the top of the relevant section.
8. **Append** to `wiki/log.md`. New entry at the TOP:
   ```
   ## [YYYY-MM-DD] save | Note Title
   - Type: [note type]
   - Location: wiki/[folder]/Note Title.md
   - From: conversation on [brief topic description]
   ```
9. **Update** `wiki/hot.md` to reflect the new addition.
10. **Confirm**: "Saved as [[Note Title]] in wiki/[folder]/."

---

## Frontmatter Template (new-file types only)

```yaml
---
type: <synthesis|concept|source|session>
title: "Note Title"
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - <relevant-tag>
status: developing
related:
  - "[[Any Wiki Page Mentioned]]"
sources:
  - "[[.raw/source-if-applicable.md]]"
---
```

decision and mistake do NOT use frontmatter — they append plain markdown entries into a single file (see Single-File Append Modes above).

---

## Writing Style

- Declarative, present tense. Write the knowledge, not the conversation.
- Not: "The user asked about X and Claude explained..."
- Yes: "X works by doing Y. The key insight is Z."
- Include all relevant context. Future sessions should be able to read this page cold.
- Link every mentioned concept, entity, or wiki page with wikilinks.
- Cite sources where applicable: `(Source: [[Page]])`.

---

## What to Save vs. Skip

Save:
- Non-obvious insights or synthesis
- **Decisions with rationale** (→ decisions.md)
- **Recurring failure patterns** (→ mistakes.md, especially on 2nd+ occurrence)
- Analyses that took significant effort
- Comparisons that are likely to be referenced again
- Research findings

Skip:
- Mechanical Q&A (lookup questions with obvious answers)
- Setup steps already documented elsewhere
- Temporary debugging sessions with no lasting insight
- Anything already in the wiki (for new-file types) — update existing instead
- A failure pattern that's already an entry in mistakes.md but you'd add nothing new (the `**最終発生**` / `**頻度**` update already happened)

If a non-decision / non-mistake topic is already in the wiki, update the existing page instead of creating a duplicate.
