---
description: プロジェクトの過去作業をざっくりサマリー（git 履歴ベース・期間/日別作業量/種類集計）
---

# /project-history

対象プロジェクトの **過去の作業履歴を git からざっくり要約**して見せるコマンド。

## 実行

- 引数 `$ARGUMENTS` がパスならそれを対象、空なら現在のフォルダ (cwd) を対象に実行する:

```bash
bash ~/.claude/scripts/project-history.sh "$ARGUMENTS"
```

（`$ARGUMENTS` が空のときは `bash ~/.claude/scripts/project-history.sh` を実行 = cwd 対象）

- 出力（期間 / 日別の作業量 / 作業の種類の集計）を**そのまま**ユーザーに見せる。

## 追加対応

- ユーザーが「5手順にマップして」「もっと詳しく」と言ったら、`git log --reverse --pretty=format:'%ad | %s' --date=short` の全件を読み、
  ユーザーの 5 手順（既存データ分析 → 実運用確認 → 公式推奨確認 → 施策起案 → ファクトチェック）にマップした表を追加で作る。
- 対象が git リポジトリでない場合は、スクリプトがその旨を出すので、それを伝える（履歴は git がないと追えない）。
