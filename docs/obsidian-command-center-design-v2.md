# v2 設計: Phase 1 MVP (`salesmtg` のみ)

## 0. Phase 1 の範囲
Phase 1 は以下だけです。

- `syncctl pull`
- `syncctl push`
- `syncctl unlock --force`（障害復旧用）
- `SessionStart` で 1 回 `pull`
- `Stop` で 1 回 `push`
- atomic lock (`mkdir` ベース)
- vault git snapshot
- slug 検証
- パストラバーサル遮断
- `restrict-cwd-edits.sh` の fail-secure 化

Phase 1 では以下に**触りません**。

- 既存 `wiki/`
- 既存 `refs/`
- 既存 142 件ノート
- `obsidian-now-done`
- `rules/40` の不変ルール変更
- `COMMAND-CENTER` 本格仕様
- `switch-project`
- `promote-knowledge`

---

## 1. 配置

### 1.1 追加ファイル
- `~/.claude/bin/syncctl`
- `~/.claude/bin/bootstrap-vault-sync-salesmtg.sh`
- `~/.claude/hooks/vault-sync-sessionstart.sh`
- `~/.claude/hooks/vault-sync-stop.sh`

### 1.2 vault 側 Phase 1 パス
- `~/Documents/Obsidian Vault/projects/salesmtg/COMMAND-CENTER/plan.md`
- `~/Documents/Obsidian Vault/projects/salesmtg/COMMAND-CENTER/tasks/`

### 1.3 project 側 Phase 1 パス
- `~/Desktop/prm/salesmtg/plan.md`
- `~/Desktop/prm/salesmtg/tasks/`
- `~/Desktop/prm/salesmtg/.ccsync/`

---

## 2. `syncctl` 全文

保存先: `~/.claude/bin/syncctl`

```bash
#!/usr/bin/env bash
set -euo pipefail

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

git_snapshot_pre_sync() {
  local slug="$1"

  git -C "$OBSIDIAN_VAULT_PATH" add "projects/$slug" >/dev/null
  git_commit_if_staged "$OBSIDIAN_VAULT_PATH" "pre-sync snapshot: $slug $(date "$DATE_FMT")" || true
}

git_commit_post_sync() {
  local slug="$1"

  git -C "$OBSIDIAN_VAULT_PATH" add "projects/$slug" >/dev/null
  git_commit_if_staged "$OBSIDIAN_VAULT_PATH" "sync mirror: $slug $(date "$DATE_FMT")" || true
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

pull_cmd() {
  local project_root slug vault_dir backup_root changed=0
  project_root="$(project_root_from_cwd)"
  slug="$(slug_from_project_root "$project_root")"
  require_salesmtg_only "$slug"

  vault_dir="$(resolve_vault_project_dir "$slug")"
  assert_vault_target_safe "$slug" "$vault_dir"
  ensure_vault_git_repo
  ensure_paths_exist_for_pull "$vault_dir"
  ensure_project_ccsync_dirs "$project_root"

  acquire_lock "$slug" "$project_root"

  backup_root="$(backup_root_for_run "$project_root")"
  mkdir -p "$backup_root/tasks"

  print_dry_run_plan_change "$vault_dir/plan.md" "$project_root/plan.md"
  rsync -ani --backup --backup-dir="$backup_root/tasks" \
    "$vault_dir/tasks/" "$project_root/tasks/" | sed 's/^/[syncctl][dry-run][pull][tasks] /' >&2 || true

  if backup_file_if_changed \
    "$vault_dir/plan.md" \
    "$project_root/plan.md" \
    "$backup_root/plan.md"; then
    changed=1
    log "plan.md updated from vault"
  fi

  rsync -ai --backup --backup-dir="$backup_root/tasks" \
    "$vault_dir/tasks/" "$project_root/tasks/" | sed 's/^/[syncctl][pull][tasks] /' >&2 || true

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
  rsync -ani --backup --backup-dir="$backup_root/vault-tasks" \
    "$project_root/tasks/" "$vault_dir/tasks/" | sed 's/^/[syncctl][dry-run][push][tasks] /' >&2 || true

  git_snapshot_pre_sync "$slug"

  if backup_file_if_changed \
    "$project_root/plan.md" \
    "$vault_dir/plan.md" \
    "$backup_root/vault-plan/plan.md"; then
    changed=1
    log "plan.md updated into vault"
  fi

  rsync -ai --backup --backup-dir="$backup_root/vault-tasks" \
    "$project_root/tasks/" "$vault_dir/tasks/" | sed 's/^/[syncctl][push][tasks] /' >&2 || true

  git_commit_post_sync "$slug"

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

---

## 3. SessionStart hook 全文

保存先: `~/.claude/hooks/vault-sync-sessionstart.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

cat >/dev/null || true

PROJECT_ROOT="$HOME/Desktop/prm/salesmtg"
SYNCCTL="$HOME/.claude/bin/syncctl"

if [[ "${PWD:-}" != "$PROJECT_ROOT" ]]; then
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

---

## 4. Stop hook 全文

保存先: `~/.claude/hooks/vault-sync-stop.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

cat >/dev/null || true

PROJECT_ROOT="$HOME/Desktop/prm/salesmtg"
SYNCCTL="$HOME/.claude/bin/syncctl"

if [[ "${PWD:-}" != "$PROJECT_ROOT" ]]; then
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

---

## 5. bootstrap 最小版 全文

保存先: `~/.claude/bin/bootstrap-vault-sync-salesmtg.sh`

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
import json, sys, pathlib

settings_path = pathlib.Path(sys.argv[1])
sessionstart_hook = sys.argv[2]
stop_hook = sys.argv[3]

data = json.loads(settings_path.read_text())
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

settings_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY

git -C "$OBSIDIAN_VAULT_PATH" add "projects/$SLUG" >/dev/null
git -C "$OBSIDIAN_VAULT_PATH" commit -m "bootstrap vault sync: $SLUG" >/dev/null || true

echo "[bootstrap] complete"
echo "[bootstrap] next: cd \"$PROJECT_ROOT\" && \"$SYNCCTL\" pull"
```

---

## 6. `restrict-cwd-edits.sh` fail-secure 修正版

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
if [[ "$FILE_PATH" == "$PRM_DIR"* ]] || [[ "$FILE_PATH" == "$BIZ_DIR"* ]]; then
  exit 0
fi

CWD_PREFIX="${CWD}/"
if [[ "$FILE_PATH" == "$CWD_PREFIX"* ]] || [[ "$FILE_PATH" == "$CWD" ]]; then
  exit 0
fi

deny "Edit blocked: File outside CWD. Attempted: $FILE_PATH, Project: $CWD"
```

---

## 7-13: 設定差分・atomic lock 要点・pull/push 安全策・slug 検証・成功基準・ロールバック・Phase 2/3

(原文のまま、長文のため省略 — codex 出力を参照)

## 11. Phase 1 成功基準（観測可能）
1. `~/Desktop/prm/salesmtg` で SessionStart 時に `syncctl pull` が 1 回だけ走る
2. Stop 時に `syncctl push` が 1 回だけ走り、`PostToolUse` では一切 push されない
3. `vault/tasks` または `project/tasks` が空のとき同期は abort し、既存 mirror は 1 件も消えない
4. stale lock 作成後 900 秒経過した状態では `pull` も `push` も失敗し、`syncctl unlock --force salesmtg` を要求する
5. push 前に vault git に `pre-sync snapshot: salesmtg ...` commit が残る
6. `salesmtg` 以外の project root で hook が発火しても no-op になる
7. frontmatter を改竄しても vault 書込先は変わらず、`projects/salesmtg/COMMAND-CENTER` に固定される
8. `restrict-cwd-edits.sh` の JSON パース失敗時に deny へ倒れる

## 12. Phase 1 ロールバック手順
1. `settings.json` から sessionstart/stop hook 2エントリ削除
2. `cd ~/Desktop/prm/salesmtg && rm -rf .ccsync plan.md tasks`
3. `git -C "$HOME/Documents/Obsidian Vault" log --oneline -- projects/salesmtg` → `git revert <sha>`
4. `~/.claude/bin/syncctl unlock --force salesmtg`

## 13. Phase 2/3 で初めて触る項目
**Phase 2**: COMMAND-CENTER 正式フォーマット / switch-project / promote-knowledge / rules/40 改訂 / 142件 archive 移動の承認ゲート
**Phase 3**: 全 prm/<slug>/ 横展開 / promotion 自動化 / shared wiki 連携 / cross-project dashboard
