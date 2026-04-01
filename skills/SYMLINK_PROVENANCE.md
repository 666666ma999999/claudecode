# Symlink Skill Provenance

Last updated: 2026-04-01

All symlinked skills point to `~/.agents/skills/<name>`.
`~/.agents/` is **not** a git repository and has no package.json — provenance is untracked.

## Origin: unknown (manual install or `npx skills install`)

| Skill | Words | Notes |
|-------|-------|-------|
| agentic-actions-auditor | 2932 | Security: GitHub Actions AI agent audit |
| understand | 2721 | Codebase knowledge graph generation |
| semgrep | 1380 | Static analysis with parallel subagents |
| smux | 1160 | tmux pane control + agent communication |
| differential-review | 974 | Security-focused PR/diff review |
| semgrep-rule-creator | 918 | Custom Semgrep rule authoring |
| supply-chain-risk-auditor | 886 | Dependency risk assessment |
| variant-analysis | 818 | Pattern-based vulnerability hunting |
| understand-diff | 540 | Git diff impact analysis |
| understand-explain | 454 | Deep-dive code explanation |
| humanizer-ja | 443 | Japanese text humanizer |
| understand-onboard | 424 | Onboarding guide generation |
| understand-chat | 406 | Interactive codebase Q&A |
| understand-dashboard | 365 | Knowledge graph web dashboard |

## Risk

- No version pinning: upstream updates to `~/.agents/skills/` silently change behavior
- No rollback: no git history to revert to previous versions

## Mitigation (recommended)

1. `git init ~/.agents` and commit current state as baseline
2. Or copy skills into `~/.claude/skills/` directly (break symlinks)
