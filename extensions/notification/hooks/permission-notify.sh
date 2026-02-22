#!/bin/bash
osascript -e 'tell application "Terminal" to activate' & say '許可が必要です' & osascript -e 'display dialog "許可が必要です" with title "Claude Code" buttons {"OK"} default button "OK"'
