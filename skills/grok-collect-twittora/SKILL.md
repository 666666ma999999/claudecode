---
name: grok-collect-twittora
description: "@twittora_ 向け (Claude Code / AI 活用) の X バズ投稿を Grok x_search で収集し、Obsidian Vault の .raw/ に material-bank 互換 (jsonl + md) で保存するスキル。influx Docker 経由で xai_sdk を実行し、出力ファイルを Vault に転送する。/grok-collect-twittora で起動。トリガー: 「grok 検索」「バズった投稿」「バズ投稿を取得」「X バズ収集」「Twitter バズ」「インプレッション高い投稿」「Twittora 素材」を含む依頼。一般的な Web 検索や mcp__grok-search ツールでの即時回答ではなく、必ず本スキル経由で influx Docker → Vault/.raw/ に保存すること。"
allowed-tools: Bash, Read
---

# grok-collect-twittora

## ⚠️ 手動実行専用（自動化非推奨）

| 項目 | 内容 |
|---|---|
| **実行モード** | manual（人間が明示的にトリガー） |
| **自動化しない理由** | Grok API コスト $0.4–0.8/run。日次自動化すると年間 $150–300 の無音支出リスク |
| **推奨頻度** | 週1回以下。話題が盛り上がったタイミングで随時 |
| **collector-health ステータス** | `⚪ manual長期未起動（許容）` — 長期未起動でも異常ではない |

@twittora_ アカウント (実名 / tech_tips + ceo_perspective) の投稿素材プールを Grok 経由で更新する。

## 前提

- `XAI_API_KEY` 環境変数が influx Docker に渡されていること (docker-compose.yml で既に対応済み)
- influx プロジェクトが `~/Desktop/biz/influx/` に存在し、Docker が起動可能
- Obsidian Vault が `~/Documents/Obsidian Vault/` に存在
- 収集スクリプトは `~/Desktop/biz/influx/scripts/grok_collect_twittora.py` (本スキルとセットで存在)

## 実行フロー

### Step 1: Grok 収集 (influx Docker)

```bash
cd ~/Desktop/biz/influx && \
docker compose run --rm -e XAI_API_KEY="$XAI_API_KEY" xstock \
  python scripts/grok_collect_twittora.py
```

オプション (環境に応じて引数を渡す):

- `--days 14`: 過去日数 (既定 7)
- `--min-likes 100`: 最低 like 数 (既定 50)
- `--per-query 12`: query あたりの最大取得数 (既定 8)
- `--queries "Claude Code" "MCP" "hooks"`: 検索 query を上書き (既定は 10 個)

出力先 (Docker volume mount 経由でホスト側に出る):
- `~/Desktop/biz/influx/output/grok_twittora/grok-twittora-YYYY-MM-DD.jsonl`
- `~/Desktop/biz/influx/output/grok_twittora/grok-twittora-YYYY-MM-DD.md`

最終的に Vault の以下 3 箇所に配置される:
- `Vault/.raw/grok-twittora-YYYY-MM-DD.jsonl` (機械可読・正本)
- `Vault/.raw/grok-twittora-YYYY-MM-DD.md` (機械可読・サマリ)
- `Vault/01_Biz/x-operation/buzz-archive/buzz-YYYY-MM-DD.md` (Obsidian で閲覧可能な人間用)

### Step 2: Vault に転記

`.raw/` (機械可読・正本) と `01_Biz/x-operation/buzz-archive/` (Obsidian で閲覧可能な人間用) の 2 箇所にコピーする。Obsidian は `.` 始まりフォルダを非表示にする (隠し表示トグルなし) ため、人間向けに別経路を用意する。

```bash
TODAY=$(date +%Y-%m-%d)
SRC=~/Desktop/biz/influx/output/grok_twittora
VAULT="$HOME/Documents/Obsidian Vault"

# 1. 正本: .raw/ (jsonl + md 両方、append-only)
cp "$SRC/grok-twittora-$TODAY.jsonl" "$SRC/grok-twittora-$TODAY.md" "$VAULT/.raw/"

# 2. 人間用: buzz-archive/ (md のみ、Obsidian の通常ツリーから見える)
mkdir -p "$VAULT/01_Biz/x-operation/buzz-archive"
cp "$SRC/grok-twittora-$TODAY.md" "$VAULT/01_Biz/x-operation/buzz-archive/buzz-$TODAY.md"
```

最新 1 セット (今日生成された分) のみをコピーする。`buzz-archive/` は md のみ (生 jsonl は機械処理用なので置かない)。

### Step 3: Vault index 更新 (任意)

`Vault/wiki/sources/_index.md` および `Vault/wiki/index.md` の Sources セクションに新エントリを追記する。

```markdown
- [[grok-twittora-YYYY-MM-DD]] — Claude Code / AI 活用バズ投稿プール (@twittora_ 向け)
```

### Step 4: 結果報告

成功時、ユーザーに次を報告する:
- 取得件数 (重複除去後)
- 合計 likes
- トップ 5 ツイート (likes 順, author + 抜粋)
- jsonl/md のフルパス

## エラーハンドリング

- `XAI_API_KEY` 未設定 → influx の `~/.zshrc` または `.env` 設定を確認するようユーザーに案内
- Docker 起動失敗 → `docker compose ps` で状態確認、`docker compose build xstock` を提案
- 0 件取得 → `--days` を伸ばす / `--min-likes` を下げる / queries を見直すよう提案

## 関連

- 収集対象アカウント: `~/Documents/Obsidian Vault/01_Biz/x-operation/twittora_.md`
- 戦略 SSoT: `~/Documents/Obsidian Vault/01_Biz/x-operation/account-strategy-2026-04-24.md`
- 既存の investment 路線収集 (kabuki666999): `~/Desktop/biz/influx/output/research/`

## 既知の制限

- Grok API は実投稿の正確な likes/impressions を保証しない (LLM 経由の推定値)
- 同一投稿の重複は id ベースで除去するが、別 query で同じ投稿が引っかかると captured_at は最初のもの
- 1 回実行で約 8 query × 8 件 = 最大 64 件 (重複除去で 30〜50 件程度になることが多い)
