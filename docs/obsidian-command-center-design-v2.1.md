# v2.1 設計: Phase 1 MVP (`salesmtg` のみ)

P0 3項目 + P1 5項目 + 軽微修正を v2 に反映済み。

## 1. `syncctl` 全文

保存先: `~/.claude/bin/syncctl`

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "${CCSYNC_DISABLE:-0}" == "1" ]]; then
  echo "[syncctl] DISABLED via CCSYNC_DISABLE=1" >&2
  exit 0
fi

COMMAND="${1:-}"
ARG1="${2:-}"
ARG2="${3:-}"

: "${OBSIDIAN_VAULT_PATH:=$HOME/Documents/Obsidian Vault}"

PRM_ROOT="$HOME/Desktop/prm"
CLAUDE_STATE_ROOT="$HOME/.claude/state/vault-sync"
LOCK_ROOT="$CLAUDE_STATE_ROOT/locks"
LOCK_TTL_SECONDS=900
DATE_FMT="+%Y-%m-%dT%H:%M:%S%z"

mkdir -p "$CLAUDE_STATE_ROOT" "$LOCK_ROOT"

log() {
  printf '[syncctl] %s\n' "$*" >&2
}

die() {
  printf '[syncctl][ERROR] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'EOF'
Usage:
  syncctl pull
  syncctl push
  syncctl unlock --force <slug>
EOF
  exit 2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

validate_slug() {
  local slug="$1"
  [[ "$slug" =~ ^[a-z0-9_-]+$ ]] || die "invalid slug: '$slug' (must match ^[a-z0-9_-]+$)"
}

project_root_from_cwd() {
  local cwd real_cwd base
  cwd="${PWD}"
  real_cwd="$(cd "$cwd" && pwd -P)"
  case "$real_cwd" in
    "$PRM_ROOT"/*) ;;
    *) die "cwd must be under $PRM_ROOT, got: $real_cwd" ;;
  esac
  base="${real_cwd#$PRM_ROOT/}"
  base="${base%%/*}"
  printf '%s\n' "$PRM_ROOT/$base"
}

slug_from_project_root() {
  local project_root slug
  project_root="$1"
  slug="$(basename "$project_root")"
  validate_slug "$slug"
  printf '%s\n' "$slug"
}

resolve_vault_project_dir() {
  local slug="$1"
  printf '%s\n' "$OBSIDIAN_VAULT_PATH/projects/$slug/COMMAND-CENTER"
}

relative_to_projects_root() {
  local target="$1"
  local projects_root target_real root_real rel

  projects_root="$OBSIDIAN_VAULT_PATH/projects"

  require_cmd python3

  target_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target")"
  root_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$projects_root")"
  rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$target_real" "$root_real")"

  printf '%s\n' "$rel"
}

assert_vault_target_safe() {
  local slug="$1"
  local target="$2"
  local rel

  rel="$(relative_to_projects_root "$target")"

  [[ "$rel" != ..* ]] || die "path traversal detected for target: $target"
  [[ "$rel" == "$slug/COMMAND-CENTER" || "$rel" == "$slug/COMMAND-CENTER/" ]] || \
    die "unexpected vault target mapping: rel='$rel', slug='$slug'"
}

require_salesmtg_only() {
  local slug="$1"
  [[ "$slug" == "salesmtg" ]] || die "Phase 1 is limited to slug=salesmtg, got: $slug"
}

lock_dir_for_slug() {
  local slug="$1"
  printf '%s\n' "$LOCK_ROOT/$slug.lock"
}

lock_meta_path() {
  local slug="$1"
  printf '%s\n' "$(lock_dir_for_slug "$slug")/meta.env"
}

LOCK_ACQUIRED=0
LOCK_DIR=""
LOCK_TOKEN=""

write_lock_meta() {
  local slug="$1"
  local project_root="$2"
  local meta
  meta="$(lock_meta_path "$slug")"
  cat > "$meta" <<EOF
slug=$slug
token=$LOCK_TOKEN
pid=$$
ppid=$PPID
user=${USER:-unknown}
host=$(hostname 2>/dev/null || echo unknown)
cwd=$project_root
created_at_epoch=$(date +%s)
created_at_iso=$(date "$DATE_FMT")
EOF
}

release_lock() {
  if [[ "$LOCK_ACQUIRED" != "1" || -z "$LOCK_DIR" ]]; then
    return 0
  fi

  if [[ -f "$LOCK_DIR/meta.env" ]]; then
    # shellcheck disable=SC1090
    . "$LOCK_DIR/meta.env" || true
    if [[ "${token:-}" == "$LOCK_TOKEN" ]]; then
      rm -rf "$LOCK_DIR"
    fi
  fi
}

acquire_lock() {
  local slug="$1"
  local project_root="$2"
  local now created age

  LOCK_DIR="$(lock_dir_for_slug "$slug")"
  LOCK_TOKEN="$(date +%s)-$$-$RANDOM"

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=1
    trap release_lock EXIT INT TERM
    write_lock_meta "$slug" "$project_root"
    return 0
  fi

  if [[ ! -f "$LOCK_DIR/meta.env" ]]; then
    die "lock exists without metadata: $LOCK_DIR. Run: syncctl unlock --force $slug"
  fi

  # shellcheck disable=SC1090
  . "$LOCK_DIR/meta.env" || die "failed to read lock metadata: $LOCK_DIR/meta.env"

  now="$(date +%s)"
  created="${created_at_epoch:-0}"
  [[ "$created" =~ ^[0-9]+$ ]] || die "invalid lock timestamp in $LOCK_DIR/meta.env"
  age=$(( now - created ))

  if (( age >= LOCK_TTL_SECONDS )); then
    die "stale lock detected for slug=$slug (age=${age}s >= ${LOCK_TTL_SECONDS}s). Push/pull blocked. Run: syncctl unlock --force $slug"
  fi

  die "lock is held for slug=$slug by user=${user:-unknown} pid=${pid:-unknown} host=${host:-unknown} cwd=${cwd:-unknown} age=${age}s"
}

unlock_force() {
  local slug="$1"
  local dir meta
  validate_slug "$slug"
  require_salesmtg_only "$slug"

  dir="$(lock_dir_for_slug "$slug")"
  meta="$(lock_meta_path "$slug")"

  [[ -d "$dir" ]] || die "no lock present for slug=$slug"

  if [[ -f "$meta" ]]; then
    log "removing lock for slug=$slug with metadata:"
    sed 's/^/[syncctl][lock] /' "$meta" >&2 || true
  else
    log "removing lock for slug=$slug with missing metadata"
  fi

  rm -rf "$dir"
  log "lock removed: $dir"
}

ensure_vault_git_repo() {
  git -C "$OBSIDIAN_VAULT_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    die "vault is not a git repository: $OBSIDIAN_VAULT_PATH"
}

ensure_paths_exist_for_pull() {
  local vault_dir="$1"
  [[ -f "$vault_dir/plan.md" ]] || die "vault plan.md missing: $vault_dir/plan.md"
  [[ -d "$vault_dir/tasks" ]] || die "vault tasks dir missing: $vault_dir/tasks"

  if ! find "$vault_dir/tasks" -mindepth 1 -type f | grep -q .; then
    die "vault tasks dir is empty; pull aborted to prevent accidental project-side wipe: $vault_dir/tasks"
  fi
}

ensure_paths_exist_for_push() {
  local project_root="$1"
  [[ -f "$project_root/plan.md" ]] || die "project plan.md missing: $project_root/plan.md"
  [[ -d "$project_root/tasks" ]] || die "project tasks dir missing: $project_root/tasks"

  if ! find "$project_root/tasks" -mindepth 1 -type f | grep -q .; then
    die "project tasks dir is empty; push aborted to prevent accidental vault-side wipe: $project_root/tasks"
  fi
}

ensure_project_ccsync_dirs() {
  local project_root="$1"
  mkdir -p "$project_root/.ccsync"
}

backup_root_for_run() {
  local project_root="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  printf '%s\n' "$project_root/.ccsync/backup-$ts"
}

backup_file_if_changed() {
  local src="$1"
  local dst="$2"
  local backup_dst="$3"

  mkdir -p "$(dirname "$backup_dst")"

  if [[ -f "$dst" ]]; then
    if cmp -s "$src" "$dst"; then
      return 1
    fi
    cp -p "$dst" "$backup_dst"
  fi

  cp -p "$src" "$dst"
  return 0
}

git_commit_if_staged() {
  local repo="$1"
  local message="$2"

  if git -C "$repo" diff --cached --quiet --; then
    return 1
  fi

  git -C "$repo" commit -m "$message" >/dev/null
  return 0
}

with_vault_git_lock() {
  local vault_git_lock
  vault_git_lock="$OBSIDIAN_VAULT_PATH/.git/ccsync.lock"

  if ! mkdir "$vault_git_lock" 2>/dev/null; then
    log "vault git locked by another process; skipping commit"
    return 0
  fi

  trap 'rmdir "$vault_git_lock" 2>/dev/null || true' RETURN
  "$@"
  rmdir "$vault_git_lock" 2>/dev/null || true
  trap - RETURN
}

_git_snapshot_pre_sync_inner() {
  local slug="$1"
  git -C "$OBSIDIAN_VAULT_PATH" add "projects/$slug" >/dev/null
  git_commit_if_staged "$OBSIDIAN_VAULT_PATH" "pre-sync snapshot: $slug $(date "$DATE_FMT")" || true
}

git_snapshot_pre_sync() {
  local slug="$1"
  with_vault_git_lock _git_snapshot_pre_sync_inner "$slug"
}

_git_commit_post_sync_inner() {
  local slug="$1"
  git -C "$OBSIDIAN_VAULT_PATH" add "projects/$slug" >/dev/null
  git_commit_if_staged "$OBSIDIAN_VAULT_PATH" "sync mirror: $slug $(date "$DATE_FMT")" || true
}

git_commit_post_sync() {
  local slug="$1"
  with_vault_git_lock _git_commit_post_sync_inner "$slug"
}

print_dry_run_plan_change() {
  local src="$1"
  local dst="$2"

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "plan.md dry-run: no change"
  elif [[ -f "$dst" ]]; then
    log "plan.md dry-run: update $dst"
  else
    log "plan.md dry-run: create $dst"
  fi
}

run_rsync_checked() {
  local target="$1"
  shift

  local output rc
  output="$("$@" 2>&1)"
  rc=$?

  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      printf '%s\n' "$line" | sed "s/^/[syncctl][rsync][$target] /" >&2
    done <<<"$output"
  fi

  if [[ $rc -ne 0 ]]; then
    die "rsync failed: code=$rc target=$target"
  fi
}

cleanup_old_backups() {
  local project_root="$1"
  find "$project_root/.ccsync" -maxdepth 1 -type d -name 'backup-*' -ctime +7 -exec rm -rf {} + 2>/dev/null || true
}

pull_cmd() {
  local project_root slug vault_dir backup_root changed=0

  project_root="$(project_root_from_cwd)"
  slug="$(slug_from_project_root "$project_root")"
  require_salesmtg_only "$slug"

  vault_dir="$(resolve_vault_project_dir "$slug")"
  assert_vault_target_safe "$slug" "$vault_dir"
  ensure_vault_git_repo
  git_snapshot_pre_sync "$slug"
  ensure_paths_exist_for_pull "$vault_dir"
  ensure_project_ccsync_dirs "$project_root"

  acquire_lock "$slug" "$project_root"

  backup_root="$(backup_root_for_run "$project_root")"
  mkdir -p "$backup_root/tasks"

  print_dry_run_plan_change "$vault_dir/plan.md" "$project_root/plan.md"
  run_rsync_checked "pull-dry-run-tasks" \
    rsync -ani --backup --backup-dir="$backup_root/tasks" \
    "$vault_dir/tasks/" "$project_root/tasks/"

  if backup_file_if_changed \
    "$vault_dir/plan.md" \
    "$project_root/plan.md" \
    "$backup_root/plan.md"; then
    changed=1
    log "plan.md updated from vault"
  fi

  run_rsync_checked "pull-tasks" \
    rsync -ai --backup --backup-dir="$backup_root/tasks" \
    "$vault_dir/tasks/" "$project_root/tasks/"

  cleanup_old_backups "$project_root"

  log "pull completed for slug=$slug backup_root=$backup_root"
  (( changed == 1 )) && log "plan changed during pull" || true
}

push_cmd() {
  local project_root slug vault_dir backup_root changed=0

  project_root="$(project_root_from_cwd)"
  slug="$(slug_from_project_root "$project_root")"
  require_salesmtg_only "$slug"

  vault_dir="$(resolve_vault_project_dir "$slug")"
  assert_vault_target_safe "$slug" "$vault_dir"
  ensure_vault_git_repo
  ensure_paths_exist_for_push "$project_root"

  mkdir -p "$vault_dir/tasks"
  ensure_project_ccsync_dirs "$project_root"

  acquire_lock "$slug" "$project_root"

  backup_root="$(backup_root_for_run "$project_root")"
  mkdir -p "$backup_root/vault-plan" "$backup_root/vault-tasks"

  print_dry_run_plan_change "$project_root/plan.md" "$vault_dir/plan.md"
  run_rsync_checked "push-dry-run-tasks" \
    rsync -ani --backup --backup-dir="$backup_root/vault-tasks" \
    "$project_root/tasks/" "$vault_dir/tasks/"

  git_snapshot_pre_sync "$slug"

  if backup_file_if_changed \
    "$project_root/plan.md" \
    "$vault_dir/plan.md" \
    "$backup_root/vault-plan/plan.md"; then
    changed=1
    log "plan.md updated into vault"
  fi

  run_rsync_checked "push-tasks" \
    rsync -ai --backup --backup-dir="$backup_root/vault-tasks" \
    "$project_root/tasks/" "$vault_dir/tasks/"

  git_commit_post_sync "$slug"
  cleanup_old_backups "$project_root"

  log "push completed for slug=$slug backup_root=$backup_root"
  (( changed == 1 )) && log "plan changed during push" || true
}

case "$COMMAND" in
  pull)
    pull_cmd
    ;;
  push)
    push_cmd
    ;;
  unlock)
    [[ "$ARG1" == "--force" ]] || usage
    [[ -n "$ARG2" ]] || usage
    unlock_force "$ARG2"
    ;;
  *)
    usage
    ;;
esac
```

## 2. SessionStart hook

保存先: `~/.claude/hooks/vault-sync-sessionstart.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "${CCSYNC_DISABLE:-0}" == "1" ]]; then
  echo "[vault-sync][SessionStart] DISABLED via CCSYNC_DISABLE=1" >&2
  exit 0
fi

cat >/dev/null || true

PROJECT_ROOT="$HOME/Desktop/prm/salesmtg"
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
```

## 3. Stop hook

保存先: `~/.claude/hooks/vault-sync-stop.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "${CCSYNC_DISABLE:-0}" == "1" ]]; then
  echo "[vault-sync][Stop] DISABLED via CCSYNC_DISABLE=1" >&2
  exit 0
fi

cat >/dev/null || true

PROJECT_ROOT="$HOME/Desktop/prm/salesmtg"
SYNCCTL="$HOME/.claude/bin/syncctl"

REAL_PWD="$(cd "${PWD:-.}" 2>/dev/null && pwd -P || echo "")"
REAL_PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P || echo "")"

if [[ "$REAL_PWD" != "$REAL_PROJECT_ROOT" ]]; then
  exit 0
fi

if [[ ! -x "$SYNCCTL" ]]; then
  echo "[vault-sync][Stop] syncctl not executable: $SYNCCTL" >&2
  exit 1
fi

echo "[vault-sync][Stop] push start" >&2
cd "$PROJECT_ROOT"
"$SYNCCTL" push
echo "[vault-sync][Stop] push done" >&2
```

## 4. bootstrap

保存先: `~/.claude/bin/bootstrap-vault-sync-salesmtg.sh`
（as-built 注記・2026-07-10: 実装済み実体は `~/.claude/bin/bootstrap-vault-sync-report.sh`（`SLUG="report"`）。salesmtg 版は未作成のまま、report プロジェクト向けとして稼働している）

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${OBSIDIAN_VAULT_PATH:=$HOME/Documents/Obsidian Vault}"

SLUG="salesmtg"
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
# salesmtg plan

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
```

## 5. `restrict-cwd-edits.sh` 改修版

保存先: `~/.claude/hooks/restrict-cwd-edits.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat || true)"

deny() {
  local reason="$1"
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$reason"}}
EOF
  exit 0
}

extract_json_field() {
  local expr="$1"
  python3 -c "
import json, sys, os
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.exit(10)

value = data
for part in '$expr'.split('.'):
    if isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break

if value is None:
    sys.exit(11)

print(os.path.realpath(value))
" <<<"$INPUT"
}

FILE_PATH=""
CWD=""

if ! FILE_PATH="$(extract_json_field 'tool_input.file_path' 2>/dev/null)"; then
  if ! FILE_PATH="$(extract_json_field 'tool_input.filePath' 2>/dev/null)"; then
    deny "Edit blocked: unable to parse tool_input.file_path from hook payload (fail-secure)"
  fi
fi

if ! CWD="$(extract_json_field 'cwd' 2>/dev/null)"; then
  deny "Edit blocked: unable to parse cwd from hook payload (fail-secure)"
fi

[[ -n "$FILE_PATH" ]] || deny "Edit blocked: empty file_path (fail-secure)"
[[ -n "$CWD" ]] || deny "Edit blocked: empty cwd (fail-secure)"

if [[ "$FILE_PATH" == "$HOME/.claude/"* ]]; then
  exit 0
fi

OBSIDIAN_VAULT="$HOME/Documents/Obsidian Vault/"
if [[ "$FILE_PATH" == "$OBSIDIAN_VAULT"* ]]; then
  exit 0
fi

PRM_DIR="$HOME/Desktop/prm/"
BIZ_DIR="$HOME/Desktop/biz/"

ALLOWED_PROJECTS=("salesmtg")
allowed=false
for proj in "${ALLOWED_PROJECTS[@]}"; do
  if [[ "$FILE_PATH" == "$PRM_DIR$proj/"* ]]; then
    allowed=true
    break
  fi
done
if [[ "$allowed" == "true" ]]; then
  exit 0
fi

ALLOWED_BIZ_PROJECTS=()
allowed_biz=false
for proj in "${ALLOWED_BIZ_PROJECTS[@]:-}"; do
  if [[ -n "$proj" && "$FILE_PATH" == "$BIZ_DIR$proj/"* ]]; then
    allowed_biz=true
    break
  fi
done
if [[ "$allowed_biz" == "true" ]]; then
  exit 0
fi

CWD_PREFIX="${CWD}/"
if [[ "$FILE_PATH" == "$CWD_PREFIX"* ]] || [[ "$FILE_PATH" == "$CWD" ]]; then
  exit 0
fi

deny "Edit blocked: File outside CWD. Attempted: $FILE_PATH, Project: $CWD"
```

## 6. v2 → v2.1 差分サマリ

| 項目 | v2 | v2.1 |
|---|---|---|
| `rsync` 失敗処理 | `\|\| true` で握り潰し | `run_rsync_checked` で exit code 厳密評価・失敗で die |
| 緊急停止 | なし | `CCSYNC_DISABLE=1` を syncctl/hook 全冒頭に追加 |
| bootstrap settings.json | 直接 write_text | `.bak-<ts>` 退避 + tmp file + `os.replace` |
| hook の cwd 判定 | `PWD` 文字列比較 | `pwd -P` realpath 比較 |
| `restrict-cwd-edits.sh` | `~/Desktop/prm/` 全許可 | `ALLOWED_PROJECTS=("salesmtg")` allowlist |
| pull 前 snapshot | push のみ | pull/push 両方で `git_snapshot_pre_sync` |
| backup-dir 清掃 | なし | `find -ctime +7 -exec rm -rf` 7日保持 |
| vault git commit 競合 | lock なし | `.git/ccsync.lock` mkdir lock + `.gitignore` 追加 |
| 成功基準7 文言 | frontmatter 改竄試験 | コード固定の静的確認 |
| ロールバック手順 | `rm -rf tasks` 直接 | `cp -rp tasks tasks.rollback-<ts>` 退避先行 |

## 7. 成功基準 8 項目（修正済）

1. SessionStart 時に `syncctl pull` が 1 回だけ走る
2. Stop 時に `syncctl push` が 1 回だけ走り、PostToolUse では一切 push されない
3. `vault/tasks` または `project/tasks` が空のとき同期は abort し、既存 mirror は 1 件も消えない
4. stale lock 作成後 900 秒経過した状態では pull/push が失敗し `syncctl unlock --force salesmtg` を要求
5. pull/push 両方で同期前に vault git に `pre-sync snapshot: salesmtg ...` commit が残る、または lock 競合時は `skipping commit` が stderr に出る
6. salesmtg 以外の project root で hook が発火しても no-op
7. vault 書込先が `resolve_vault_project_dir(slug)` でコード固定、frontmatter は syncctl から参照されないことを静的確認
8. `restrict-cwd-edits.sh` の JSON パース失敗時に deny へ倒れ、`~/Desktop/prm/salesmtg/` 以外は自動許可されない

## 8. ロールバック手順（修正済）

```bash
# 1. 緊急停止（即時）
export CCSYNC_DISABLE=1

# 2. settings.json から hook 2エントリを手動削除（バックアップは .bak-<ts> あり）

# 3. project 側を退避してから削除
cd ~/Desktop/prm/salesmtg
cp -rp tasks "tasks.rollback-$(date +%s)" 2>/dev/null || true
rm -rf .ccsync
rm -f plan.md
rm -rf tasks

# 4. vault 側を git revert
git -C "$HOME/Documents/Obsidian Vault" log --oneline -- projects/salesmtg
git -C "$HOME/Documents/Obsidian Vault" revert <sync-commit-sha>

# 5. lock 清掃
~/.claude/bin/syncctl unlock --force salesmtg
```

## 9. Phase 2/3

**Phase 2**: COMMAND-CENTER 正式仕様 / switch-project / promote-knowledge / rules/40 改訂 / 142件 archive 移動の承認ゲート
**Phase 3**: 全 prm/<slug>/ 横展開 / promotion 自動化 / shared wiki 連携 / cross-project dashboard
