#!/usr/bin/env bash
# 互換シム: 旧パスを参照する稼働中セッション向け。全セッション再起動後に削除可（本体= posttooluse-edit-history.py）
exec "$HOME/.claude/hooks/posttooluse-edit-history.py"
