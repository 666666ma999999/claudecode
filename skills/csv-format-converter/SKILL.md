---
name: csv-format-converter
description: CSVファイルのフォーマット分析・変換スキル。エンコーディング検出、列構造の解析、異なるシステム間でのフォーマット変換を実行。「CSVを変換」「フォーマットを合わせて」「CSV形式を分析」などのリクエストで使用。
metadata:
  author: masaaki-nagasawa
  version: 1.0.0
---

# CSV Format Converter

CSVファイルのフォーマットを分析し、目的の形式に変換するスキル。

## トリガー条件

以下のいずれかに該当する場合に使用:
- CSVファイルの変換が必要
- CSVのフォーマット/エンコーディングを確認したい
- システム間でCSV形式を合わせる必要がある

## 入力

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| source_csv | Yes | 変換元CSVファイルパス |
| target_format | No | 出力形式名（auto検出可） |
| target_encoding | No | 出力エンコーディング（デフォルト: 元と同じ） |

## 出力

| パラメータ | 説明 |
|-----------|------|
| converted_csv_path | 変換後ファイルパス |
| row_count | 変換した行数 |
| format_info | 検出したフォーマット情報 |

---

## STEP 1: フォーマット分析

### エンコーディング検出

```python
import chardet

def detect_encoding(file_path):
    with open(file_path, 'rb') as f:
        result = chardet.detect(f.read())
    return result['encoding']
```

### よくあるエンコーディング

| システム | エンコーディング |
|---------|-----------------|
| 日本のレガシーシステム | Shift_JIS (cp932) |
| 現代のWebシステム | UTF-8 |
| Windows Excel | cp932 or UTF-8 BOM |

### 列構造の解析

```python
import csv

def analyze_structure(file_path, encoding):
    with open(file_path, 'r', encoding=encoding) as f:
        # 空行をスキップ
        lines = [l for l in f.readlines() if l.strip()]

    # ヘッダー検出
    reader = csv.reader(lines)
    first_row = next(reader)

    return {
        'columns': first_row,
        'column_count': len(first_row),
        'has_header': not first_row[0].isdigit()
    }
```

---

## STEP 2: フォーマット変換

### 変換パターン

#### パターンA: 列の抽出・並び替え

```python
def extract_columns(row, column_mapping):
    """
    column_mapping: {'new_col': 'old_col'} or {'new_col': index}
    """
    return [row.get(col, '') if isinstance(col, str) else row[col]
            for col in column_mapping.values()]
```

#### パターンB: 行の展開（1行→複数行）

```python
def expand_rows(row, expansion_rules):
    """
    1つの行を複数行に展開（例: キャリアごとに分割）
    expansion_rules: [
        {'carrier_id': '110', 'sid_col': 'dmenu_sid'},
        {'carrier_id': '6', 'sid_col': 'spau_pc_code'},
    ]
    """
    expanded = []
    for rule in expansion_rules:
        new_row = row.copy()
        new_row['carrier_id'] = rule['carrier_id']
        new_row['serviceid'] = row.get(rule['sid_col'], '')
        if new_row['serviceid']:  # 値がある場合のみ
            expanded.append(new_row)
    return expanded
```

#### パターンC: エンコーディング変換

```python
def convert_encoding(input_path, output_path, from_enc, to_enc):
    with open(input_path, 'r', encoding=from_enc) as f:
        content = f.read()
    with open(output_path, 'w', encoding=to_enc) as f:
        f.write(content)
```

---

## STEP 3: 出力

### 出力オプション

| オプション | 説明 |
|-----------|------|
| with_header | ヘッダー行を含める（True/False） |
| encoding | 出力エンコーディング |
| line_ending | 改行コード（\n, \r\n） |

### 出力例

```python
def write_csv(rows, output_path, encoding='cp932', with_header=False, headers=None):
    with open(output_path, 'w', newline='', encoding=encoding) as f:
        writer = csv.writer(f)
        if with_header and headers:
            writer.writerow(headers)
        writer.writerows(rows)
    return output_path
```

---

## 既知のフォーマット定義

### MKB SitePpv形式

```yaml
name: mkb_siteppv
encoding: cp932
has_header: false
columns:
  - site_id
  - carrier_id
  - name
  - serviceid
  - menuid
  - charge
  - public_date
  - rank_flg
```

### 原稿管理（従量管理）形式

```yaml
name: manuscript_ppv
encoding: cp932
has_header: true
skip_empty_lines: true
columns:
  - ppv_id
  - title
  - guide
  - docomo_sid
  - au_pc_code
  - softbank_sid
  - dmenu_sid
  - spau_pc_code
  - spsb_sid
  - price
  - ... (29列)
```

### 変換マッピング: 原稿管理 → MKB

```python
MANUSCRIPT_TO_MKB = {
    'site_id': lambda row, ctx: ctx['site_id'],
    'carrier_id': lambda row, ctx: ctx['carrier_id'],
    'name': lambda row, ctx: row['title'],
    'serviceid': lambda row, ctx: row[ctx['sid_col']],
    'menuid': lambda row, ctx: row.get('p_menu_id') or f"ppv{row['ppv_id']}",
    'charge': lambda row, ctx: row['price'],
    'public_date': lambda row, ctx: row['public_date'],
    'rank_flg': lambda row, ctx: row.get('ranking_view_flg', '0') or '0',
}

CARRIER_EXPANSION = [
    {'carrier_id': '110', 'sid_col': 'dmenu_sid'},
    {'carrier_id': '6', 'sid_col': 'spau_pc_code'},
    {'carrier_id': '7', 'sid_col': 'spsb_sid'},
]
```

---

## 使用例

### 例1: フォーマット分析のみ

```
ユーザー: このCSVのフォーマットを教えて
AI:
  - エンコーディング: cp932
  - 列数: 29
  - ヘッダー: あり
  - 形式: 原稿管理（従量管理）形式
```

### 例2: MKB形式への変換

```
ユーザー: このCSVをMKB形式に変換して
AI:
  1. フォーマット分析 → 原稿管理形式と判定
  2. 変換マッピング適用
  3. キャリアごとに行展開
  4. cp932でヘッダーなし出力
  出力: /path/to/converted.csv (9行)
```

---

## 注意事項

- 変換前に必ずバックアップを推奨
- エンコーディングエラー時は元ファイルを破損しない
- 大量データ（10万行以上）は分割処理を検討

