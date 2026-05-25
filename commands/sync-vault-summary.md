---
description: rules/42 対象ファイルの編集を要約し vault MOC に append する
---

# /sync-vault-summary

`sync-vault-summary` skill を起動。

詳細: `~/.claude/skills/sync-vault-summary/SKILL.md`

## 概要
本セッションで Edit/Write した rules/42 対象ファイル (plan/measures/spec/analysis/CLAUDE/README/data-sources 等) を Claude が 1-3 行に要約し、対応する vault MOC (02_Ai/<group>/<sub>_ope.md) の「🔁 最新更新ログ」セクションに prepend する。

## 前提
- `~/.claude/state/vault-cc-enabled` 存在 (なければ abort)
- `~/.claude/state/edit-history.jsonl` に本セッションの編集履歴あり (posttooluse-edit-history.sh が記録)

## 起動
ユーザーが `/sync-vault-summary` と入力すると本コマンド経由で skill が起動する。
