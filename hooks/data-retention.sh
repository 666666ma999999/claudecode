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

# 7. projects/ - Archive session prompt logs (*.jsonl) older than 14 days,
#    delete only the heavy UUID session dirs (subagents/tool-results).
#    Preserves: memory/, CLAUDE.md, settings.json, sessions-index.json
#    Archive dir is chmod 700 + gitignored (may contain plaintext tokens until rotated).
#    (bunshin v1 Phase 0 / T1 2026-07-02: rm -f jsonl -> mv to archives/jsonl)
cleanup_project_sessions() {
    local projects_dir="${CLAUDE_DIR}/projects"

    if [[ ! -d "${projects_dir}" ]]; then
        return
    fi

    local count=0
    local archived=0
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    local archive_dir="${CLAUDE_DIR}/archives/jsonl"
    mkdir -p "${archive_dir}" 2>/dev/null
    chmod 700 "${CLAUDE_DIR}/archives" "${archive_dir}" 2>/dev/null

    # Archive old .jsonl session files (UUID-named only) instead of deleting
    while IFS= read -r -d '' file; do
        local basename
        basename=$(basename "${file}" .jsonl)
        if [[ "${basename}" =~ ${uuid_regex} ]]; then
            local projdir dest
            projdir=$(basename "$(dirname "${file}")")
            dest="${archive_dir}/${projdir}"
            mkdir -p "${dest}" 2>/dev/null
            # -n: never overwrite an already-archived copy. Fallback deletes the
            # projects/ source ONLY (never the archive side) if a copy exists there.
            mv -n "${file}" "${dest}/" 2>/dev/null || true
            if [[ -e "${file}" && -e "${dest}/$(basename "${file}")" ]]; then
                rm -f "${file}" 2>/dev/null
            fi
            [[ ! -e "${file}" ]] && ((archived++)) || true
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
        log "projects/sessions: archived ${archived} jsonl to archives/jsonl, processed ${count} files/dirs older than 14 days"
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
    "${CLAUDE_DIR}/state/plan-strategy.json" \
    "${CLAUDE_DIR}/state/improvement-capture.done"; do
    if [[ -f "${ephemeral_file}" ]]; then
        rm -f "${ephemeral_file}"
        log "ephemeral-state: removed $(basename "${ephemeral_file}")"
    fi
done

# 13. Append-only observability logs - cap to last N lines when oversized.
#     (profiling/stop/capture ログは edit 毎に無制限増殖するが、正しさを依存する
#      消費者がいない。improvement-queue.jsonl 等の機能キューは意図的に除外。)
#     best-effort: SessionStart 中の並行追記で末尾数行を失う可能性は許容。
cap_log() {
    local file="$1" max_bytes="$2" keep_lines="$3" label="$4"
    [[ -f "${file}" ]] || return 0
    local size
    size=$(stat -f%z "${file}" 2>/dev/null || echo 0)
    if [[ "${size}" -gt "${max_bytes}" ]]; then
        local tmp="${file}.captmp"
        if tail -n "${keep_lines}" "${file}" > "${tmp}" 2>/dev/null; then
            mv "${tmp}" "${file}"
            log "${label}: capped to last ${keep_lines} lines (was $((size/1048576))MB)"
        else
            rm -f "${tmp}" 2>/dev/null || true
        fi
    fi
}
cap_log "${CLAUDE_DIR}/state/hook-profiling.jsonl" 2097152 5000 "hook-profiling"
cap_log "${CLAUDE_DIR}/state/subagent-stops.log"   2097152 3000 "subagent-stops"
cap_log "${CLAUDE_DIR}/state/auto-capture.log"     2097152 3000 "auto-capture"
