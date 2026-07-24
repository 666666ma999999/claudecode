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

### Known false-positive mode (observed 2026-07-24, pokeca-invest trial run)

Pointing `dep_scanner.py` at a project root makes it `rglob` ALL supported manifests, **including files bundled inside `node_modules/` by third-party packages** (e.g. a package's own `devDependencies` declaration, or a `yarn.lock` accidentally shipped in an npm tarball like `uri-js`). These describe the third party's dev environment, not anything installed in the scanned project. Observed result: 3 "HIGH lodash" findings in a project whose lockfile and `node_modules/` contain no lodash at all (one finding was even a mis-pairing with an adjacent `esprima@4.0.1` entry in a bundled yarn.lock — the yarn.lock parser can misattribute versions).

**Rule: before acting on any finding, verify against the project's own lockfile (`package-lock.json` packages map) and the physically installed `node_modules/<pkg>/package.json`. A finding that exists only under someone else's `node_modules` metadata is noise.** Prefer scanning a copy of the project with `node_modules/` excluded, or pass a subdirectory that contains only first-party manifests.

## Update policy

Upstream tracking is manual. When re-syncing, pin to a new commit SHA, re-download, re-run this same audit (grep for network/exec calls), and update this file's SHA and retrieval date accordingly. Do not use `npx skills update` for this skill.
