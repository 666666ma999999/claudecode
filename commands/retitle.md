# /retitle

$ARGUMENTS を改題コンテキスト (例: 年代・テーマ) として使用。引数なしなら AskUserQuestion で入力収集。

このコマンドは `retitle-product` スキルを起動します (占い商品改題、11 体 Agent Pipeline)。詳細は `~/.claude/skills/retitle-product/SKILL.md` 参照。

## 入力

ユーザーから AskUserQuestion で以下を収集 ($ARGUMENTS に含まれない項目のみ):

- **商品名**: 【括弧KW】本文 形式
- **小見出し**: 9 個前後のリスト
- **改題変数**:
  - 年代 (例: 50 代)
  - テーマ (恋愛 / 復縁 / 結婚 / 仕事 / 人生)
  - シチュエーション (任意、年の差 / 職場 / 既婚 / 不倫 / 遠距離 / LGBT)
  - シーズン (任意、春 / 夏 / 秋 / 冬 / クリスマス / 年末年始)
  - キーワード (任意、SNS 疲れ / 既読スルー等)

## 11 体 Agent Pipeline

1. **Planner** — 企画方針決定 (括弧 KW 分解、9 小見出しに役割コード付与)
2-3. **Marketer + Fortune Teller** (並列) — ペルソナ定義 + 占い師視点整理
4. **Writer** — タイトル・サブコピー生成
5. **Editor** — 文言調整
6. **QA Check** — ブランド規約・禁止表現チェック
7-8. **Sales + Data** (並列) — 販売視点・過去データ照合
9. **Optimizer** — コンバージョン最適化
10. **Final Reviewer** — 全体整合性確認
11. **Formatter** — 最終納品形式へ整形

APIキー不要。Claude Code 自身が全 Agent を実行。
