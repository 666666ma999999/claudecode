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
