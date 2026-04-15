# /retitle

$ARGUMENTS を改題コンテキスト (例: 年代・テーマ・シチュエーション) として使用。引数なしなら AskUserQuestion で入力収集。

このコマンドは **`retitle-product`** スキルを起動します。**詳細な実行手順・Agent Pipeline 構成・各ステップの役割・外部ルール参照先は全て** `~/.claude/skills/retitle-product/SKILL.md` を参照してください (複製しない — 常に skill 側が正)。

## 起動後の最初のアクション

1. `~/.claude/skills/retitle-product/SKILL.md` を Read で読み込む
2. Step 0 Input Collection から skill の指示通り実行
3. $ARGUMENTS に含まれる情報 (年代/テーマ等) を初期入力として取り込み、不足分を AskUserQuestion で収集

## 用途の要約 (1 行)

占い商品の改題 (商品名+小見出し+改題変数→新商品) を Agent Pipeline で生成。API キー不要、Claude Code 自身が全 Agent を実行。
