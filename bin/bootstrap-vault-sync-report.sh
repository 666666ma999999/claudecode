#!/usr/bin/env bash
set -euo pipefail

: "${OBSIDIAN_VAULT_PATH:=$HOME/Documents/Obsidian Vault}"

SLUG="report"
PROJECT_ROOT="$HOME/Desktop/prm/$SLUG"
VAULT_DIR="$OBSIDIAN_VAULT_PATH/projects/$SLUG/COMMAND-CENTER"
SYNCCTL="$HOME/.claude/bin/syncctl"
SESSIONSTART_HOOK="$HOME/.claude/hooks/vault-sync-sessionstart.sh"
STOP_HOOK="$HOME/.claude/hooks/vault-sync-stop.sh"
SETTINGS_JSON="$HOME/.claude/settings.json"

die() {
  printf '[bootstrap][ERROR] %s\n' "$*" >&2
  exit 1
}

[[ -d "$PROJECT_ROOT" ]] || die "project root missing: $PROJECT_ROOT"
[[ -d "$OBSIDIAN_VAULT_PATH" ]] || die "vault missing: $OBSIDIAN_VAULT_PATH"

if ! git -C "$OBSIDIAN_VAULT_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[bootstrap] vault is not git repo; initializing" >&2
  git -C "$OBSIDIAN_VAULT_PATH" init >/dev/null
  git -C "$OBSIDIAN_VAULT_PATH" add . >/dev/null || true
  git -C "$OBSIDIAN_VAULT_PATH" commit -m "initial vault snapshot" >/dev/null || true
fi

mkdir -p "$VAULT_DIR/tasks" "$PROJECT_ROOT/tasks" "$PROJECT_ROOT/.ccsync"

if [[ ! -f "$VAULT_DIR/plan.md" ]]; then
  cat > "$VAULT_DIR/plan.md" <<'EOF'
# report plan

## Goal

## Tasks

## Verification
EOF
fi

if ! find "$VAULT_DIR/tasks" -mindepth 1 -type f | grep -q .; then
  cat > "$VAULT_DIR/tasks/active.md" <<'EOF'
# active

## Scope

## Progress

## Session Handoff
EOF
fi

if [[ ! -f "$PROJECT_ROOT/plan.md" ]]; then
  cp "$VAULT_DIR/plan.md" "$PROJECT_ROOT/plan.md"
fi

if ! find "$PROJECT_ROOT/tasks" -mindepth 1 -type f | grep -q .; then
  cp "$VAULT_DIR/tasks/active.md" "$PROJECT_ROOT/tasks/active.md"
fi

chmod +x "$SYNCCTL" "$SESSIONSTART_HOOK" "$STOP_HOOK"

python3 - "$SETTINGS_JSON" "$SESSIONSTART_HOOK" "$STOP_HOOK" <<'PY'
import json
import os
import pathlib
import sys
import tempfile
import time

settings_path = pathlib.Path(sys.argv[1])
sessionstart_hook = sys.argv[2]
stop_hook = sys.argv[3]

raw = settings_path.read_text()
data = json.loads(raw)

ts = time.strftime("%Y%m%d-%H%M%S")
backup_path = settings_path.with_name(f"{settings_path.name}.bak-{ts}")
backup_path.write_text(raw)

hooks = data.setdefault("hooks", {})

def ensure(event, command):
    arr = hooks.setdefault(event, [])
    for item in arr:
        for hook in item.get("hooks", []):
            if hook.get("command") == command:
                return
    arr.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": command}]
    })

ensure("SessionStart", sessionstart_hook)
ensure("Stop", stop_hook)

new_text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
json.loads(new_text)

tmp_fd, tmp_name = tempfile.mkstemp(
    prefix=settings_path.name + ".tmp-",
    dir=str(settings_path.parent)
)
try:
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
        fh.write(new_text)
    os.replace(tmp_name, settings_path)
finally:
    if os.path.exists(tmp_name):
        os.unlink(tmp_name)
PY

if [[ -d "$OBSIDIAN_VAULT_PATH/.git" ]]; then
  if ! grep -qxF '.git/ccsync.lock' "$OBSIDIAN_VAULT_PATH/.gitignore" 2>/dev/null; then
    printf '%s\n' '.git/ccsync.lock' >> "$OBSIDIAN_VAULT_PATH/.gitignore"
  fi
fi

git -C "$OBSIDIAN_VAULT_PATH" add ".gitignore" "projects/$SLUG" >/dev/null
git -C "$OBSIDIAN_VAULT_PATH" commit -m "bootstrap vault sync: $SLUG" >/dev/null || true

echo "[bootstrap] complete"
echo "[bootstrap] next: cd \"$PROJECT_ROOT\" && \"$SYNCCTL\" pull"
