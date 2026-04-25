#!/bin/bash
# Hook profiler wrapper.
# Usage in settings.json:  ~/.claude/hooks/_profile-wrapper.sh <real-hook-path>
#
# Logs each hook's wall-clock duration + exit code to ~/.claude/state/hook-profiling.jsonl
# Stdin/stdout/stderr/exit_code are passed through transparently to the wrapped hook.
# Logging failures must never break the hook chain.

set -u
real_hook="$1"
shift

# perl Time::HiRes for sub-ms timing; ~5-10ms perl startup is acceptable.
start_epoch=$(perl -MTime::HiRes=time -e 'printf "%.6f\n", time')

"$real_hook" "$@"
exit_code=$?

end_epoch=$(perl -MTime::HiRes=time -e 'printf "%.6f\n", time')
duration_ms=$(perl -e "printf \"%d\", ($end_epoch - $start_epoch) * 1000")

# Best-effort logging — swallow all errors.
{
    log_dir="$HOME/.claude/state"
    mkdir -p "$log_dir" 2>/dev/null
    log_file="$log_dir/hook-profiling.jsonl"
    hook_name=$(basename "$real_hook")
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cwd_escaped=$(pwd | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"ts":"%s","hook":"%s","duration_ms":%s,"exit_code":%s,"cwd":"%s"}\n' \
        "$ts" "$hook_name" "$duration_ms" "$exit_code" "$cwd_escaped" >> "$log_file"
} 2>/dev/null || true

exit $exit_code
