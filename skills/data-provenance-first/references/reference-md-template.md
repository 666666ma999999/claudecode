# 人間可読リファレンス (REFERENCE.md) テンプレート

`data_lineage.yaml` から **生成可能** な人間可読版 (印刷・レビュー時に使用)。
yaml が正本、MD は派生成果物として扱う。

## 標準ファイル位置

`<project-root>/docs/data-reference.md`

## 生成方法 (推奨)

`scripts/generate_data_reference.py` で yaml → MD 変換。
手書きで書いてはいけない (yaml と乖離するため)。

## テンプレート (yaml1件 → MDテーブル1行の対応例)

```markdown
# データリファレンス — <プロジェクト名>

> このファイルは `docs/data_lineage.yaml` から自動生成。
> 直接編集禁止。yaml を更新後、再生成すること。

**最終更新**: 2026-05-07
**対象画面**: salesmtg/output/dashboard_unified.html

## セクション別マッピング

### 事業部全体サマリー

| ID | 表示ラベル | ソース | 列/行 | 計算式 | 単位 |
|---|---|---|---|---|---|
| `m-biz-mom-waterfall` | 月次営業利益変動Waterfall | `boradmtg/csv/デジコン収益分析_YYYYMM.xlsx` (sheet: YYMM月サマリー表) | 小計列 / 営業利益行 | yen_to_sen, MoM diff | 千円 |
| `m-biz-bestworst-profit` | 営業利益増減 Top5/Worst5 | `boradmtg/tmp/bestworst5_profit.csv` | segment_name, change | rank by abs(change), top5/bottom5 | 千円 |
| `m-biz-personnel-detail` | 個人別人件費増減 Top10 | `boradmtg/tmp/personnel_detail.csv` | name, prev_month, curr_month, change | sort by abs(change) desc, top10 | 千円 |

### 全セグメント P&L 分析

(... 同様 ...)

## 取得不可項目 (要 ETL 拡張)

| 項目 | 必要なETL | 担当 | 期限 |
|---|---|---|---|
| (例: セグメント別広告費) | (例: extract_segments.py の KEY_METRICS 拡張) | (例: BE) | (例: Phase 2) |

## kpi_tree.yaml への参照

| display id | kpi_tree node | 計算式正本 |
|---|---|---|
| `m-biz-mom-waterfall` | `operating_profit` | `docs/kpi_tree.yaml` |
```

## 用途

- 取締役会レビュー前の事前資料として印刷
- 監査説明での「これどこから?」即答資料
- 新メンバーオンボーディング
- データソース変更時の影響範囲調査
