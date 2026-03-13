#!/bin/bash
# Claudeの最下部のステータスバーをリッチにするための設定集

# 各種場所
CLAUDE_DIR="$HOME/.claude"
USAGE_LOG="$CLAUDE_DIR/.sl_usage_log.csv"
LIVE_DIR="$CLAUDE_DIR/.sl_live"
CACHE_DIR="$HOME/.cache/claude-statusline"
USAGE_CACHE="$CACHE_DIR/usage.json"
CACHE_TTL=180  # 3 minutes
mkdir -p "$LIVE_DIR" "$CACHE_DIR"

input=$(cat)

# Debug: save last received stdin for troubleshooting
echo "$input" > "$CACHE_DIR/last_stdin.json" 2>/dev/null

# 各種情報を取得
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

# 各種計算
# current_usage.input_tokens を優先 (現在のコンテキストの実際のトークン数)
# なければ used_percentage から逆算、それもなければ total の合算をフォールバック
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
cur_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
used_tokens=$((input_tokens + output_tokens))

if [ -n "$cur_input" ] && [ -n "$cur_output" ]; then
  current_used=$((cur_input + cur_output))
elif [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  current_used=$(awk "BEGIN {printf \"%.0f\", ($used_pct * $context_size) / 100}")
else
  current_used=$((input_tokens + output_tokens))
  [ "$current_used" -gt "$context_size" ] && current_used=$context_size
fi

# used_pct を整数として再計算 (バー描画用)
if [ "$context_size" -gt 0 ]; then
  used_pct=$(awk "BEGIN {printf \"%.1f\", ($current_used / $context_size) * 100}")
else
  used_pct=0
fi

remaining_tokens=$((context_size - current_used))
[ "$remaining_tokens" -lt 0 ] && remaining_tokens=0
current_time=$(date +%s)

# Git branch
git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")

# Format number with k/M suffix
fmt() {
  local n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1fk\", $n/1000}"
  else
    echo "${n:-0}"
  fi
}

# Initialize usage log
[ ! -f "$USAGE_LOG" ] && echo "ts,sid,tokens" >"$USAGE_LOG"

# Per-session live state file
LIVE_FILE="$LIVE_DIR/${session_id}.json"

# Session tracking
turn_count=1
compress_count=0

if [ -f "$LIVE_FILE" ]; then
  last_ctx=$(jq -r '.ctx // 0' "$LIVE_FILE" 2>/dev/null)
  last_turns=$(jq -r '.turns // 0' "$LIVE_FILE" 2>/dev/null)
  s_start=$(jq -r '.start // 0' "$LIVE_FILE" 2>/dev/null)
  compress_count=$(jq -r '.compress // 0' "$LIVE_FILE" 2>/dev/null)
  compress_last=$(jq -r '.compress_last // 0' "$LIVE_FILE" 2>/dev/null)

  if [ "$current_used" -ne "${last_ctx:-0}" ]; then
    turn_count=$((last_turns + 1))
  else
    turn_count=$last_turns
  fi

  if [ "${compress_last:-0}" -gt 0 ] && [ "$current_used" -gt 0 ]; then
    drop=$((compress_last - current_used))
    threshold=$((compress_last / 5))
    if [ "$drop" -gt "$threshold" ] && [ "$drop" -gt 10000 ]; then
      compress_count=$((compress_count + 1))
    fi
  fi
else
  s_start=$current_time
fi

printf '{"tok":%d,"ctx":%d,"ts":%d,"turns":%d,"start":%d,"compress":%d,"compress_last":%d}' \
  "$used_tokens" "$current_used" "$current_time" "$turn_count" "$s_start" \
  "$compress_count" "$current_used" >"$LIVE_FILE"

# ── Quota API (cached) ──
_fetch_usage() {
  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  [ -z "$token" ] && return 1
  curl -sf --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" >"$USAGE_CACHE.tmp" 2>/dev/null && \
    mv "$USAGE_CACHE.tmp" "$USAGE_CACHE"
}

# Refresh cache if stale
if [ -f "$USAGE_CACHE" ]; then
  cache_age=$((current_time - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0)))
  [ "$cache_age" -ge "$CACHE_TTL" ] && _fetch_usage
else
  _fetch_usage
fi

# Parse quota data
five_h_pct=0; five_h_reset="--"; seven_d_pct=0; seven_d_reset="--"
if [ -f "$USAGE_CACHE" ]; then
  five_h_pct=$(jq -r '.five_hour.utilization // 0' "$USAGE_CACHE" 2>/dev/null)
  seven_d_pct=$(jq -r '.seven_day.utilization // 0' "$USAGE_CACHE" 2>/dev/null)
  five_h_reset_raw=$(jq -r '.five_hour.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)
  seven_d_reset_raw=$(jq -r '.seven_day.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)

  # Calculate time until reset (handles ISO 8601 with timezone)
  _time_until() {
    local iso=$1
    [ -z "$iso" ] && echo "--" && return
    local reset_ts
    # Try GNU date first, then macOS date with manual TZ offset handling
    reset_ts=$(date -d "$iso" +%s 2>/dev/null)
    if [ -z "$reset_ts" ]; then
      # macOS: strip fractional seconds, parse UTC portion, adjust for TZ offset
      local dt_part=$(echo "$iso" | sed 's/\.[^+-]*//')
      local base_dt=$(echo "$dt_part" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
      local tz_sign=$(echo "$dt_part" | grep -o '[+-][0-9][0-9]:[0-9][0-9]$' | head -c1)
      local tz_h=$(echo "$dt_part" | grep -o '[+-][0-9][0-9]:[0-9][0-9]$' | sed 's/^[+-]//;s/:.*//')
      local tz_m=$(echo "$dt_part" | grep -o '[+-][0-9][0-9]:[0-9][0-9]$' | sed 's/^[+-][0-9][0-9]://')
      reset_ts=$(date -juf "%Y-%m-%dT%H:%M:%S" "$base_dt" +%s 2>/dev/null)
      if [ -n "$reset_ts" ] && [ -n "$tz_sign" ]; then
        local tz_offset_sec=$(( (10#${tz_h:-0} * 3600) + (10#${tz_m:-0} * 60) ))
        [ "$tz_sign" = "+" ] && reset_ts=$((reset_ts - tz_offset_sec)) || reset_ts=$((reset_ts + tz_offset_sec))
      fi
    fi
    [ -z "$reset_ts" ] && echo "--" && return
    local diff=$((reset_ts - current_time))
    [ "$diff" -le 0 ] && echo "now" && return
    local h=$((diff / 3600)) m=$(( (diff % 3600) / 60 ))
    [ "$h" -gt 0 ] && echo "${h}h${m}m" || echo "${m}m"
  }
  five_h_reset=$(_time_until "$five_h_reset_raw")
  seven_d_reset=$(_time_until "$seven_d_reset_raw")
fi

# Build quota progress bars (5 chars each)
_mini_bar() {
  local pct_val=$1 width=5
  local filled_n=$(awk "BEGIN {printf \"%.0f\", ($pct_val / 100) * $width}")
  [ "$filled_n" -gt "$width" ] && filled_n=$width
  local empty_n=$((width - filled_n))
  local b=""
  for ((i = 0; i < filled_n; i++)); do b+="█"; done
  for ((i = 0; i < empty_n; i++)); do b+="░"; done
  echo "$b"
}
five_h_int=$(awk "BEGIN {printf \"%.0f\", ${five_h_pct:-0}}")
seven_d_int=$(awk "BEGIN {printf \"%.0f\", ${seven_d_pct:-0}}")
five_h_bar=$(_mini_bar "$five_h_int")
seven_d_bar=$(_mini_bar "$seven_d_int")

# Context window bar
ctx_pct_int=$(awk "BEGIN {printf \"%.0f\", ${used_pct:-0}}")
ctx_bar=$(_mini_bar "$ctx_pct_int")

# Periodic cleanup
if [ $((RANDOM % 50)) -eq 0 ]; then
  if [ -f "$USAGE_LOG" ]; then
    cutoff=$((current_time - 7776000))
    tmp="$USAGE_LOG.tmp"
    head -1 "$USAGE_LOG" >"$tmp"
    tail -n +2 "$USAGE_LOG" | awk -F, -v c="$cutoff" '$1 >= c' >>"$tmp"
    mv "$tmp" "$USAGE_LOG"
  fi

  stale_cutoff=$((current_time - 172800))
  for lf in "$LIVE_DIR"/*.json; do
    [ -f "$lf" ] || continue
    [ "$lf" = "$LIVE_FILE" ] && continue
    live_ts=$(jq -r '.ts // 0' "$lf" 2>/dev/null)
    if [ "${live_ts:-0}" -lt "$stale_cutoff" ] 2>/dev/null; then
      stale_tok=$(jq -r '.tok // 0' "$lf" 2>/dev/null)
      stale_sid=$(basename "$lf" .json)
      [ "$stale_tok" -gt 0 ] 2>/dev/null && echo "$live_ts,$stale_sid,$stale_tok" >>"$USAGE_LOG"
      rm -f "$lf"
    fi
  done

  rm -f "$CLAUDE_DIR/.sl_session.json" "$CLAUDE_DIR/.sl_last_state.json" "$CLAUDE_DIR/.sl_compress.json" 2>/dev/null
fi

# Output (1 line): model | context | 5h | 7d | git branch
printf "🤖 %s │ 📊 %s/%s │ ⏱5h %s %d%%(%s) 📅7d %s %d%%(%s) │ 🔀 %s" \
  "$model" \
  "$(fmt $current_used)" \
  "$(fmt $context_size)" \
  "$five_h_bar" \
  "$five_h_int" \
  "$five_h_reset" \
  "$seven_d_bar" \
  "$seven_d_int" \
  "$seven_d_reset" \
  "$git_branch"
