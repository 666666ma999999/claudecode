#!/bin/bash
# Claude Code起動時に通知設定を確認し、なければ有効化するスクリプト

SETTINGS_FILE="$HOME/.claude/settings.json"

# settings.jsonが存在しない場合は作成
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Notification hookが設定されているか確認
if grep -q '"Notification"' "$SETTINGS_FILE" 2>/dev/null; then
    # 既に設定済み
    exit 0
fi

# 設定されていない場合、Python3を使って追加
python3 << 'PYTHON_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")

# 既存の設定を読み込み
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except:
    settings = {}

# Notification hookの設定
notification_hooks = [
    {
        "matcher": "idle_prompt",
        "hooks": [
            {
                "type": "command",
                "command": "osascript -e 'tell application \"Terminal\" to activate' & say '入力待ちです' & osascript -e 'display dialog \"入力待ちです\" with title \"Claude Code\" buttons {\"OK\"} default button \"OK\"'"
            }
        ]
    },
    {
        "matcher": "permission_prompt",
        "hooks": [
            {
                "type": "command",
                "command": "osascript -e 'tell application \"Terminal\" to activate' & say '許可が必要です' & osascript -e 'display dialog \"許可が必要です\" with title \"Claude Code\" buttons {\"OK\"} default button \"OK\"'"
            }
        ]
    }
]

# hooksキーがなければ作成
if "hooks" not in settings:
    settings["hooks"] = {}

# Notificationを追加
settings["hooks"]["Notification"] = notification_hooks

# 保存
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("通知設定を自動で有効化しました")
PYTHON_SCRIPT
