---
description: プロダクトの成果を X 記事化→投稿登録→24h計測まで一気通貫で運ぶ（ship-article スキル起動）
argument-hint: "[product slug / idea_YYYYMMDD_NNN / theme]"
---

# /ship-article

Claude で作ったプロダクトの成果を X 記事にして、投稿登録・計測接続まで運びます。各 Phase は既存スキルへ delegate する thin orchestrator で、記事本文・レビュー・計測のロジックは持ちません。

## 実行内容

`~/.claude/skills/ship-article/SKILL.md` の Phase P0→P5 を実行（詳細手順・失敗分岐は `~/.claude/skills/ship-article/references/phases.md`）:

1. **P0 起点判定**: `project-recall` + `wiki/x-article-stock.md` から出荷対象ネタを 1 件確定 → state `located`
2. **P1 素材化**: `/capture-improvement` で Material Bank に裏付け素材を登録 → `materialized`
3. **P2 記事生成**: make_article cwd で `/generate-x-article`（内蔵ゲート fact-check→review-team→verify-experience）→ `drafted`
4. **P3 承認ゲート**: `review_passed` 確認 + OPSEC 提示 + **ユーザー承認必須** → `approved`
5. **P4 投稿登録**: make_article cwd で `/post-article` → autopost 登録 + x-stock entry を `consumed` 化 → `posted`
6. **P5 計測接続**: `fetch-engagement` で実測還流、または定期計測に接続 → `measuring`/`done`

## 完了条件（3 点すべて観測で確認）

- ① `results.jsonl` に当該 art_NNN の `posted` 記録
- ② `x-article-stock.md` の該当 entry が `state: consumed`
- ③ 24h 計測が接続（`metrics_snapshot` event か `cron_metrics_snapshot` launchd）

## 前提条件

- 記事制作の正本 `~/Desktop/biz/make_article/` が存在（generate-x-article / post-article はここのローカルスキル）
- ネタ帳 `~/Documents/Obsidian Vault/wiki/x-article-stock.md` が存在（`/x-stock` で蓄積したもの）
- 計測は influx VNC + X Cookie（fetch-engagement 前提）

## NOT for

- ネタ蓄積のみ → `/x-stock`
- 記事本文の執筆・レビューそのもの → make_article の `/generate-x-article`
- 計測のみ → `fetch-engagement`
- 改善素材の登録のみ → `/capture-improvement`
- 短文単発投稿 → `/generate-x-post`

## 関連（gitignore 内・この Mac のみの履歴資料）

- 設計 SSoT: `~/.claude/tasks/p-ship-article.md`
- ボトルネック実測: `~/.claude/tasks/p-skills-audit-2026-07-files/audit/offense-synthesis.md` §N5
