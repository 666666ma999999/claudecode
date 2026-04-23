#!/bin/bash
osascript -e 'tell application "Terminal" to activate' & say '許可が必要です' & osascript -e 'display notification "許可が必要です" with title "Claude Code"'
