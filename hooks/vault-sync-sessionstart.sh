#!/usr/bin/env bash
set -euo pipefail

if [[ "${CCSYNC_DISABLE:-0}" == "1" ]]; then
  echo "[vault-sync][SessionStart] DISABLED via CCSYNC_DISABLE=1" >&2
  exit 0
fi

cat >/dev/null || true

PROJECT_ROOT="$HOME/Desktop/prm/report"
SYNCCTL="$HOME/.claude/bin/syncctl"

REAL_PWD="$(cd "${PWD:-.}" 2>/dev/null && pwd -P || echo "")"
REAL_PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P || echo "")"

if [[ "$REAL_PWD" != "$REAL_PROJECT_ROOT" ]]; then
  exit 0
fi

if [[ ! -x "$SYNCCTL" ]]; then
  echo "[vault-sync][SessionStart] syncctl not executable: $SYNCCTL" >&2
  exit 1
fi

echo "[vault-sync][SessionStart] pull start" >&2
cd "$PROJECT_ROOT"
"$SYNCCTL" pull
echo "[vault-sync][SessionStart] pull done" >&2
