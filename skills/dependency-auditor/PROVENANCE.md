# Provenance

- **Source repo**: https://github.com/alirezarezvani/claude-skills
- **Source path**: `engineering/skills/dependency-auditor/`
- **Commit SHA (pinned)**: `aecfb8e0bb71dbf1413082f86b33a5c4c9b8f416`
- **Retrieved**: 2026-07-24
- **License**: MIT (inherited from repo root)
- **Method**: Manual file-by-file download via `raw.githubusercontent.com` at the pinned SHA. `npx skills add` was NOT used. No downloaded script was executed during import.

## Audit record

Candidate 1 in `~/.claude/tasks/refs/candidate-audit.md`. Manually reviewed source code before installation:

- No outbound network calls in `scripts/*.py` (`requests`/`urllib`/`http.client`/`socket` string matches are false positives: e.g. `'requests'` appears only as a package name inside the offline CVE pattern database in `dep_scanner.py`, and as a version pin in `upgrade_planner.py`; `subprocess` is imported in `dep_scanner.py` and `upgrade_planner.py` but never actually invoked)
- No `eval`/`exec`/`os.system`/`__import__` usage found
- No `postinstall` hooks (this is a Claude Skill, not an npm package)

## Operational note

The three scripts (`dep_scanner.py`, `license_checker.py`, `upgrade_planner.py`) are offline, deterministic pattern-matchers over manifests/lockfiles. The built-in CVE pattern set is a smoke layer only (~16 entries as of this commit) and is NOT a substitute for live vulnerability databases. Per SKILL.md's own guidance, pair findings with `npm audit` / `pip-audit` / `cargo audit` for current CVE coverage.

## Update policy

Upstream tracking is manual. When re-syncing, pin to a new commit SHA, re-download, re-run this same audit (grep for network/exec calls), and update this file's SHA and retrieval date accordingly. Do not use `npx skills update` for this skill.
