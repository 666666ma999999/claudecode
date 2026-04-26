#!/bin/bash
# SessionStart: Detect extension pattern projects and print guidance
# When CWD has config/extensions.yaml or config/extensions.json,
# remind Claude about the extension pattern rules.

INPUT=$(cat)

CWD="$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', ''))
except:
    print('')
" 2>/dev/null)"

if [[ -z "$CWD" ]]; then
  exit 0
fi

PROJECT_TYPE=""
if [[ -f "$CWD/config/extensions.yaml" ]]; then
  PROJECT_TYPE="BE"
elif [[ -f "$CWD/config/extensions.json" ]]; then
  PROJECT_TYPE="FE"
fi

if [[ -z "$PROJECT_TYPE" ]]; then
  exit 0
fi

cat >&2 <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Extension Pattern Project Detected (${PROJECT_TYPE})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
このプロジェクトはエクステンションアーキテクチャを採用しています。

必須ルール:
  • 新機能は src/extensions/<name>/ に作成すること
  • core/ の変更は最小限に（新HookPoint/Interface追加のみ）
  • ext間の直接import禁止 → EventBus を使用
  • テストは ext 内に自己完結

参照スキル:
  • BE: be-extension-pattern
  • FE: fe-extension-pattern
  • FE+BE連携: fe-be-extension-coordination
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

exit 0
