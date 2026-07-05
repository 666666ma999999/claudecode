# /capture-improvement

$ARGUMENTS を改善メモとして使用。引数なしなら AskUserQuestion で収集。

このコマンドは **`capture-improvement`** スキルを起動します。**カテゴリ定義・閾値・登録先・JSONL スキーマ等は全て** `~/.claude/skills/capture-improvement/SKILL.md` を参照してください (複製しない — 常に skill 側が正)。

## 起動後の最初のアクション

1. `~/.claude/skills/capture-improvement/SKILL.md` を Read で読み込む
2. 核心ルール確認: **定量モード (Before/After 数値あり) と質的モード (数値なし体験談も登録可) の 2 モード。判定は skill の STEP 3 に従う**
3. $ARGUMENTS の改善メモを Before/After 数値で定量化 (AskUserQuestion で不足分確認)
4. skill の 4 カテゴリ判定基準に照合して閾値達成か評価
5. 閾値達成 → 定量モードで登録 / 未達・数値なし → 質的モード (STEP 3c) へフォールバック（捨てない）

## 用途の要約 (1 行)

プロジェクト改善 (速度・コスト・保守性・DX) を定量評価し make_article Material Bank に登録。
