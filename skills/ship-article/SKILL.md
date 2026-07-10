---
name: ship-article
description: |
  プロダクト作業の成果を X 記事化→投稿→24h計測まで一気通貫で運ぶ thin orchestrator。
  各 Phase は既存スキル/パイプラインへ delegate するだけで、ship-article 内に business logic を持たない。
  トリガー語: これ記事にして出して, 記事化して投稿, ship article, 投稿まで運んで, x-stock消化,
  記事を出荷, ネタを記事化して出す。
  NOT for: ネタ蓄積のみ→x-stock / 記事本文の執筆・レビュー→make_article の generate-x-article /
  計測のみ→fetch-engagement / 改善素材の登録のみ→capture-improvement。
user-invocable: true
argument-hint: "[product slug or idea_YYYYMMDD_NNN or theme]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - WebSearch
  - AskUserQuestion
---

# ship-article スキル（記事出荷オーケストレーター）

「Claude で作ったプロダクトの成果」を X 記事にして**投稿・計測まで**運ぶ薄い司令塔。
記事の中身・レビュー・計測の実装は**一切持たない**。既存スキルを順に呼ぶだけ。

## 絶対原則（設計記録は散逸・2026-07-10監査で確認。本SKILLが現行の正本）

- **thin wrapper**: 各 Phase は既存スキル/既存パイプラインへ delegate。ship-article は state 遷移と gate 判定のみ。
- **記事本文ロジックを書かない**: 生成・レビュー・計測は make_article / global スキルの責務。ここに複製しない。
- **投稿の実送信はしない**: `/post-article` は autopost 管理画面への登録まで。X への実投稿は autopost 側。

## Phase 表（詳細手順・失敗分岐は `references/phases.md`）

| Phase | 名前 | delegate 先（実在） | 入力→出力 | state |
|---|---|---|---|---|
| P0 | 起点判定 | `project-recall` + `wiki/x-article-stock.md` 読取 + AskUserQuestion | 発話/cwd → `slug` `stock_entry_id` `source_cwd` | `located` |
| P1 | 素材化 | `/capture-improvement`（global） | 成果 → Material Bank 素材 ≥1 | `materialized` |
| P2 | 記事生成 | make_article cwd で `/generate-x-article` | 素材 → `art_NNN` + `-short` ペア（内蔵ゲート: fact-check-from-history→article-review-team→verify-experience） | `drafted` |
| P3 | 承認ゲート | results.jsonl `review_passed` 確認 + OPSEC 提示 + **ユーザー承認必須** | draft → 承認 | `approved` |
| P4 | 投稿登録 | make_article cwd で `/post-article <draft>` → x-stock entry を `consumed` 化 | 承認 → autopost 登録 + `posted` event | `posted` |
| P5 | 計測接続 | `fetch-engagement`（global） / 失敗時 `/record-result` | posted_url → `metrics_snapshot` | `measuring` |

state ファイル: `~/.claude/state/ship-article/<slug>.json`（schema は `references/phases.md`）。

## 完了条件（3 点すべて観測で確認・`<art_id>`=art_NNN, `<id>`=idea_YYYYMMDD_NNN）

```bash
RES=~/Desktop/biz/make_article/output/published/results.jsonl
STOCK="$HOME/Documents/Obsidian Vault/wiki/x-article-stock.md"
# ① posted 記録
grep '"event": "posted"' "$RES" | grep '<art_id>'                 # 非空
# ② x-stock が consumed
awk '/^## <id>/{f=1} f&&/state:/{print; exit}' "$STOCK"            # state: consumed
# ③ 24h 計測が接続（どちらか）
grep '"event": "metrics_snapshot"' "$RES" | grep '<art_id>'        # 非空、または
launchctl list | grep -i com.masa.make-article-metrics            # 定期計測が生きている(launchd Label)
```

3 点が揃うまで完了報告しない。①だけ・②だけの「投稿したが計測未接続」「生成したが未投稿」は**未完**。

## 良い例（実績・results.jsonl 由来。2026-07-05 実測で照合済み）

`art_013` が draft_created→**posted**（`https://x.com/twittora_/status/2052933092961309152`）まで到達（results.jsonl で直接確認）。ただし **metrics_snapshot はファイル全体で0件・②x-stock consumedもゼロ件** — ①posted の実績はこの1件のみで、②③の実績は現状ゼロ件。①②③すべて揃った実績はまだ無く、ship-articleが最後まで運ぶのは未踏の工程である旨を明記する。

## 悪い例（アンチパターン・出典: offense-synthesis N5）

x-article-stock に **idea 75 件・posted 0 件**（実公開わずか 1 件（art_013））。x-stock は蓄積のみ・generate-x-article は project skill で、**idea→consumed を通す動線が誰の責務でもなかった**ため死蔵。ship-article は「蓄積だけで出荷ゼロ」を塞ぐために idea→consumed を最後まで運ぶ。ここで P4 の consumed 化を飛ばすと同じ死蔵に戻る。

## 出典（設計記録は散逸・2026-07-10監査で確認。本SKILLが現行の正本）

- 採用設計: Codex + Friction Analyst 2 並列レビュー済み（元ファイルは散逸）
- ボトルネック実測: offense-synthesis §N5（元ファイルは散逸）
