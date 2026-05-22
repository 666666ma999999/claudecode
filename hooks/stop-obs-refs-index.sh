#!/bin/bash
# Stop hook: Regenerate References/Sources/_index.md when vault is present.
# Triggered after every Claude session stop. Idempotent, <1s runtime.
# Safe to run even when no raw/ files changed (full overwrite of _index.md).

vault="$HOME/Documents/Obsidian Vault"

# Guard: vault must exist and have References/raw/
[ -d "$vault/References/raw" ] || exit 0

# Run index generator (silent unless error)
"$HOME/.claude/bin/obs-refs-index" >/dev/null 2>&1 || true

exit 0
