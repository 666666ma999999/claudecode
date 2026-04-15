# /new-feature

$ARGUMENTS を feature-slug (英小文字・ハイフン区切り) または feature 概要として使用。引数なしなら Phase 1 で確認。

このコマンドは **`new-feature`** スキルを起動します。**Phase 0-4 の詳細手順・AskUserQuestion 4 項目・Plan mode 連動は全て** `~/.claude/skills/new-feature/SKILL.md` を参照してください (複製しない — 常に skill 側が正)。

## 起動後の最初のアクション

1. `~/.claude/skills/new-feature/SKILL.md` を Read で読み込む
2. Phase 0 Discovery からマーカーファイル検出 + 既存 tasks/ 読込
3. Phase 1 で $ARGUMENTS を feature-slug の初期候補として使い、4 項目 (Why/Who/非ゴール/成功基準) を AskUserQuestion で収集
4. `mkdir -p tasks && cp ~/.claude/templates/plan.md tasks/{slug}.md` ({slug} はリテラル置換)
5. Phase 2 で EnterPlanMode

## 用途の要約 (1 行)

新機能/MVP の 4 項目ブリーフを対話収集し、Plan mode を起動して影響範囲+変更禁止ファイルを自動提案する統合フロー。
