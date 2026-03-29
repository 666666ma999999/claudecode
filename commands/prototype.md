# Prototype Mode

$ARGUMENTS を仮説として使用。引数なしなら曖昧な点をヒアリング。

## 目的

要件が曖昧な状態で「何を作るべきか」を発見するための使い捨てプロトタイプを作成する。
コードは破棄前提。目的は「自分が本当に何を求めているか発見すること」。

## テンプレート（実行前に埋める）

1. **Hypothesis**: 何を確かめたいか（$ARGUMENTS から推論 or ヒアリング）
2. **What we test**: 作るもの（動く最小限）
3. **Kill criteria**: 何が判明したらこの方向を捨てるか
4. **Exit criteria**: 何がわかったらDeliveryに昇格するか
5. **Disposal plan**: 捨てる前にどの知見を残すか

## ルール

- implementation-checklist 不要。テスト不要。速度優先
- Lint・フォーマットもスキップ可
- コミットしない（一時ファイルとして扱う）
- 出力先: プロジェクト内の `_prototype/` ディレクトリ（gitignore推奨）

## 完了後のフロー

1. プロトタイプから得られた知見を言語化する
2. 成功基準が書けるようになったか確認:
   - YES → task-planner スキルで Delivery 計画を策定。プロトタイプは削除
   - NO → 別の角度でもう1回 Prototype。または Clarify に戻る
3. 知見を `tasks/lessons.md` に記録（再利用可能な発見がある場合のみ）
