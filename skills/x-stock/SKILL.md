---
name: x-stock
description: |
  X (Twitter) 記事ネタを vault の x-article-stock.md に append する。
  cwd 非依存・どのプロジェクトからでも発火可。
  トリガー語: "X ネタ" / "記事ネタ" / "ブログネタ" / "Twitter ネタ"
              "ストック" / "stock" / "あとで書く" / "ネタ帳"
              "これ記事に" / "これバズる" / "x-stock" / "/x-stock"
              "tweet idea" / "ネタとして残す" / "あとで tweet"
  NOT for: 記事本体の執筆 (→ make_article), wiki 知識化 (→ /save /wiki)
user-invocable: true
argument-hint: "[idea memo]"
allowed-tools:
  - Read
  - Edit
  - AskUserQuestion
---

# x-stock skill

X 記事ネタを vault グローバルストックへ保存する。**追加専用**。cwd 非依存。

## 責務範囲

- ✅ idea の新規 append（`state: idea` 固定）
- ✅ source_cwd / source_project の自動記録
- ❌ state 更新・promote・archive・export（→ make_article / 手動編集）
- ❌ 既存 entry のマージ・重複チェック（→ 人間判断）

## STEP 0: 前提確認

保存先ファイルを確認する。

```
STOCK_FILE="$HOME/Documents/Obsidian Vault/wiki/x-article-stock.md"
```

- ファイルが存在しなければ「x-article-stock.md が見つかりません」と報告して停止。
- 存在すれば現在の最大 idea 番号を `grep "^id: idea_"` で取得する。

## STEP 1: ネタ要素収集

ユーザー発話から以下を抽出する（最大 1 回 AskUserQuestion・全項目省略可）:

| フィールド | 必須 | 抽出元 |
|---|---|---|
| `title` | **必須** | 発話 or AskUserQuestion |
| `tags` | 任意 | 発話 or 省略 |
| `body` (note) | 任意 | 発話 or 省略 |

**タイトルのみで append OK**。AskUserQuestion を省略できる場合は省略する。

省略パスの条件:
- 発話に 5 文字以上のタイトル相当テキストがある → そのまま title として使用、他は空で保存

## STEP 2: source 自動記録

現在の cwd を取得し `source_project` を推定する:

| cwd パターン | source_project |
|---|---|
| `~/Desktop/biz/<name>/*` | `<name>` |
| `~/Desktop/prm/<name>/*` | `<name>` |
| `~/.claude` | `claude-config` |
| `~/Documents/Obsidian Vault` | `vault` |
| その他 | cwd の末尾ディレクトリ名 |

## STEP 3: append 実行

採番ルール:
- 既存の `id: idea_` を grep して最大番号を取得
- 新 id = 最大値 + 1（例: 既存最大 006 → `idea_007`）

追記フォーマット（ファイル末尾に追加）:

```
---
id: idea_NNN
title: "<ユーザーのタイトル>"
state: idea
source_cwd: "<実際の cwd 絶対パス>"
source_project: "<推定プロジェクト名>"
created: "YYYY-MM-DD"
tags: [<タグ配列・省略時は空配列 []>]
---

<本文メモ（省略可・ない場合は空行のみ）>

```

**必須制約**:
- `x-article-stock.md` の先頭 frontmatter（ファイル先頭 --- ブロック）は**一切変更しない**
- 既存 entry は**変更しない**
- ファイル末尾に追記するのみ

## STEP 4: 完了報告

1 行のみ返す:

```
idea_NNN 「<title>」を x-article-stock.md に追加 (source: <source_project>)
```

記事化は別フロー: `make_article` cwd で collect-materials skill 経由。

## state 運用（参考）

- 新規追加時: 常に `state: idea`
- 記事化後: ユーザーが手動で `state: consumed` に更新（この skill は変更しない）
- 使用中の stage: `idea` / `consumed` の 2 段階のみ（旧 6 段階は既存 entry 互換のため残置）
