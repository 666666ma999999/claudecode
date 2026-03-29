---
description: influxプロジェクトのXブックマーク記事を検索・表示する
argument-hint: "[検索キーワード] or [数字] for latest N件"
---

# Xブックマーク記事の取得

データソース: `~/.claude/data/bookmarks.jsonl` (influx プロジェクトからのシンボリックリンク)
ラベル付きデータ: `~/.claude/data/bookmarks-normalized.jsonl`

## 引数の解釈

$ARGUMENTS

- 引数なし → 最新20件を表示
- 数字のみ (例: `50`) → 最新N件を表示
- キーワード (例: `AI`, `投資`) → テキスト・著者名で検索
- `all` → 全件の統計サマリー
- `authors` → 著者別の件数ランキング
- `normalized` → ラベル付きデータから検索

## 表示形式

各記事を以下の形式で表示:

```
@著者名 | いいね数 | 投稿日
テキスト（最初の200文字）
URL
---
```

## データファイルの読み方

- `~/.claude/data/bookmarks.jsonl` を Read ツールで読み込む
- 各行は独立した JSON オブジェクト
- フィールド: url, text, author, like_count, retweet_count, reply_count, bookmark_count, view_count, is_long_form, created_at

## normalized データの追加フィールド

`~/.claude/data/bookmarks-normalized.jsonl` には以下が追加されている:
- `labels.topic_domain` — トピック分類
- `labels.post_intent` — 投稿意図
- `labels.style_format` — 文体フォーマット
- `labels.hook_pattern` — フック手法
- `features` — 文字数、リスト有無、絵文字数等
