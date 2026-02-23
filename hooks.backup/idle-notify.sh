#!/bin/bash
osascript -e 'tell application "Terminal" to activate' & say '入力待ちです' & osascript -e 'display dialog "入力待ちです" with title "Claude Code" buttons {"OK"} default button "OK"'
