# data_lineage.yaml スキーマ定義

## ファイル位置

`<project-root>/docs/data_lineage.yaml`

## トップレベル

```yaml
schema_version: 1.0           # スキーマバージョン (このスキルの version と整合)
generated_at: 2026-05-07      # YAML 最終更新日 (ISO 8601)
target_dashboard: salesmtg/output/dashboard_unified.html  # 対象画面 (相対パス)
project: salesmtg              # プロジェクト識別子

displays:                      # 表示エントリの配列 (主要部)
  - id: ...
    ...
```

## displays[] 必須フィールド

| フィールド | 型 | 説明 | 例 |
|---|---|---|---|
| `id` | string | 一意ID。DOM ID推奨。kebab-case | `m-biz-mom-waterfall` |
| `section` | string | UI内のセクション名 (見出し) | `事業部全体サマリー` |
| `label` | string | 表示ラベル/タイトル | `月次営業利益変動Waterfall` |
| `source_file` | string | ソースファイル相対パス | `boradmtg/csv/デジコン収益分析_YYYYMM.xlsx` |
| `unit` | string | 単位 | `千円` / `%` / `件` |

## displays[] 推奨フィールド

| フィールド | 型 | 説明 | 例 |
|---|---|---|---|
| `sheet` | string | Excelシート名 (Excel源) | `2603月サマリー表` |
| `column` | string \| list | CSV列名 / Excel列 | `change_sen` / `[D, E]` |
| `row` | string \| int | Excel行 (固定行のとき) | `営業利益行` |
| `cells` | string | 範囲指定 | `D5:F30` |
| `transform` | string | 変換処理の概要 | `yen_to_sen, MoM diff` |
| `formula` | string | 計算式 | `(curr - prev) / abs(prev) * 100` |
| `filter` | string | 抽出条件 | `category == "BEST"` |
| `kpi_tree_ref` | string | kpi_tree.yaml への参照 | `docs/kpi_tree.yaml#operating_profit` |
| `notes` | string | 補足・既知の制約 | `小計セグメント前提。合計は配賦相殺でゼロ` |
| `updated_at` | date | このエントリの最終更新 | `2026-05-07` |

## 例 (実プロジェクトより抜粋)

```yaml
schema_version: 1.0
generated_at: 2026-05-07
target_dashboard: salesmtg/output/dashboard_unified.html
project: salesmtg

displays:
  - id: m-biz-mom-waterfall
    section: 事業部全体サマリー
    label: 月次営業利益変動Waterfall
    source_file: boradmtg/csv/デジコン収益分析_YYYYMM.xlsx
    sheet: YYMM月サマリー表
    column: 小計列
    row: 営業利益行
    transform: yen_to_sen, MoM diff
    unit: 千円
    notes: 小計セグメント前提 (合計は配賦相殺で 0 になる)
    updated_at: 2026-05-07

  - id: m-biz-bestworst-profit
    section: 事業部全体サマリー
    label: 営業利益増減 Top5/Worst5
    source_file: boradmtg/tmp/bestworst5_profit.csv
    column: [segment_name, change, pct_change]
    formula: rank by abs(change), top5 / bottom5
    unit: 千円
    notes: change は profit_curr - profit_prev (yen)
    updated_at: 2026-05-07

  - id: m-biz-personnel-detail
    section: 事業部全体サマリー
    label: 個人別人件費増減 Top10
    source_file: boradmtg/tmp/personnel_detail.csv
    column: [name, category, prev_month, curr_month, change]
    filter: prev_month > 0 OR curr_month > 0
    formula: sort by abs(change) desc, top 10
    unit: 千円
    notes: 退職者 (prev>0 かつ curr=0) は別ブロックで表示
    updated_at: 2026-05-07
```

## バリデーション (推奨実装)

`scripts/validate_lineage.py` で以下を確認:

1. 全 `id` が一意
2. 全 `source_file` が実在 (相対パス)
3. `kpi_tree_ref` が指す node が `kpi_tree.yaml` に存在
4. ダッシュボードHTML内の主要DOM ID と yaml の `id` が一致 (差分は警告)

このバリデータが pre-commit / hook から呼ばれる想定。
