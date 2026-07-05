## Gotchas

Before interpreting Step 1 output, check these known failure modes.

**Data collection silent failures**
- `jq` not installed: conversation extraction prints `(unavailable: jq not installed or parse error)`. BEHAVIOR section will be empty -- treat as [INSUFFICIENT DATA], not a finding.
- `python3` not on PATH: all MCP/hooks/allowedTools sections print `(unavailable)`. Do not flag those areas when the data source itself failed.
- `settings.local.json` absent: only the allowedTools count drops to 0; hooks and MCP are still aggregated from `~/.claude/settings.json` and `.mcp.json`. Normal for projects using global settings only -- not a misconfiguration.

**MEMORY.md path construction**
- Path built with `sed 's|[/._]|-|g'` on `pwd`. Claude Code converts `/`, `.`, and `_` to `-`. If MEMORY.md shows `(none)` but the user mentions prior sessions, verify the path manually before flagging as [!].

**Conversation extract scope**
- Only the 3 most recent `.jsonl` files are sampled, skipping the active session. Findings from fewer than 3 files carry low signal -- always tag [LOW CONFIDENCE].

**MCP token estimate**
- Assumes ~25 tools/server and ~200 tokens/tool. Servers with many or few tools cause large over/under-estimates. Treat as directional, not precise.

**Tier misclassification edge cases**
- The bash block excludes `node_modules/`, `dist/`, and `build/`, but not all generators. Monorepos with `.next/`, `__pycache__/`, or `.turbo/` output can inflate the file count and trigger COMPLEX tier falsely. Recheck manually if the tier feels wrong.

