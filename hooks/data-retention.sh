#!/bin/bash
# data-retention.sh - Automated data retention cleanup for ~/.claude/
# Safe to run on every session start. Idempotent.
#
# Retention policies:
#   debug/          - 14 days
#   session-env/    - 7 days
#   todos/          - 90 days
#   tasks/          - 30 days
#   file-history/   - 60 days
#   shell-snapshots/ - 30 days

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
LOG_PREFIX="[data-retention]"

log() {
    echo "${LOG_PREFIX} $*" >&2
}

cleanup_files() {
    local dir="$1"
    local days="$2"
    local label="$3"

    if [[ ! -d "${dir}" ]]; then
        return
    fi

    local count
    count=$(find "${dir}" -type f -mtime +"${days}" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "${count}" -gt 0 ]]; then
        find "${dir}" -type f -mtime +"${days}" -delete 2>/dev/null
        find "${dir}" -type d -empty -delete 2>/dev/null
        log "${label}: deleted ${count} files older than ${days} days"
    fi
}

cleanup_dirs() {
    local dir="$1"
    local days="$2"
    local label="$3"

    if [[ ! -d "${dir}" ]]; then
        return
    fi

    local count
    count=$(find "${dir}" -mindepth 1 -maxdepth 1 -type d -mtime +"${days}" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "${count}" -gt 0 ]]; then
        find "${dir}" -mindepth 1 -maxdepth 1 -type d -mtime +"${days}" -exec rm -rf {} + 2>/dev/null
        log "${label}: deleted ${count} directories older than ${days} days"
    fi
}

# 1. debug/ - Delete files older than 14 days
cleanup_files "${CLAUDE_DIR}/debug" 14 "debug"

# 2. session-env/ - Delete directories older than 7 days
cleanup_dirs "${CLAUDE_DIR}/session-env" 7 "session-env"

# 3. todos/ - Delete files older than 90 days
cleanup_files "${CLAUDE_DIR}/todos" 90 "todos"

# 4. tasks/ - Delete directories older than 30 days
cleanup_dirs "${CLAUDE_DIR}/tasks" 30 "tasks"

# 5. file-history/ - Delete files older than 60 days
cleanup_files "${CLAUDE_DIR}/file-history" 60 "file-history"

# 6. shell-snapshots/ - Delete files older than 30 days
cleanup_files "${CLAUDE_DIR}/shell-snapshots" 30 "shell-snapshots"

# 7. projects/ - Delete session data (*.jsonl and UUID dirs) older than 14 days
#    Preserves: memory/, CLAUDE.md, settings.json, sessions-index.json
cleanup_project_sessions() {
    local projects_dir="${CLAUDE_DIR}/projects"

    if [[ ! -d "${projects_dir}" ]]; then
        return
    fi

    local count=0
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

    # Delete old .jsonl session files (UUID-named only)
    while IFS= read -r -d '' file; do
        local basename
        basename=$(basename "${file}" .jsonl)
        if [[ "${basename}" =~ ${uuid_regex} ]]; then
            rm -f "${file}" 2>/dev/null
            ((count++)) || true
        fi
    done < <(find "${projects_dir}" -maxdepth 2 -name "*.jsonl" -type f -mtime +14 -print0 2>/dev/null)

    # Delete old UUID session directories (contain subagents/, tool-results/, etc.)
    while IFS= read -r -d '' dir; do
        local dirname
        dirname=$(basename "${dir}")
        if [[ "${dirname}" =~ ${uuid_regex} ]]; then
            rm -rf "${dir}" 2>/dev/null
            ((count++)) || true
        fi
    done < <(find "${projects_dir}" -mindepth 2 -maxdepth 2 -type d -mtime +14 -print0 2>/dev/null)

    if [[ "${count}" -gt 0 ]]; then
        log "projects/sessions: deleted ${count} session files/dirs older than 14 days"
    fi
}

cleanup_project_sessions

# 8. telemetry/ - Delete files older than 14 days
cleanup_files "${CLAUDE_DIR}/telemetry" 14 "telemetry"

# 9. backups/ - Delete files older than 7 days
cleanup_files "${CLAUDE_DIR}/backups" 7 "backups"

# 9b. state/precompact-backups/ - Delete snapshot directories older than 7 days
# (PreCompact hook が作る 1 セッション単位の state snapshot が無限蓄積するのを防ぐ)
if [[ -d "${CLAUDE_DIR}/state/precompact-backups" ]]; then
    find "${CLAUDE_DIR}/state/precompact-backups" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
    log "precompact-backups: purged snapshots older than 7 days"
fi

# 10. plans/ - Delete plan files older than 14 days
cleanup_files "${CLAUDE_DIR}/plans" 14 "plans"

# 11. cache/ - Delete cache files older than 7 days
cleanup_files "${CLAUDE_DIR}/cache" 7 "cache"

# 12. Ephemeral mid-session state (should not persist across sessions)
for ephemeral_file in \
    "${CLAUDE_DIR}/state/verify-step.pending" \
    "${CLAUDE_DIR}/state/fix-retry-count" \
    "${CLAUDE_DIR}/state/fix-last-file" \
    "${CLAUDE_DIR}/state/skill-review.done" \
    "${CLAUDE_DIR}/state/needs-simplify.pending" \
    "${CLAUDE_DIR}/state/simplify-snapshot" \
    "${CLAUDE_DIR}/state/simplify-iteration" \
    "${CLAUDE_DIR}/state/fe-browser-verified.done" \
    "${CLAUDE_DIR}/state/plan-readiness.done" \
    "${CLAUDE_DIR}/state/plan-files-snapshot.txt" \
    "${CLAUDE_DIR}/state/improvement-capture.done"; do
    if [[ -f "${ephemeral_file}" ]]; then
        rm -f "${ephemeral_file}"
        log "ephemeral-state: removed $(basename "${ephemeral_file}")"
    fi
done
