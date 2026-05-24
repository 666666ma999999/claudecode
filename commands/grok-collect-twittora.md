---
description: Grok x_search で X バズ投稿を収集し Vault/.raw/ に保存する。influx Docker 経由実行
argument-hint: "[--days N] [--min-likes N]"
---

# /grok-collect-twittora

@twittora_ 向けの X バズ投稿を Grok x_search で収集して Obsidian Vault に保存します。

## 実行内容

`~/.claude/skills/grok-collect-twittora/SKILL.md` の手順を実行:

1. **influx Docker 起動**: `cd ~/Desktop/biz/influx && docker compose run --rm -e XAI_API_KEY="$XAI_API_KEY" xstock python scripts/grok_collect_twittora.py $ARGUMENTS`
2. **出力ファイル確認**: `~/Desktop/biz/influx/output/grok_twittora/grok-twittora-YYYY-MM-DD.{jsonl,md}` 生成確認
3. **Vault へコピー**: `cp ~/Desktop/biz/influx/output/grok_twittora/grok-twittora-YYYY-MM-DD.{jsonl,md} ~/Documents/Obsidian\ Vault/.raw/`
4. **collector-health 更新**: `python3 ~/.claude/scripts/update_claudeenv.py --target health`

## オプション

- `--days N`: 過去 N 日 (既定 7)
- `--min-likes N`: 最低 like 数 (既定 50)

## 前提条件

- XAI_API_KEY 環境変数が設定済み (~/.zshrc または ~/.envrc.shared)
- Docker daemon 起動済み
- `~/Desktop/biz/influx/` 配下に influx プロジェクト存在

## トラブルシューティング

- 「`XAI_API_KEY: parameter null`」→ ターミナル再起動 (.zshrc 再読込)
- 「Cannot connect to Docker daemon」→ Docker Desktop 起動
- 出力ファイルが生成されない → `~/Desktop/biz/influx/scripts/grok_collect_twittora.py` を python3 直接実行してエラー確認
