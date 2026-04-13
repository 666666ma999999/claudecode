#!/bin/bash
# PostToolUse hook: Skill tool で /simplify が実行されたらマーカーを設置
# stop-continue-until-green.sh が simplify-done.timestamp を確認して解除する

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
SKILL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('skill',''))" 2>/dev/null)

# Skill tool で simplify が実行された場合のみ
if [ "$TOOL_NAME" = "Skill" ] && [ "$SKILL_NAME" = "simplify" ]; then
    STATE_DIR="$HOME/.claude/state"
    mkdir -p "$STATE_DIR"
    touch "$STATE_DIR/simplify-done.timestamp"
fi

exit 0
