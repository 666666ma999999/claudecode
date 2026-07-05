---
description: reply の多い X 投稿を記事ネタとして週1で半手動収集する（collect-reply-posts スキル起動）
---

# /collect-reply-posts

AI/Claude Code 界隈で reply（返信・議論）を多くもらっている X 投稿を記事ネタ素材として収集します。

## 実行内容

`~/.claude/skills/collect-reply-posts/SKILL.md` の手順（4段+記録）を実行:

1. **Stage 1**: `bash ~/.claude/skills/collect-reply-posts/gen-queries.sh` で探索クエリURLを生成
2. **Stage 2**: 出力URLをブラウザで開き、reply の多い親投稿を目視で15〜20件拾ってセッションに貼る
3. **Stage 3**: `references/judgment-prompt.md` の rubric に従い、AIが採否・論点・見出し案をまとめて評価
4. **Stage 4**: 採用ネタを1件ずつ `/x-stock` に渡して保存
5. **Stage 5**: `~/.claude/state/reply-search-feedback.jsonl` に採否を記録（自己改善ループの ground truth）

詳細は `~/.claude/skills/collect-reply-posts/SKILL.md` を参照。

## 前提条件

- Obsidian Vault が `~/Documents/Obsidian Vault/` に存在し、`wiki/x-article-stock.md` がある
- X にログイン済みのブラウザ（advanced search の `min_replies:` はログイン時のみ安定）

## 関連

- 収集軸違い（likes/バズ）: `/grok-collect-twittora`
