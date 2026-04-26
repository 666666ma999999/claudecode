---
description: Move an Obsidian NOW task to DONE with original prompt archived to refs/.
---

Read the `obsidian-now-done` skill. Then run the NOW→DONE workflow.

Usage:
- `/done` — find the most recent NOW task in the current project's MD file. If multiple candidates, list and ask which to complete.
- `/done [task-name]` — complete the named task (slug match against NOW heading).
- `/done list` — list current NOW tasks across the project's tracked MD without making changes.

Behavior:
- Move the task from `## NOW` to `## DONE` using the new refs-separation format (h5 heading, summary line, `[[refs/...]]` link, result summary).
- Archive the original prompt verbatim to `<project>/refs/YYYY-MM-DD_<slug>.md` (append-only).
- Skip if the source MD has no `## NOW` section or no eligible entries.

If the project has no DONE-pattern MD set up yet, say: "No NOW/DONE MD found in this project. The /done command requires a project MD with `## NOW` and `## DONE` sections."

This command is the explicit-trigger entry point for the obsidian-now-done skill (alongside natural-language triggers like "タスク完了" / "NOW→DONE").
