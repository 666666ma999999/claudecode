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
3. Archive the original prompt verbatim. Preferred path: `<project>/tasks/refs/YYYY-MM-DD_<slug>.md` (next to `tasks/NOW.md`); if the NOW MD lives elsewhere, use a `refs/` dir alongside it. Create the dir if absent; append-only — never overwrite an existing ref.
4. Record the task under the DONE section (`## Done` or `## DONE`), **matching that section's existing format**:
   - If it is a markdown table, insert a new row right after the header separator (newest on top) with a one-line summary + a link to the refs file.
   - Otherwise use the h5 refs-separation format: `##### YYYY-MM-DD <task title>` + one-line summary + refs link + result summary.
   Then remove the task from `## NOW` (if it was listed there).
5. Update the file's `last_updated` frontmatter (or `**最終更新**:` line) to today.

Note: **spot prompts** use `~/.claude/scripts/vault-spot-runner.sh` instead — it runs the prompt (result to `reports/`) and appends a full-text record (prompt body + いつ/なぜ/結果) to the project's `prompts/_INBOX.md` under `## 📒 記録` as the completion marker (no NOW.md row, no refs/ copy; the old `prompts/spot/done/` move was retired 2026-06-26 — see [[decisions]]). `/done` is the manual NOW→DONE path for tasks worked interactively that you want recorded in the `## Done` ledger.

Edge cases:
- No `## NOW` section / no eligible entries → skip and report: "No NOW/DONE MD found in this project. The /done command requires a project MD with a `## NOW` and a `## Done`/`## DONE` section."
- `/done list` → list NOW tasks only; make no changes.

Natural-language triggers: "タスク完了" / "NOW→DONE" route here too.
