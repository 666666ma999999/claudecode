#!/usr/bin/env bash
# userprompt-goal-inject.sh — UserPromptSubmit hook (the core fix).
#
# Injects the current 1-line session goal into Claude's context EVERY turn, so the
# goal lives in the model's context window — not only on the human-facing statusline
# (which the model never reads). This is the fix for "the AI drifts from / forgets
# the goal" on long / multi-day sessions. stdout IS injected into context (same
# mechanism proven by wiki-recall-on-prompt.sh / userprompt-routing-inject.sh).
#
# Detection of "goal changed" is left to the model (option B): it sees the goal +
# the live work each turn and is told to confirm on divergence. No fragile auto
# heuristic. Application of a change is the explicit `/session-goal "新目標"`.
#
# - Goal set   -> inject header + goal (truncated ~100 chars, NOT full text, so we
#                 don't pollute context / worsen context-rot) + a 1-line B reminder.
# - Goal unset -> only on a substantive (task-verb) prompt, nudge to set one.
#                 Silent on chat / short prompts. Never hard-blocks.

set -u

input=$(cat 2>/dev/null || echo "{}")

{ IFS= read -r cwd; IFS= read -r prompt; } < <(printf '%s' "$input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("cwd") or "")
    print((d.get("prompt") or d.get("user_prompt") or "").replace("\n", " "))
except Exception:
    print(""); print("")
' 2>/dev/null)

SGK_BASE="${cwd:-$(pwd -P)}"
source "$HOME/.claude/scripts/session-goal-key.sh" 2>/dev/null || exit 0

if [ -f "$GOAL_FILE" ]; then
  goal=$(head -1 "$GOAL_FILE" | tr -d '\r\n')
  if [ -n "$goal" ]; then
    goal=$(printf '%s' "$goal" | perl -CSAD -ne 'chomp; if (length > 100){print substr($_,0,100)."\x{2026}"} else {print}' 2>/dev/null || printf '%s' "$goal")
    echo "=== 🎯 今回のセッション目標 ==="
    echo "$goal"
    echo "(この目標と直近の作業がズレた/変わったと感じたら、続行前に1行で確認し、変わっていれば \`/session-goal \"新目標\"\` で更新。脱線でないなら無視可)"
  fi
else
  # 未設定: 実タスクっぽい prompt のときだけ促す (雑談・短文・確認はスルー = 鬱陶しさ回避)
  if [ "${#prompt}" -ge 12 ] && printf '%s' "$prompt" | grep -qiE '実装|修正|追加|作って|直して|変更|リファクタ|新機能|構築|デバッグ|調査|分析|レビュー|design|implement|refactor|build|fix|add|create'; then
    echo "=== 🎯 セッション目標 未設定 ==="
    echo "(最初のタスクが固まったら目標を1行に要約して \`/session-goal \"…\"\` で確定を提案。毎ターン再注入＋statusline で見失い防止)"
  fi
fi

exit 0
