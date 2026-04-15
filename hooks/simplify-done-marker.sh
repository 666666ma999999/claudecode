#!/bin/bash
# PostToolUse hook: /simplify 実行を検知しマーカー設置
# stop-continue-until-green.sh が simplify-done.timestamp を確認して解除する
# 発火条件:
#   (a) Skill tool で skill=simplify (Claude が Skill 経由で呼出)
#   (b) SlashCommand で command=/simplify... (ユーザーが直接入力)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
SKILL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('skill',''))" 2>/dev/null)
CMD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

STATE_DIR="$HOME/.claude/state"
touch_done() { mkdir -p "$STATE_DIR"; touch "$STATE_DIR/simplify-done.timestamp"; }

if [ "$TOOL_NAME" = "Skill" ] && [ "$SKILL_NAME" = "simplify" ]; then
    touch_done
elif [ "$TOOL_NAME" = "SlashCommand" ] && [[ "$CMD" == /simplify* ]]; then
    touch_done
fi

exit 0
