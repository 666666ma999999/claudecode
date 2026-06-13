---
description: Move an Obsidian NOW task to DONE with original prompt archived to refs/.
---

Run the NOW→DONE workflow described below. (This command is self-contained — the
former `obsidian-now-done` skill is dormant at `skills/_dormant/`; do NOT try to load it.)

Usage:
- `/done` — find the most recent NOW task in the current project's MD file. If multiple candidates, list and ask which to complete.
- `/done [task-name]` — complete the named task (slug match against NOW heading).
- `/done list` — list current NOW tasks across the project's tracked MD without making changes.

Steps:
1. Locate the project's NOW/DONE MD. Resolution order:
   a. A `*_ope.md` MOC or `tasks/NOW.md` in the current project that contains a `## NOW` section.
   b. If none, search the cwd's tracked MD for a `## NOW` heading.
2. Pick the target task (newest under `## NOW`, or the slug match for `/done [task-name]`).
3. Archive the original prompt verbatim to `<project>/refs/YYYY-MM-DD_<slug>.md` (create `refs/` if absent; append-only — never overwrite an existing ref).
4. Move the task from `## NOW` to `## DONE` using the refs-separation format:
   `##### YYYY-MM-DD <task title>` + one-line summary + `[[refs/YYYY-MM-DD_<slug>]]` link + result summary.
5. Update the file's `last_updated` frontmatter to today.

Edge cases:
- No `## NOW` section / no eligible entries → skip and report: "No NOW/DONE MD found in this project. The /done command requires a project MD with `## NOW` and `## DONE` sections."
- `/done list` → list NOW tasks only; make no changes.

Natural-language triggers: "タスク完了" / "NOW→DONE" route here too.
