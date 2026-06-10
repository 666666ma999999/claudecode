#!/usr/bin/env bash
# SessionStart: 編集 ALLOW リストを冒頭に表示 (Claude が ALLOW を見落として "禁止" 断定するのを防ぐ)
# 設計経緯: 14 ラウンド議論で permission-claim-proof として再発防止策 C (2026-05-13)
echo "=== 📝 Edit Policy (file write ALLOW list) ==="
echo "  cwd 配下 + ~/.claude/ + ~/Documents/Obsidian Vault/ + ~/Desktop/prm/ + ~/Desktop/biz/ + ~/.agents/skills/ (symlink)"
echo "  source: ~/.claude/hooks/restrict-cwd-edits.sh"
