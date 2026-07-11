---
name: salesmtg-dashboard-qa
description: 営業会議ダッシュボードのUI品質保証。全セグメント統一フォーマット、欠損データのN/A表示、粗利構成テーブルの整合性を検証する。
triggers:
  - ダッシュボード 表示確認
  - 粗利構成 フォーマット
  - セグメント 表示 統一
  - N/A 表示
  - ダッシュボード QA
not_for:
  - データ整合性チェック（→ salesmtg-data-audit）
  - スクレイパー修正
allowed-tools: [Read, Glob, Grep, Bash]
---

# salesmtg ダッシュボードQAスキル

## 使用タイミング

- ダッシュボードHTML生成後の品質チェック
- 「数字がおかしい」「表示が違う」の報告時
- generate_unified_dashboard.py の表示ロジック変更時
- 新セグメント追加時

## QAチェックリスト

### 1. セグメント統一フォーマット

- [ ] 全セグメント（Seg 1-19 + Seg 20）が同じ列構成で表示される
- [ ] セグメント順序が Seg 1 → Seg 20 の固定順
- [ ] はやとも（Seg 1）のフォーマットが基準。他セグメントが同じ形式か確認

### 2. 粗利構成テーブル

各セグメントの行が以下の7行で統一されているか:

```
セグメント名（ヘッダ行）
  ①初月売上
  ①広告費
  ②2-5M月額
  ②2-5M従量
  ③6M+月額
  ③6M+従量
  施策粗利計
```

### 3. 0 vs 欠損の区別

| 状態 | 表示 | 意味 |
|------|------|------|
| 値が0 | `0` | 実データとして0（広告費がないサイト等） |
| データソースにない | `N/A` | 取得できていない / swan-manageに値がない |
| フォールバック使用 | `値†` | 正本と異なるソースから取得（注釈付き） |

### 4. フォールバック警告

- 継続会員月額が月次売上CSVに存在しないセグメント → ②③月額に注釈
- 広告費が月次売上CSVに存在しないセグメント → ①広告費に`N/A`
- KPI CSVが存在しないセグメント → 因果分解を非表示

### 5. 検証コマンド（汎用版・2026-07-11 P4 裁定）

> 旧版は単一定数 `DASHBOARD_DATA` 前提で、現行 HTML（`PL_DATA`/`BOARD_DATA` 等 15 定数に分割済み・2026-07-11 実測）では必ず AttributeError。**まず定数を発見してから検証する** 2 段構えに変更。

```python
# STEP A: HTML 内の全データ定数を発見（定数名にハードコード依存しない）
python3 -c "
import re, sys
html = open(sys.argv[1]).read()
consts = sorted(set(re.findall(r'const ([A-Z_]+) *=', html)))
print('発見した定数:', consts)
" output/dashboard_unified_<YYYYMM>.html

# STEP B: 発見した定数ごとに JSON 抽出して検証（例: 粗利構成は PL_DATA・セグメント別は BOARD_DATA）
python3 -c "
import json, re, sys
html = open(sys.argv[1]).read()
name = sys.argv[2]  # STEP A で見つけた定数名
m = re.search(r'const ' + name + r' *= *({.*?});\s*\n', html, re.DOTALL)
assert m, f'{name} が見つからない（STEP A の一覧から選ぶ）'
data = json.loads(m.group(1))
print(name, '→ keys:', list(data)[:10] if isinstance(data, dict) else type(data))
" output/dashboard_unified_<YYYYMM>.html PL_DATA
```

役割の目安（2026-07-11 時点の実測・定数は増減しうるので STEP A を必ず先に）: 粗利構成 = `PL_DATA`（マージ規則 `PL_MERGE_MAP`/`PL_SEG_MAP`）／セグメント別ボード = `BOARD_DATA`／日次・月次 = `DAILY_DATA`/`MONTHLY_DATA`/`MTD_DATA`。

### 6. ブラウザ確認（必須）

- [ ] HTMLをブラウザで開く
- [ ] 粗利構成タブを選択
- [ ] 全セグメントをスクロールして確認
- [ ] はやとも（Seg 1）と他セグメントのフォーマットが一致
- [ ] 前月/当月のハイライト列が正しい

## 参照ドキュメント

- `salesmtg/CLAUDE.md` — UI表示ルール、ペルソナ視点
- `salesmtg/development.md` — 20セグメント定義、計算式
