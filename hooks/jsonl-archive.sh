#!/bin/bash
# jsonl-archive.sh — preserve ~/.claude/projects/*.jsonl before data-retention.sh (14-day) deletes them.
#
# Why: data-retention.sh removes JSONLs older than 14 days, but fact-check-from-history skill
#      needs longer history for environment-based article verification.
# How: At SessionStart, hardlink JSONLs older than PRESERVE_AFTER_DAYS to ~/.claude/archives/jsonl/.
#      Hardlinks cost zero disk until originals are deleted. After deletion, archive is sole owner.
# Why SessionStart (not launchd): retention deletion runs at SessionStart, so preservation must
#      run in the same lifecycle. launchd misses events when Mac is asleep.

set -euo pipefail

SRC="${HOME}/.claude/projects"
DST="${HOME}/.claude/archives/jsonl"
PRESERVE_AFTER_DAYS=5

[ ! -d "${SRC}" ] && exit 0

mkdir -p "${DST}"

added=0
skipped=0

while IFS= read -r -d '' f; do
    rel="${f#${SRC}/}"
    dst_file="${DST}/${rel}"
    if [ -e "${dst_file}" ]; then
        skipped=$((skipped + 1))
        continue
    fi
    mkdir -p "$(dirname "${dst_file}")"
    if ln "${f}" "${dst_file}" 2>/dev/null; then
        added=$((added + 1))
    elif cp -p "${f}" "${dst_file}" 2>/dev/null; then
        added=$((added + 1))
    fi
done < <(find "${SRC}" -name "*.jsonl" -type f -mtime +${PRESERVE_AFTER_DAYS} -print0 2>/dev/null)

if [ "${added}" -gt 0 ]; then
    echo "[jsonl-archive] preserved=${added} skipped=${skipped} dst=${DST}" >&2
fi

exit 0
