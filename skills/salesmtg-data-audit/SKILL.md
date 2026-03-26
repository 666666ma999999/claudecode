---
name: salesmtg-data-audit
description: 営業会議ダッシュボードのデータ整合性監査。月次売上CSV・KPI CSV・summary CSVの重複/欠損/ソース不整合を検出し、粗利構成の正確性を保証する。
triggers:
  - salesmtg データ監査
  - CSV整合性チェック
  - 粗利構成 不整合
  - スクレイピング後 検証
  - 月次売上CSV 2セット問題
not_for:
  - ダッシュボードUI修正（→ salesmtg-dashboard-qa）
  - 通常のコード修正
---

# salesmtg データ整合性監査スキル

## 使用タイミング

- スクレイピング後のCSV品質チェック
- 粗利構成テーブルの数値が「おかしい」と報告された時
- 新しい月のパイプライン実行前後
- データソースの優先順位を変更する時

## 監査手順

### Phase 1: CSV構造チェック

```bash
# 1. 月次売上CSVの行数・重複確認
wc -l data/月次売上-mobile-YYYY-MM-sites.csv
# ヘッダ行数（1なら正常、2以上なら2セット問題）
grep -c 'サイトID' data/月次売上-mobile-YYYY-MM-sites.csv

# 2. 各サイトの行数確認（8行/サイト × 1セット = 正常）
awk -F'","' '{print $1}' CSV | sort | uniq -c | sort -rn | head -20

# 3. 空行サイトの特定
# 全集計区分が空のサイトを検出
```

### Phase 2: 2セット問題の検出と解決

swan-manageのCSVは新旧プラットフォームの2セットを含む。

**検出ルール:**
- 同一サイトIDで同一集計区分の行が2行以上 → 2セット
- 片方にデータあり・片方が空 → データあり行を採用
- 両方にデータあり → **エラー停止**（手動確認必要）
- 両方とも空 → 欠損としてマーク

**対応コード（generate_dashboard.py parse_csv内）:**
```python
# Skip empty duplicate rows (all values zero)
if any(v != 0 for v in month_values.values()):
    data[site_id][metric] = month_values
```

### Phase 3: ソース整合性チェック

各セグメントについて以下を確認:

| チェック項目 | 正本 | 検算式 |
|-------------|------|--------|
| 売上 = 継続会員月額 + 施策売上 | 月次売上CSV | `売上 = 継続会員月額 + 売上（月額+従量）` |
| 広告費が存在するか | 月次売上CSV | 値 > 0 または明示的に0 |
| 6M+月額の計算元 | 月次売上CSV or summary CSV | フォールバック時は警告 |
| summary月列 = KPI月列 | summary/KPI CSV | `_months` の一致確認 |

### Phase 4: 監査レポート出力

```
=== salesmtg データ監査レポート ===
対象月: YYYYMM
CSVファイル: 月次売上-mobile-YYYY-MM-sites.csv
行数: XXXX行（2セット検出 / 1セット正常）

■ サイト別ステータス
  OK: 15サイト（データ完全）
  WARN: 3サイト（フォールバック使用: 469, 467, 465）
  ERROR: 0サイト

■ フォールバック詳細
  Seg 3 (469): 継続会員月額=欠損 → summary CSV月額売上で代替
  Seg 5 (467): 継続会員月額=欠損 → summary CSV月額売上で代替
  ...

■ 検算結果
  売上突合: 17/17サイト OK
  粗利構成合計 vs 施策粗利: 差分 < 1万円
```

## 参照ドキュメント

- `salesmtg/CLAUDE.md` — データソースの正本定義
- `salesmtg/development.md` — データフロー・計算式仕様
