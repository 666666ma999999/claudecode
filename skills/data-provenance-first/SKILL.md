---
name: data-provenance-first
description: |
  ダッシュボード/レポート生成プロジェクトで、表示中の全数値の出典(どのファイルのどの列・どんな計算)を
  機械可読な docs/data_lineage.yaml で正本管理するスキル。経営資料/監査説明用ダッシュボードの数値根拠を
  追跡可能にし、表示変更時の整合性を hook で警告する。
  キーワード: 出典管理, 数値根拠, リファレンス, data lineage, ダッシュボード監査
  NOT for: 単発のグラフ生成 (→ dashboard-design-guide)、KPI計算式定義 (→ kpi-tree-first)
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
license: proprietary
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
  category: data-governance
  tags: [data-lineage, provenance, dashboard, audit, governance]
---

# data-provenance-first スキル

## 原則

**ダッシュボードに表示する全数値は、docs/data_lineage.yaml に出典を登録してから表示する。**

経営資料・監査説明・取締役会用ダッシュボードでは、表示数値が「どのファイルの・どの列・どの計算」から来たか即座に答えられないとレビュー時に致命的。生成 → 表示 → 後で根拠を探す、では破綻する。

## 発動条件

- ダッシュボード/レポート生成プロジェクトで以下のいずれか:
  - 新規セクション追加 (新KPI・新テーブル・新チャート)
  - 既存表示の数値ロジック変更
  - 表示中の数値について「これどこから?」と聞かれたとき
  - 月次/週次の運用報告書を作成・更新するプロジェクト
- マーカー: `output/dashboard*.html`, `output/report*.html`, または `docs/data_lineage.yaml` の存在

## ファイル構成

```
<project-root>/
  docs/
    data_lineage.yaml      ← 出典正本（このスキルの主成果物）
    kpi_tree.yaml          ← 計算式正本（kpi-tree-first スキル）
  output/
    dashboard*.html        ← 表示物
```

## ワークフロー

### 1. 新規表示追加時

1. 表示する数値の **id (DOM ID推奨)** を決める
2. `docs/data_lineage.yaml` に `displays:` エントリを追加
3. 必須フィールドを埋める (詳細: `references/lineage-yaml-spec.md`)
4. ダッシュボード生成スクリプトを更新
5. 生成→ブラウザで実値が yaml の formula 通りか目視確認

### 2. 既存表示変更時

1. 該当 id の yaml エントリを更新 (source_file/formula 等)
2. `updated_at` を当日に変更
3. 変更理由を `notes` に追記

### 3. レビュー時 (経営層から「これどこ?」と聞かれたとき)

1. yaml で該当 id を検索
2. `source_file` + `sheet/column` + `formula` を提示

## 強制力 (hook)

`~/.claude/hooks/data-provenance-guard.sh` が PostToolUse(Write|Edit) で:
- ダッシュボード生成スクリプト (`generate_*dashboard*.py`, `generate_*report*.py`) を編集したか検出
- 同プロジェクトの `docs/data_lineage.yaml` が同セッション内で更新されたかチェック
- 更新がなければ **warning** (block ではない)

未対応プロジェクトへの誤発動防止: `docs/data_lineage.yaml` が存在しないプロジェクトでは無作動。

## kpi-tree-first との関係

| スキル | 管理対象 | ファイル |
|---|---|---|
| `kpi-tree-first` | KPIの**計算式** (葉ノードまで) | `docs/kpi_tree.yaml` |
| `data-provenance-first` | 表示数値の**出典** (どこから来たか) | `docs/data_lineage.yaml` |

両者は相互参照する:
- `data_lineage.yaml` の `displays[].kpi_tree_ref` が `kpi_tree.yaml#node_id` を指す
- `kpi_tree.yaml` の `leaf.datasource` は `data_lineage.yaml` で詳細管理

KPI以外の表示 (Top10ランキング・Waterfall・Heatmap 等の派生表示) も `data_lineage.yaml` の対象。

## 詳細リファレンス

- YAML スキーマ定義: `references/lineage-yaml-spec.md`
- 人間可読レポート (REFERENCE.md) テンプレ: `references/reference-md-template.md`
