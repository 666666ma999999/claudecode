#!/bin/bash
# セッション開始時に ~/.claude/ の最新を pull
cd ~/.claude || exit 0
git pull --rebase --no-edit &>/dev/null &
exit 0
