---
name: x-stock
description: |
  X(Twitter)記事ネタをvaultのx-article-stock.mdへappendする(cwd非依存・全プロジェクトから発火可)。
  トリガー語: Xネタ,記事ネタ,ブログネタ,Twitterネタ,ストック,stock,あとで書く,ネタ帳,これ記事に,これバズる,x-stock,/x-stock,tweet idea,ネタとして残す,あとでtweet。
  NOT for: 記事本体の執筆→make_article, wiki知識化→/save /wiki, 投稿・計測まで運ぶ出荷→ship-article, 改善・体験談・気付きの記録→capture-improvement（Material Bank 行き。X ネタとして残すのは本 skill）
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
- 存在すれば当日日付 `YYYYMMDD` の既存エントリを `grep "^## idea_<YYYYMMDD>_"` で数え、その日の連番 NNN を決める（当日 0 件なら 001）。ID 体系は `idea_YYYYMMDD_NNN`（見出し `## idea_...`）で固定。

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
- ID 体系は `idea_YYYYMMDD_NNN`（YYYYMMDD=当日, NNN=当日連番3桁ゼロ埋め）
- `grep "^## idea_<YYYYMMDD>_"` で当日既存件数を数え +1 を NNN とする（例: 当日既存2件→`idea_YYYYMMDD_003`、0件→`idea_YYYYMMDD_001`）

追記フォーマット（ファイル末尾に追加）:

````
## idea_YYYYMMDD_NNN: <ユーザーのタイトル>

```yaml
state: idea
captured_at: YYYY-MM-DD
source_cwd: "<実際の cwd 絶対パス>"
source_project: "<推定プロジェクト名>"
tags: [<タグ配列・省略時は空配列 []>]
```

**note**:
- <本文メモ（省略可）>

---
````

**必須制約**:
- `x-article-stock.md` の先頭 frontmatter（ファイル先頭 --- ブロック）は**一切変更しない**
- 既存 entry は**変更しない**
- ファイル末尾に追記するのみ

## STEP 4: 完了報告

1 行のみ返す:

```
idea_YYYYMMDD_NNN 「<title>」を x-article-stock.md に追加 (source: <source_project>)
```

記事化は別フロー: `make_article` cwd の `generate-x-article` skill 経由（`material_ids` に `x-stock:idea_*` を含めると該当entryの `state` が自動で `consumed` に更新される）。

## state 運用（参考）

- 新規追加時: 常に `state: idea`
- 記事化後: `generate-x-article` 経由（`material_ids` に `x-stock:idea_*` 指定）なら該当 entry の `state` は自動で `consumed` に更新される。それ以外の手動記事化ではユーザーが手動で `state: consumed` に更新（本 skill 自身は state を変更しない）
- 使用中の stage: `idea` / `draft` / `consumed` の 3 段階（state 集計テーブル準拠。旧多段階は既存 entry 互換で残置）
