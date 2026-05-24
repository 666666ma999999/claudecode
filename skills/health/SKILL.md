---
name: health
description: Run when Claude feels off, ignores rules, or hooks/MCP need auditing.
allowed-tools: [Read, Glob, Grep, Bash]
---

# Claude Code Configuration Health Audit

Audit the current project's Claude Code setup with the six-layer framework:
`CLAUDE.md → rules → skills → hooks → subagents → verifiers`

The goal is to find violations and identify the misaligned layer, calibrated to project complexity.

**Output language:** Check in order: (1) CLAUDE.md `## Communication` rule (global takes precedence over local); (2) language of the user's recent conversation messages; (3) default English. Apply the detected language to all output including progress lines, the report, and the stop-condition question.

**IMPORTANT:** Before the first tool call, output a progress block in the output language:

```
Step 1/3: Collecting configuration data
  · CLAUDE.md (global + local) · rules/ · settings.local.json · hooks
  · MCP servers · skills inventory + security scan
  · conversation history (up to 3 recent sessions)
```

## Step 0: Assess project tier

| Tier | Signal | What's expected |
|------|--------|-----------------|
| **Simple** | <500 project files, 1 contributor, no CI | CLAUDE.md only; 0–1 skills; no rules/; hooks optional |
| **Standard** | 500–5K project files, small team or CI present | CLAUDE.md + 1–2 rules files; 2–4 skills; basic hooks |
| **Complex** | >5K project files, multi-contributor, multi-language, active CI | Full six-layer setup required |

**Apply only the detected tier's requirements.**

## Step 1: Collect all data

Run the collector script (executes one bash block, prints all sections):

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/collect.sh
```

The script handles: tier metrics, CLAUDE.md (global + local), rules/, settings.local.json, hooks, MCP servers, allowedTools, gitignore check, nested CLAUDE.md, MEMORY.md, conversation extracts, skill inventory + frontmatter + symlink provenance, and a sample of full skill content.

Known failure modes (silent data gaps, MEMORY.md path issues, MCP estimate caveats, tier misclassification edge cases) are documented in `references/gotchas.md`. Read it if the data looks unexpected.

**Hook/Skill/MCP が起動しない時は `/debug "なぜ <hook名> が発火しなかった?"` で診断ログを取得**（Claude Code 2.1.140+ built-in）。tail/log 手動探索より高速。

## Step 2: Analyze with tier-adjusted depth

After Step 1 completes, output a summary line, then the step indicator:

```
Tier: {SIMPLE/STANDARD/COMPLEX} -- {file_count} files · {contributor_count} contributors · CI: {present/absent}
Step 2/3: {SIMPLE: "Analyzing locally" | STANDARD/COMPLEX: "Launching parallel analysis agents"}
```

**SIMPLE**: analyze locally without subagents. Prioritize core config checks, skip conversation-heavy cross-validation unless evidence is obvious.

**STANDARD / COMPLEX**: launch two subagents in parallel. Paste structural data inline (replace credential values with `[REDACTED]`). Coverage:

- Agent 1: read `agents/agent1-context.md` — CLAUDE.md, rules, skills, MCP context + security scan
- Agent 2: read `agents/agent2-control.md` — hooks, allowedTools, behavior patterns, three-layer defense

## Step 3: Synthesize and present

```
Step 3/3: Synthesizing report
```

Aggregate findings into one report:

```
**Health Report: {project} ({tier} tier, {file_count} files)**

### ✓ Passing
| Check | Detail |
|-------|--------|
(up to 5 rows of passing checks relevant to the tier)

### ☻ Critical -- fix now
Rules violated, missing verification, dangerous allowedTools, MCP overhead >12.5%,
required-path Access denied, active cache-breakers, security findings.

### ◎ Structural -- fix soon
CLAUDE.md content belonging elsewhere, missing hooks, oversized skill descriptions,
single-layer critical rules, model switching, verifier gaps, subagent permission gaps,
skill structural issues.

### ○ Incremental -- nice to have
New patterns, outdated items, global vs local placement, context hygiene,
HANDOFF.md adoption, skill invoke tuning, provenance.
```

If all three issue sections are empty, output one short line: `✓ All relevant checks passed. Nothing to fix.`

## Non-goals

- Never auto-apply fixes without confirmation.
- Never apply complex-tier checks to simple projects.
- Flag issues, do not replace architectural judgment.

**Stop condition:** After the report, ask in the output language:
> "Should I draft the changes? I can handle each layer separately: global CLAUDE.md / local CLAUDE.md / hooks / skills."

Do not make any edits without explicit confirmation.
